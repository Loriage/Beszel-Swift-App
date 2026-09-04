import Foundation

enum SortOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case custom = "filter.custom"
    case bySystem = "filter.bySystem"
    case byMetric = "filter.byMetric"
    case byService = "filter.byService"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .custom: "filter.custom"
        case .bySystem: "filter.bySystem"
        case .byMetric: "filter.byMetric"
        case .byService: "filter.byService"
        }
    }
}

struct DashboardLayout: Codable, Equatable, Sendable {
    var orderedPinIDs: [String] = []
    var sortOption: SortOption = .bySystem
    var sortDescending = false

    func sortedPins(
        _ pins: [ResolvedPinnedItem],
        systemNames: [String: String],
        bundle: Bundle
    ) -> [ResolvedPinnedItem] {
        if sortOption == .custom {
            var ranks: [String: Int] = [:]
            for (index, id) in orderedPinIDs.enumerated() where ranks[id] == nil {
                ranks[id] = index
            }
            return pins.enumerated().sorted {
                let lhs = ranks[$0.element.id] ?? (orderedPinIDs.count + $0.offset)
                let rhs = ranks[$1.element.id] ?? (orderedPinIDs.count + $1.offset)
                return lhs < rhs
            }.map(\.element)
        }

        let sortablePins = pins.map { pin in
            SortablePin(
                pin: pin,
                systemName: systemNames[pin.systemID] ?? "",
                displayName: pin.item.localizedDisplayName(for: bundle)
            )
        }
        let sorted = sortablePins.sorted { lhs, rhs in
            if (lhs.pin.item == .systemInfo) != (rhs.pin.item == .systemInfo) {
                return lhs.pin.item == .systemInfo
            }
            let lhsKey: String
            let rhsKey: String
            switch sortOption {
            case .custom, .bySystem:
                lhsKey = lhs.systemName
                rhsKey = rhs.systemName
            case .byMetric:
                lhsKey = lhs.pin.item.metricName
                rhsKey = rhs.pin.item.metricName
            case .byService:
                lhsKey = lhs.pin.item.serviceName
                rhsKey = rhs.pin.item.serviceName
            }
            if lhsKey != rhsKey { return lhsKey < rhsKey }
            if lhs.displayName != rhs.displayName { return lhs.displayName < rhs.displayName }
            return lhs.pin.id < rhs.pin.id
        }.map(\.pin)
        return sortDescending ? Array(sorted.reversed()) : sorted
    }

    private struct SortablePin {
        let pin: ResolvedPinnedItem
        let systemName: String
        let displayName: String
    }
}
