import Foundation
import Observation

@Observable @MainActor
final class NetworkMonitorStore {
    private(set) var monitors: [NetworkMonitorRecord] = []
    private(set) var charts: [String: NetworkMonitorChartData] = [:]
    private(set) var isSupported = false
    private(set) var canManage = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var historyError: String?
    private var records: [NetworkMonitorStatsRecord] = []
    private var loadedRange: TimeRangeOption?
    private var generation = 0
    private let api: BeszelAPIService

    init(api: BeszelAPIService) { self.api = api }

    func monitors(for systemID: String) -> [NetworkMonitorRecord] {
        monitors.filter { $0.system == systemID }
    }

    func target(for item: PinnedItem, systemID: String) -> String? {
        switch item {
        case .networkMonitorLatency(let id), .networkMonitorLoss(let id):
            return monitors.first { $0.id == id && $0.system == systemID }?.targetLabel
        default: return nil
        }
    }

    func clear() {
        generation += 1
        monitors = []
        charts = [:]
        records = []
        loadedRange = nil
        isSupported = false
        canManage = false
        isLoading = false
        errorMessage = nil
        historyError = nil
    }

    func refresh(range: TimeRangeOption, includeHistory: Bool = true) async {
        // A quick status refresh must not supersede a history request already in flight.
        if !includeHistory && isLoading { return }
        generation += 1
        let request = generation
        isLoading = true
        errorMessage = nil
        if loadedRange != range {
            records = []
            charts = [:]
            loadedRange = nil
        }
        defer { if generation == request { isLoading = false } }
        do {
            let fetched = try await api.fetchNetworkMonitors()
            try Task.checkCancellation()
            guard generation == request else { return }
            isSupported = true
            monitors = fetched.sorted { $0.targetLabel.localizedStandardCompare($1.targetLabel) == .orderedAscending }
            rebuildCharts(range: range)
            if includeHistory {
                do {
                    let history = fetched.isEmpty ? [] : try await api.fetchNetworkMonitorStats(range: range)
                    try Task.checkCancellation()
                    guard generation == request else { return }
                    records = history
                    loadedRange = range
                    historyError = nil
                    rebuildCharts(range: range)
                } catch {
                    guard !Task.isCancelled, generation == request else { return }
                    historyError = String(localized: "monitor.history.unavailable")
                }
                let permission = (try? await api.canManageNetworkMonitors()) ?? false
                guard !Task.isCancelled, generation == request else { return }
                canManage = permission
            }
        } catch BeszelAPIService.BeszelAPIError.httpError(statusCode: 404) {
            guard generation == request else { return }
            clear()
        } catch {
            guard !Task.isCancelled, generation == request else { return }
            errorMessage = String(localized: "monitor.unavailable")
        }
    }

    private func rebuildCharts(range: TimeRangeOption) {
        let grouped = Dictionary(grouping: records, by: \.monitor)
        charts = Dictionary(uniqueKeysWithValues: monitors.map {
            ($0.id, NetworkMonitorChartData(monitor: $0, records: grouped[$0.id] ?? [], expectedInterval: range.expectedInterval))
        })
    }

    func save(_ configuration: NetworkMonitorConfiguration, id: String?, range: TimeRangeOption) async throws {
        try await api.saveNetworkMonitor(configuration, id: id)
        await refresh(range: range)
    }

    func setEnabled(_ monitor: NetworkMonitorRecord, range: TimeRangeOption) async throws {
        try await api.setNetworkMonitorEnabled(id: monitor.id, enabled: !monitor.enabled)
        await refresh(range: range)
    }

    func delete(_ monitor: NetworkMonitorRecord, range: TimeRangeOption) async throws {
        try await api.deleteNetworkMonitor(id: monitor.id)
        await refresh(range: range)
    }

    #if DEBUG
    func loadFixture(monitors: [NetworkMonitorRecord], records: [NetworkMonitorStatsRecord]) {
        self.monitors = monitors
        self.records = records
        isSupported = true
        canManage = true
        loadedRange = .lastHour
        rebuildCharts(range: .lastHour)
    }
    #endif
}
