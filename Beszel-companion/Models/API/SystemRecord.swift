import Foundation

nonisolated struct SystemRecord: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let status: String?
    let host: String?
    let port: String?
    let info: SystemInfo?
    let v: String?       // agent version
    let updated: String?
}

nonisolated struct SystemInfo: Codable, Hashable, Sendable {
    // Hardware info
    let h: String?       // hostname
    let k: String?       // kernel version
    let c: Int?          // cpu cores
    let t: Int?          // cpu threads
    let m: String?       // cpu model
    let o: String?       // operating system string
    let os: Int?         // os identifier enum
    let u: Double?       // uptime in seconds
    let v: String?       // agent version

    // Live metrics
    let cpu: Double?     // current cpu percent
    let mp: Double?      // memory percent
    let dp: Double?      // disk percent
    let b: Double?       // bandwidth (mb)
    let bb: Double?      // bandwidth bytes

    // Load average
    let l1: Double?      // load average 1 min
    let l5: Double?      // load average 5 min
    let l15: Double?     // load average 15 min
    let la: [Double]?    // load average array [1, 5, 15]

    // Optional features
    let bat: [Double]?   // battery [percent, state] - state is enum but decoded as number
    let g: Double?       // highest gpu utilization
    let dt: Double?      // dashboard display temperature
    let p: Bool?         // system is using podman
    let ct: Int?         // connection type

    // Extra data
    let efs: [String: Double]?    // extra filesystem percentages
    let sv: [Int]?                // services [total, failed]
}

extension SystemInfo {
    static func sample() -> SystemInfo {
        SystemInfo(
            h: "server",
            k: "Linux",
            c: 4,
            t: 8,
            m: "Intel Core i7",
            o: nil,
            os: 1,
            u: 3600 * 24 * 3,
            v: nil,
            cpu: nil,
            mp: nil,
            dp: nil,
            b: 0,
            bb: nil,
            l1: nil,
            l5: nil,
            l15: nil,
            la: nil,
            bat: nil,
            g: nil,
            dt: nil,
            p: nil,
            ct: nil,
            efs: nil,
            sv: nil
        )
    }
}
