import Foundation

nonisolated struct SystemRecord: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let status: String?
    let host: String?
    let info: SystemInfo?
}

nonisolated struct SystemInfo: Codable, Hashable, Sendable {
    let h: String? // hostname
    let k: String? // kernel version
    let c: Int?    // cpu cores
    let t: Int?    // cpu threads
    let m: String? // cpu model
    let os: Int?   // os identifier
}
