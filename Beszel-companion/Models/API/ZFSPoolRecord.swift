import Foundation

/// Beszel 0.19 pool details. These are separate from the GiB/rate history samples.
nonisolated struct ZFSPoolRecord: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let system: String
    let name: String
    let health: String?
    let size: UInt64?
    let alloc: UInt64?
    let free: UInt64?
    let scrub: ZFSScrub?
    let vdevs: [ZFSVdev]?
    let datasets: [ZFSDataset]?
    let detailsUpdated: String?

    enum CodingKeys: String, CodingKey {
        case id, system, name, health, size, alloc, free, scrub, vdevs, datasets
        case detailsUpdated = "details_updated"
    }
}

nonisolated struct ZFSScrub: Codable, Hashable, Sendable {
    let state: String?
    let progress: String?
    let errors: UInt64?
}

nonisolated struct ZFSVdev: Codable, Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let state: String?
    let readErrs: UInt64?
    let writeErrs: UInt64?
    let checksumErrs: UInt64?
}

nonisolated struct ZFSDataset: Codable, Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let used: UInt64?
    let avail: UInt64?
    let mount: String?
}

nonisolated struct ZFSPoolStats: Codable, Equatable, Sendable {
    let d: Double?       // capacity in GiB
    let du: Double?      // allocated in GiB
    let rb: Double?      // read bytes/s (omitted when zero)
    let wb: Double?      // write bytes/s (omitted when zero)
    let h: String?

    var percent: Double? {
        guard let d, let du, d > 0 else { return nil }
        return du / d * 100
    }
}
