import Foundation

struct Instance: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    let url: String
    let email: String
}
