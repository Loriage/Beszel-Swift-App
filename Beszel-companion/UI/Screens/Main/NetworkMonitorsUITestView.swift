#if DEBUG
import SwiftUI

struct NetworkMonitorsUITestView: View {
    @State private var monitoring: NetworkMonitorStore = {
        let instance = Instance(id: UUID(), name: "Fixture", url: "https://fixture.invalid", email: "fixture@example.invalid")
        let api = BeszelAPIService(instance: instance, instanceManager: InstanceManager.shared, testToken: "fixture") { _ in
            throw URLError(.notConnectedToInternet)
        }
        let store = NetworkMonitorStore(api: api)
        store.loadFixture(monitors: NetworkMonitorFixtures.monitors, records: NetworkMonitorFixtures.records)
        return store
    }()
    @State private var dashboard: DashboardManager = {
        let defaults = UserDefaults(suiteName: "com.nohitdev.Beszel.NetworkMonitorUITests")!
        defaults.removePersistentDomain(forName: "com.nohitdev.Beszel.NetworkMonitorUITests")
        return DashboardManager(userDefaults: defaults)
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                NetworkMonitorsCard(system: NetworkMonitorFixtures.system, monitoring: monitoring).padding()
            }
            .navigationTitle("system.title")
            .groupBoxStyle(CardGroupBoxStyle())
            .monitoringScreenBackground()
        }
        .environment(SettingsManager())
        .environment(InstanceManager.shared)
        .environment(dashboard)
        .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--monitor-dark") ? .dark : .light)
        .dynamicTypeSize(ProcessInfo.processInfo.arguments.contains("--large-text") ? .accessibility3 : .large)
    }
}

enum NetworkMonitorFixtures {
    static let now = Date()
    static let system = try! JSONDecoder().decode(SystemRecord.self, from: Data(#"{"id":"server1","name":"Home Server","status":"up","info":{"v":"0.20.0"}}"#.utf8))
    static let monitors: [NetworkMonitorRecord] = [
        makeMonitor(id: "icmp1", target: "1.1.1.1", protocol: "icmp"),
        makeMonitor(id: "http1", target: "https://example.com", protocol: "http"),
        makeMonitor(id: "tcp1", target: "nas.local", protocol: "tcp", enabled: false),
        makeMonitor(id: "dns1", target: "example.com", protocol: "dns")
    ]
    static let records = monitors.flatMap { monitor in
        (0..<60).compactMap { index -> NetworkMonitorStatsRecord? in
            // A gap is deliberately distinct from a failed probe.
            guard !(28...30).contains(index) else { return nil }
            let success: Int64 = index == 41 ? 0 : (index == 40 ? 1 : 2)
            let response = 8_000 + Double(index % 8) * 400 + (index == 20 ? 18_000 : 0)
            return NetworkMonitorStatsRecord(
                id: "\(monitor.id)-\(index)", system: "server1", monitor: monitor.id,
                created: now.addingTimeInterval(Double(index - 59) * 60).timeIntervalSince1970 * 1000,
                type: "1m", totalCount: 2, successCount: success,
                responseSum: Double(success) * response, responseMin: success > 0 ? response * 0.8 : 0,
                responseMax: success > 0 ? response * 1.3 : 0
            )
        }
    }

    static func makeMonitor(id: String, target: String, protocol kind: String, enabled: Bool = true) -> NetworkMonitorRecord {
        NetworkMonitorRecord(
            id: id, system: "server1", target: target, protocol: kind, port: kind == "tcp" ? 443 : 0,
            interval: 30, enabled: enabled, res: 9600, resAvg1h: 10200, resMin1h: 6400, resMax1h: 28000,
            loss1h: 2.5, updated: DateFormatter.pocketBase.string(from: now)
        )
    }
}
#endif
