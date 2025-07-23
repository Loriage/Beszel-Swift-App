import Foundation

struct AuthMethodsResponse: Decodable {
    let password: PasswordAuth
    let oauth2: OAuth2Auth
}

struct PasswordAuth: Decodable {
    let enabled: Bool
}

struct OAuth2Auth: Decodable {
    let enabled: Bool
    let providers: [OAuth2Provider]
}

struct OAuth2Provider: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let displayName: String
    let authUrl: String
    let codeVerifier: String
}
