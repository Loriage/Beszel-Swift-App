import Foundation
import Combine

class BeszelAPIService: ObservableObject {
    private let instance: Instance
    private let instanceManager: InstanceManager
    
    private let baseURL: String
    private let email: String
    private var credential: String

    private static var tokenCache: [UUID: String] = [:]
    private var authToken: String? {
        get { BeszelAPIService.tokenCache[instance.id] }
        set { BeszelAPIService.tokenCache[instance.id] = newValue }
    }

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
        if authToken != nil {
            return
        }

        let parts = credential.components(separatedBy: ".")
        if parts.count == 3 {
            let header = parts[0]

            if let headerData = Data(base64Encoded: header.padding(toLength: ((header.count + 3) / 4) * 4, withPad: "=", startingAt: 0)),
               let _ = try? JSONSerialization.jsonObject(with: headerData, options: []) as? [String: Any] {
                self.authToken = credential
                return
            }
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
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        self.authToken = authResponse.token
        instanceManager.updateCredential(for: self.instance, newCredential: authResponse.token)
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
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        let newToken = authResponse.token
        
        self.authToken = newToken
        self.credential = newToken
        instanceManager.updateCredential(for: self.instance, newCredential: newToken)
    }

    private func performRequest<T: Decodable>(with url: URL) async throws -> T {
        try await ensureAuthenticated()
        
        guard let token = authToken else {
            throw URLError(.userAuthenticationRequired)
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await self.session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            try await refreshToken()
            
            guard let refreshedToken = authToken else {
                throw URLError(.userAuthenticationRequired)
            }
            
            var refreshedRequest = URLRequest(url: url)
            refreshedRequest.addValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
            
            let (refreshedData, refreshedResponse) = try await self.session.data(for: refreshedRequest)
            
            guard let finalHttpResponse = refreshedResponse as? HTTPURLResponse, finalHttpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            return try JSONDecoder().decode(T.self, from: refreshedData)
            
        } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(T.self, from: data)
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
