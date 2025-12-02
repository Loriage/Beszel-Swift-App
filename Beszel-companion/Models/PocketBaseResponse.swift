import Foundation

nonisolated struct PocketBaseListResponse<T: Codable & Sendable>: Codable, Sendable {
    let page: Int
    let perPage: Int
    let totalItems: Int
    let totalPages: Int
    let items: [T]
}
