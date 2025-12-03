import Foundation

actor BeszelAPIService {
    private let instance: Instance
    private let instanceManager: InstanceManager
    
    private let baseURL: String
    private let email: String
    private var credential: String

    private var authToken: String?

    private nonisolated static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
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
        self.credential = instanceManager.loadCredential(for: instance) ?? ""
    }

    private var session: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }

    private func ensureAuthenticated() async throws {
        if authToken != nil { return }

        let parts = credential.components(separatedBy: ".")
        if parts.count == 3 {
            self.authToken = credential
            return
        }

        guard !email.isEmpty, !credential.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        
        guard let url = URL(string: "\(baseURL)/api/collections/users/auth-with-password") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["identity": self.email, "password": self.credential]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await self.session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.userAuthenticationRequired)
        }

        let authResponse = try Self.jsonDecoder.decode(AuthResponse.self, from: data)
        self.authToken = authResponse.token
        
        let newToken = authResponse.token
        let localInstance = self.instance
        
        await MainActor.run {
            self.instanceManager.updateCredential(for: localInstance, newCredential: newToken)
        }
    }

    private func refreshToken() async throws {
        guard let url = URL(string: "\(baseURL)/api/collections/users/auth-refresh") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if let currentToken = self.authToken {
            request.addValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await self.session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let authResponse = try Self.jsonDecoder.decode(AuthResponse.self, from: data)
        let newToken = authResponse.token
        
        self.authToken = newToken
        self.credential = newToken
        
        let localInstance = self.instance
        await MainActor.run {
            self.instanceManager.updateCredential(for: localInstance, newCredential: newToken)
        }
    }

    private func performRequest<T: Decodable & Sendable>(with url: URL) async throws -> T {
        try await ensureAuthenticated()
        
        guard let token = authToken else {
            throw URLError(.userAuthenticationRequired)
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await self.session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            try await refreshToken()

            guard let refreshedToken = authToken else { throw URLError(.userAuthenticationRequired) }
            var refreshedRequest = URLRequest(url: url)
            refreshedRequest.addValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
            let (refreshedData, _) = try await self.session.data(for: refreshedRequest)

            return try Self.jsonDecoder.decode(T.self, from: refreshedData)
            
        } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
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
