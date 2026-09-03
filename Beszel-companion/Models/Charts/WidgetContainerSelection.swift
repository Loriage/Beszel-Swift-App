import Foundation

/// Container history is keyed by service name, not by an individual deployment's ID.
/// Keep that name scoped to its hub and system so a redeployment can retain the widget.
nonisolated struct WidgetContainerSelection: Hashable, Sendable {
    let instanceID: UUID
    let systemID: String
    let name: String

    init(instanceID: UUID, systemID: String, name: String) {
        self.instanceID = instanceID
        self.systemID = systemID
        self.name = name
    }

    var id: String {
        "v1:" + [instanceID.uuidString, systemID, name]
            .map { Data($0.utf8).base64EncodedString() }
            .joined(separator: ":")
    }

    init?(id: String) {
        let components = id.split(separator: ":", omittingEmptySubsequences: false)
        guard components.count == 4, components[0] == "v1" else { return nil }
        let values = components.dropFirst().compactMap { component -> String? in
            guard let data = Data(base64Encoded: String(component)) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        guard values.count == 3, let instanceID = UUID(uuidString: values[0]),
              !values[1].isEmpty, !values[2].isEmpty else { return nil }
        self.init(instanceID: instanceID, systemID: values[1], name: values[2])
    }

    func latestRecord(in records: [ContainerRecord]) -> ContainerRecord? {
        records.filter { $0.system == systemID && $0.name == name }
            .max { $0.updated < $1.updated }
    }

    func matches(instanceID: String?, systemID: String?) -> Bool {
        UUID(uuidString: instanceID ?? "") == self.instanceID && systemID == self.systemID
    }

    func availability(in records: [ContainerRecord]) -> WidgetContainerAvailability {
        guard let record = latestRecord(in: records) else { return .missing }
        switch record.runtimeState {
        case .running: return .running
        case .stopped: return .stopped
        case .unknown: return .unavailable
        }
    }

    func history(in records: [ContainerStatsRecord]) -> [StatPoint] {
        records.filter { $0.system == systemID }.compactMap { record in
            guard let stat = record.stats.first(where: { $0.name == name }) else { return nil }
            return StatPoint(
                date: record.created, cpu: stat.cpu, memory: stat.memory,
                netSent: stat.netSent ?? 0, netReceived: stat.netReceived ?? 0
            )
        }
        .sorted { $0.date < $1.date }
    }

    static func runningSelections(
        in records: [ContainerRecord], instanceID: UUID, systemID: String, search: String = ""
    ) -> [Self] {
        let names = Set(records.filter { $0.system == systemID }.map(\.name))
        let search = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .compactMap { name in
                let selection = Self(instanceID: instanceID, systemID: systemID, name: name)
                guard selection.latestRecord(in: records)?.runtimeState == .running,
                      search.isEmpty || name.localizedStandardContains(search) else { return nil }
                return selection
            }
    }
}

nonisolated enum WidgetContainerAvailability: Equatable, Sendable {
    case running
    case stopped
    case missing
    case unavailable
    case notConfigured
    case selectionChanged
}

public nonisolated enum DockerWidgetMetric: String, CaseIterable, Sendable {
    case cpu
    case memory
    case network

    public var title: LocalizedStringResource {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .network: "widget.docker.network"
        }
    }

    var chartType: WidgetChartType {
        switch self {
        case .cpu: .containerCPU
        case .memory: .containerMemory
        case .network: .containerNetwork
        }
    }
}
