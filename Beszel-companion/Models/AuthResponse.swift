import Foundation

nonisolated struct AuthResponse: Codable, Sendable {
    let token: String
}
