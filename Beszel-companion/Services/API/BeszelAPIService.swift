import Foundation

actor BeszelAPIService {
    private let instance: Instance
    private let instanceManager: InstanceManager
    
    private let baseURL: String
    private let email: String
    
    private var credential: String?
    private var authToken: String?
    
    private var refreshTask: Task<String, Error>?
    
    private nonisolated static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS'Z'"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let date = formatter.date(from: dateStr) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
        }
        return decoder
    }()
    
    private lazy var session: URLSession = {
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
    
    private func getValidToken() async throws -> String {
        if let currentToken = authToken {
            return currentToken
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
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            return try Self.jsonDecoder.decode(T.self, from: data)
        } else {
            throw URLError(.badServerResponse)
        }
    }
    
    func fetchSystems() async throws -> [SystemRecord] {
        guard let url = URL(string: "\(baseURL)/api/collections/systems/records") else {
            throw URLError(.badURL)
        }
        let response: PocketBaseListResponse<SystemRecord> = try await performRequest(with: url)
        return response.items
    }
    
    func fetchMonitors(filter: String?) async throws -> [ContainerStatsRecord] {
        let url = try buildURL(for: "/api/collections/container_stats/records", filter: filter)
        let response: PocketBaseListResponse<ContainerStatsRecord> = try await performRequest(with: url)
        return response.items
    }
    
    func fetchSystemStats(filter: String?) async throws -> [SystemStatsRecord] {
        let url = try buildURL(for: "/api/collections/system_stats/records", filter: filter)
        let response: PocketBaseListResponse<SystemStatsRecord> = try await performRequest(with: url)
        return response.items
    }
    
    private func buildURL(for path: String, filter: String?) throws -> URL {
        guard var components = URLComponents(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        components.path = path
        
        components.queryItems = [
            URLQueryItem(name: "perPage", value: "500")
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
