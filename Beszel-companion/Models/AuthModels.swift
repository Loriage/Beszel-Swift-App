import Foundation

nonisolated struct AuthMethodsResponse: Decodable, Sendable {
    let password: PasswordAuth
    let oauth2: OAuth2Auth
}

nonisolated struct PasswordAuth: Decodable, Sendable {
    let enabled: Bool
}

nonisolated struct OAuth2Auth: Decodable, Sendable {
    let enabled: Bool
    let providers: [OAuth2Provider]
}

nonisolated struct OAuth2Provider: Decodable, Identifiable, Sendable {
    var id: String { name }
    let name: String
    let displayName: String
    let authUrl: String
    let codeVerifier: String
}
