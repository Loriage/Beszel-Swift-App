import Foundation

struct SystemRecord: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let status: String
    let host: String
    let info: SystemInfo
}

struct SystemInfo: Codable, Hashable {
    let h: String // hostname
    let k: String // kernel version
    let c: Int    // cpu cores
    let t: Int    // cpu threads
    let m: String // cpu model
    let os: Int
}
