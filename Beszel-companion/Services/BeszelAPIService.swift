import Foundation
import Combine

class BeszelAPIService: ObservableObject {
    private let baseURL: String
    private let email: String
    private let password: String
    private var authToken: String?

    init(url: String, email: String, password: String) {
        self.baseURL = url
        self.email = email
        self.password = password
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

    private func authenticate() async throws {
        guard let url = URL(string: "\(baseURL)/api/collections/users/auth-with-password") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["identity": self.email, "password": self.password]
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        self.authToken = authResponse.token
    }

    func fetchMonitors(filter: String?) async throws -> [ContainerStatsRecord] {
        if authToken == nil {
            try await authenticate()
        }
        guard let token = authToken else {
            throw URLError(.userAuthenticationRequired)
        }

        let url = try buildURL(for: "/api/collections/container_stats/records", filter: filter)

        var request = URLRequest(url: url)
        request.addValue(token, forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decodedResponse = try JSONDecoder().decode(PocketBaseListResponse<ContainerStatsRecord>.self, from: data)
        return decodedResponse.items
    }

    func fetchSystemStats(filter: String?) async throws -> [SystemStatsRecord] {
        if authToken == nil {
            try await authenticate()
        }
        guard let token = authToken else {
            throw URLError(.userAuthenticationRequired)
        }

        let url = try buildURL(for: "/api/collections/system_stats/records", filter: filter)

        var request = URLRequest(url: url)
        request.addValue(token, forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decodedResponse = try JSONDecoder().decode(PocketBaseListResponse<SystemStatsRecord>.self, from: data)
        return decodedResponse.items
    }

    func fetchSystems() async throws -> [SystemRecord] {
        if authToken == nil {
            try await authenticate()
        }
        guard let token = authToken else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let urlString = "\(baseURL)/api/collections/systems/records"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.addValue(token, forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decodedResponse = try JSONDecoder().decode(PocketBaseListResponse<SystemRecord>.self, from: data)
        return decodedResponse.items
    }
}
