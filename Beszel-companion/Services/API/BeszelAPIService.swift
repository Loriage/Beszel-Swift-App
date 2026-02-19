import Foundation

actor BeszelAPIService {
    private let instance: Instance
    private let instanceManager: InstanceManager
    
    private let baseURL: String
    private let email: String
    
    private var credential: String?
    private var authToken: String?
    
    private var refreshTask: Task<String, Error>?
    
    private static let tokenCache = UserDefaults.sharedSuite
    private static let tokenCacheValiditySeconds: TimeInterval = 600
    
    private nonisolated static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private nonisolated static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)

            if let date = dateFormatter.date(from: dateStr) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
        }
        return decoder
    }()
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()
    
    init(instance: Instance, instanceManager: InstanceManager) {
        self.instance = instance
        self.instanceManager = instanceManager
        
        var cleanUrl = instance.url.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanUrl.hasSuffix("/") {
            cleanUrl.removeLast()
        }
        
        self.baseURL = cleanUrl
        self.email = instance.email
    }
    
    private func getStoredCredential() -> String {
        if let cred = credential { return cred }
        let loaded = instanceManager.loadCredential(for: instance) ?? ""
        self.credential = loaded
        return loaded
    }
    
    private nonisolated func cacheKey() -> String {
        "cachedToken_\(instance.id.uuidString)"
    }
    
    private nonisolated func cacheTimestampKey() -> String {
        "cachedTokenTime_\(instance.id.uuidString)"
    }
    
    private nonisolated func getCachedToken() -> String? {
        guard let token = Self.tokenCache.string(forKey: cacheKey()),
              let timestamp = Self.tokenCache.object(forKey: cacheTimestampKey()) as? Date else {
            return nil
        }
        
        if Date().timeIntervalSince(timestamp) < Self.tokenCacheValiditySeconds {
            return token
        }
        return nil
    }
    
    private nonisolated func setCachedToken(_ token: String) {
        Self.tokenCache.set(token, forKey: cacheKey())
        Self.tokenCache.set(Date(), forKey: cacheTimestampKey())
    }
    
    private func getValidToken() async throws -> String {
        if let currentToken = authToken {
            return currentToken
        }
        
        if let cachedToken = getCachedToken() {
            self.authToken = cachedToken
            return cachedToken
        }
        
        if let existingTask = refreshTask {
            return try await existingTask.value
        }
        
        let task = Task { () -> String in
            let cred = getStoredCredential()
            guard !cred.isEmpty else {
                throw URLError(.userAuthenticationRequired)
            }
            
            if isJWT(cred) {
                return try await refreshToken(currentToken: cred)
            } else {
                return try await loginWithPassword(password: cred)
            }
        }
        
        self.refreshTask = task
        
        do {
            let newToken = try await task.value
            self.authToken = newToken
            setCachedToken(newToken)
            self.refreshTask = nil
            return newToken
        } catch {
            self.refreshTask = nil
            self.authToken = nil
            throw error
        }
    }
    
    private func isJWT(_ str: String) -> Bool {
        let parts = str.components(separatedBy: ".")
        return parts.count == 3 && str.hasPrefix("ey")
    }

    private func userIDFromToken(_ token: String) -> String? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { return nil }
        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else { return nil }
        return id
    }
    
    private func loginWithPassword(password: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/collections/users/auth-with-password") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["identity": self.email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await self.session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let authResponse = try Self.jsonDecoder.decode(AuthResponse.self, from: data)
        return authResponse.token
    }
    
    private func refreshToken(currentToken: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/collections/users/auth-refresh") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await self.session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let authResponse = try Self.jsonDecoder.decode(AuthResponse.self, from: data)
        let newToken = authResponse.token
        
        self.credential = newToken
        let localInstance = self.instance
        
        await MainActor.run {
            self.instanceManager.updateCredential(for: localInstance, newCredential: newToken)
        }
        
        return newToken
    }
    
    private func performRequest<T: Decodable & Sendable>(with url: URL) async throws -> T {
        let token = try await getValidToken()
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await self.session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            self.authToken = nil
            
            let newToken = try await getValidToken()
            
            var retryRequest = request
            retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            
            let (retryData, retryResponse) = try await self.session.data(for: retryRequest)
            
            if let retryHttpResponse = retryResponse as? HTTPURLResponse, retryHttpResponse.statusCode == 200 {
                return try Self.jsonDecoder.decode(T.self, from: retryData)
            } else {
                throw URLError(.userAuthenticationRequired)
            }
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                return try Self.jsonDecoder.decode(T.self, from: data)
            } else {
                throw BeszelAPIError.httpError(statusCode: httpResponse.statusCode, url: url.absoluteString)
            }
        } else {
            throw URLError(.badServerResponse)
        }
    }
    
    enum BeszelAPIError: LocalizedError {
        case httpError(statusCode: Int, url: String)
        case apiError(statusCode: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .httpError(let statusCode, let url):
                return "HTTP \(statusCode) error for \(url)"
            case .apiError(let statusCode, let message):
                return "HTTP \(statusCode): \(message)"
            }
        }
    }

    private func parseAPIError(data: Data, statusCode: Int, url: URL) -> BeszelAPIError {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String {
            return .apiError(statusCode: statusCode, message: message)
        }
        return .httpError(statusCode: statusCode, url: url.absoluteString)
    }
    
    func fetchSystems() async throws -> [SystemRecord] {
        guard let url = URL(string: "\(baseURL)/api/collections/systems/records") else {
            throw URLError(.badURL)
        }
        let response: PocketBaseListResponse<SystemRecord> = try await performRequest(with: url)
        return response.items
    }
    
    /// Fetches system details from the new endpoint (Beszel agent 0.18.0+).
    /// Returns empty array for servers running older agents that don't have this endpoint.
    func fetchSystemDetails() async throws -> [SystemDetailsRecord] {
        guard let url = URL(string: "\(baseURL)/api/collections/system_details/records") else {
            throw URLError(.badURL)
        }
        do {
            let response: PocketBaseListResponse<SystemDetailsRecord> = try await performRequest(with: url)
            return response.items
        } catch let error as BeszelAPIError {
            if case .httpError(let statusCode, _) = error, statusCode == 404 {
                return []
            }
            throw error
        }
    }
    
    func fetchMonitors(filter: String?) async throws -> [ContainerStatsRecord] {
        try await fetchAllPages(path: "/api/collections/container_stats/records", filter: filter)
    }
    
    func fetchSystemStats(filter: String?) async throws -> [SystemStatsRecord] {
        try await fetchAllPages(path: "/api/collections/system_stats/records", filter: filter)
    }
    
    private func fetchAllPages<T: Codable & Sendable>(path: String, filter: String?) async throws -> [T] {
        var allItems: [T] = []
        var currentPage = 1
        var totalPages = 1
        
        repeat {
            let url = try buildURL(for: path, filter: filter, page: currentPage)
            let response: PocketBaseListResponse<T> = try await performRequest(with: url)
            
            allItems.append(contentsOf: response.items)
            totalPages = response.totalPages
            currentPage += 1
        } while currentPage <= totalPages
        
        return allItems
    }
    
    func fetchLatestSystemStats(systemID: String) async throws -> SystemStatsRecord? {
        guard var components = URLComponents(string: baseURL) else { throw URLError(.badURL) }
        components.path = "/api/collections/system_stats/records"
        components.queryItems = [
            URLQueryItem(name: "perPage", value: "1"),
            URLQueryItem(name: "sort", value: "-created"),
            URLQueryItem(name: "filter", value: "system = '\(systemID)'")
        ]
        
        guard let url = components.url else { throw URLError(.badURL) }
        let response: PocketBaseListResponse<SystemStatsRecord> = try await performRequest(with: url)
        return response.items.first
    }
    
    private func performMutatingRequest(
        url: URL,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> Data {
        let token = try await getValidToken()

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let body = body {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            self.authToken = nil
            let newToken = try await getValidToken()

            var retryRequest = request
            retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")

            let (retryData, retryResponse) = try await session.data(for: retryRequest)

            guard let retryHttp = retryResponse as? HTTPURLResponse,
                  (200...299).contains(retryHttp.statusCode) else {
                throw URLError(.userAuthenticationRequired)
            }
            return retryData
        }

        if let httpResponse = response as? HTTPURLResponse {
            if (200...299).contains(httpResponse.statusCode) {
                return data
            } else {
                throw parseAPIError(data: data, statusCode: httpResponse.statusCode, url: url)
            }
        }
        throw URLError(.badServerResponse)
    }

    func createAlert(system: String, name: String, value: Double, min: Double) async throws -> AlertRecord {
        guard let url = URL(string: "\(baseURL)/api/collections/alerts/records") else {
            throw URLError(.badURL)
        }
        let token = try await getValidToken()
        guard let userID = userIDFromToken(token) else {
            throw URLError(.userAuthenticationRequired)
        }
        let body: [String: Any] = ["user": userID, "system": system, "name": name, "value": value, "min": min]
        let data = try await performMutatingRequest(url: url, method: "POST", body: body)
        return try Self.jsonDecoder.decode(AlertRecord.self, from: data)
    }

    func updateAlert(id: String, system: String, name: String, value: Double, min: Double) async throws -> AlertRecord {
        guard let url = URL(string: "\(baseURL)/api/collections/alerts/records/\(id)") else {
            throw URLError(.badURL)
        }
        let token = try await getValidToken()
        guard let userID = userIDFromToken(token) else {
            throw URLError(.userAuthenticationRequired)
        }
        let body: [String: Any] = ["user": userID, "system": system, "name": name, "value": value, "min": min]
        let data = try await performMutatingRequest(url: url, method: "PATCH", body: body)
        return try Self.jsonDecoder.decode(AlertRecord.self, from: data)
    }

    func deleteAlert(id: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/collections/alerts/records/\(id)") else {
            throw URLError(.badURL)
        }
        _ = try await performMutatingRequest(url: url, method: "DELETE")
    }

    func fetchAlerts(filter: String?) async throws -> [AlertRecord] {
        try await fetchAllPages(path: "/api/collections/alerts/records", filter: filter)
    }
    
    func fetchAlertHistory(filter: String?) async throws -> [AlertHistoryRecord] {
        try await fetchAllPages(path: "/api/collections/alerts_history/records", filter: filter)
    }
    
    func fetchAlertHistorySince(date: Date) async throws -> [AlertHistoryRecord] {
        // PocketBase expects dates in format: "2022-01-01 10:00:00.000Z"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = formatter.string(from: date)
        let filter = "created >= '\(dateString)'"
        return try await fetchAlertHistory(filter: filter)
    }
    
    func fetchLatestAlertHistory(limit: Int = 50) async throws -> [AlertHistoryRecord] {
        guard var components = URLComponents(string: baseURL) else { throw URLError(.badURL) }
        components.path = "/api/collections/alerts_history/records"
        components.queryItems = [
            URLQueryItem(name: "perPage", value: String(limit)),
            URLQueryItem(name: "sort", value: "-created")
        ]
        
        guard let url = components.url else { throw URLError(.badURL) }
        let response: PocketBaseListResponse<AlertHistoryRecord> = try await performRequest(with: url)
        return response.items
    }
    
    func fetchContainers(filter: String?) async throws -> [ContainerRecord] {
        try await fetchAllPages(path: "/api/collections/containers/records", filter: filter)
    }
    
    func fetchContainerLogs(systemID: String, containerID: String) async throws -> String {
        guard var components = URLComponents(string: baseURL) else { throw URLError(.badURL) }
        components.path = "/api/beszel/containers/logs"
        components.queryItems = [
            URLQueryItem(name: "system", value: systemID),
            URLQueryItem(name: "container", value: containerID)
        ]
        
        guard let url = components.url else { throw URLError(.badURL) }
        
        let token = try await getValidToken()
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            return String(data: data, encoding: .utf8) ?? ""
        } else if let httpResponse = response as? HTTPURLResponse {
            throw BeszelAPIError.httpError(statusCode: httpResponse.statusCode, url: url.absoluteString)
        }
        throw URLError(.badServerResponse)
    }
    
    func fetchContainerInfo(systemID: String, containerID: String) async throws -> String {
        guard var components = URLComponents(string: baseURL) else { throw URLError(.badURL) }
        components.path = "/api/beszel/containers/info"
        components.queryItems = [
            URLQueryItem(name: "system", value: systemID),
            URLQueryItem(name: "container", value: containerID)
        ]
        
        guard let url = components.url else { throw URLError(.badURL) }
        
        let token = try await getValidToken()
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                return prettyString
            }
            return String(data: data, encoding: .utf8) ?? ""
        } else if let httpResponse = response as? HTTPURLResponse {
            throw BeszelAPIError.httpError(statusCode: httpResponse.statusCode, url: url.absoluteString)
        }
        throw URLError(.badServerResponse)
    }
    
    private func buildURL(for path: String, filter: String?, page: Int = 1) throws -> URL {
        guard var components = URLComponents(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        components.path = path
        
        components.queryItems = [
            URLQueryItem(name: "perPage", value: "500"),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        if let filter = filter {
            components.queryItems?.append(URLQueryItem(name: "filter", value: filter))
        }
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        return url
    }
}
