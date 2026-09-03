import Foundation

/// The hub version, not the agent version, determines which alert names it accepts.
nonisolated struct HubInfo: Decodable, Sendable {
    let v: String?

    var supports019: Bool {
        guard var version = v else { return false }
        if version.hasPrefix("v") { version.removeFirst() }
        guard let release = version.split(separator: "+", maxSplits: 1).first else { return false }
        let parts = release.split(separator: "-", maxSplits: 1)
        guard let core = parts.first else { return false }
        let components = core.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3 else { return false }
        let numbers = components.compactMap { Int($0) }
        guard numbers.count == 3, numbers.allSatisfy({ $0 >= 0 }) else { return false }
        let minimum = [0, 19, 0]
        if numbers == minimum { return parts.count == 1 }
        return minimum.lexicographicallyPrecedes(numbers)
    }
}
