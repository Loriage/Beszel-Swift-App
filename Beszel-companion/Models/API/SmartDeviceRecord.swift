import Foundation

nonisolated struct SmartDeviceRecord: Identifiable, Codable, Sendable {
    let id: String
    let system: String
    let name: String
    let model: String?
    let state: String?       // e.g. "PASSED", "FAILED"
    let capacity: Int?       // bytes
    let temp: Int?           // degrees Celsius
    let firmware: String?
    let serial: String?
    let type: String?        // e.g. "ATA", "NVMe"
    let hours: Int?          // power-on hours
    let cycles: Int?         // power cycle count
    let attributes: [SmartAttribute]?
    let updated: Date?

    var isPassed: Bool {
        state?.uppercased() == "PASSED"
    }

    var isFailed: Bool {
        guard let s = state else { return false }
        let u = s.uppercased()
        return u == "FAILED" || u == "FAILING"
    }

    var formattedCapacity: String? {
        guard let cap = capacity, cap > 0 else { return nil }
        let gb = Double(cap) / 1_000_000_000.0
        if gb >= 1000 {
            return String(format: "%.1f TB", gb / 1000)
        }
        return String(format: "%.0f GB", gb)
    }
}

nonisolated struct SmartAttribute: Codable, Identifiable, Sendable {
    let id: Int?
    let name: String          // json: "n"
    let value: Int?           // json: "v" – normalized value
    let worst: Int?           // json: "w"
    let threshold: Int?       // json: "t"
    let rawValue: Int?        // json: "rv"
    let rawString: String?    // json: "rs"
    let whenFailed: String?   // json: "wf"

    enum CodingKeys: String, CodingKey {
        case id
        case name = "n"
        case value = "v"
        case worst = "w"
        case threshold = "t"
        case rawValue = "rv"
        case rawString = "rs"
        case whenFailed = "wf"
    }

    var isFailing: Bool {
        let wf = whenFailed ?? ""
        return !wf.isEmpty && wf != "-"
    }
}
