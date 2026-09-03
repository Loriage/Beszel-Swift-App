#if DEBUG
import SwiftUI

/// Deterministic, network-free UI coverage. This screen is absent from Release builds
/// and does not save a hub, credentials, or changes to monitoring settings.
struct Beszel019UITestView: View {
    let legacy: Bool
    private static let end = Date(timeIntervalSince1970: 1_788_480_000)
    private static let stats: SystemStatsDetail = {
        var stats = SystemStatsDetail.sample()
        stats.zfsPools = ["tank": ZFSPoolStats(d: 512, du: 128, rb: 2_000_000, wb: 1_000_000, h: "DEGRADED")]
        stats.diskIOTotals = [20_000_000_000, 12_000_000_000]
        return stats
    }()
    private static let points: [SystemDataPoint] = (0..<30).map { index in
        var stats = Self.stats
        stats.diskIOTotals = [Double(index + 1) * 1_000_000_000, Double(index + 1) * 500_000_000]
        stats.zfsPools = ["tank": ZFSPoolStats(
            d: 512, du: 120 + Double(index) / 4,
            rb: index == 20 ? 8_000_000 : 2_000_000,
            wb: index == 12 ? 4_000_000 : 1_000_000, h: "DEGRADED"
        )]
        return SystemStatsRecord(id: "fixture-\(index)", created: end.addingTimeInterval(Double(index - 29) * 120), stats: stats, type: "1m")
    }.asDataPoints()
    private static let pool = ZFSPoolRecord(
        id: "pool1", system: "server1", name: "tank", health: "DEGRADED",
        size: 549_755_813_888, alloc: 137_438_953_472, free: 412_316_860_416,
        scrub: ZFSScrub(state: "FINISHED", progress: nil, errors: 2),
        vdevs: [ZFSVdev(name: "mirror-0", state: "DEGRADED", readErrs: 0, writeErrs: 0, checksumErrs: 2)],
        datasets: [ZFSDataset(name: "tank/backups", used: 107_374_182_400, avail: 412_316_860_416, mount: "/backups")],
        detailsUpdated: "2026-09-04 08:00:00.000Z"
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("System SSD").font(.title2.bold())
                    SystemDiskUsageChartView(
                        dataPoints: Self.points, xAxisFormat: .dateTime.hour().minute(), diskName: "System SSD"
                    )
                    if !legacy {
                        ZFSPoolsCard(
                            names: ["tank"], stats: Self.stats.zfsPools ?? [:], records: [Self.pool],
                            dataPoints: Self.points, xAxisFormat: .dateTime.hour().minute(), detailsUnavailable: false
                        )
                        StorageHistoryChart(metric: .cumulativeRead(disk: nil), dataPoints: Self.points, xAxisFormat: .dateTime.hour().minute())
                        StorageHistoryChart(metric: .cumulativeWrite(disk: nil), dataPoints: Self.points, xAxisFormat: .dateTime.hour().minute())
                    }
                }
                .padding()
            }
            .navigationTitle(legacy ? "Legacy hub fixture" : "Beszel 0.19 fixture")
            .monitoringScreenBackground()
            .groupBoxStyle(CardGroupBoxStyle())
            .environment(\.chartXDomain, Self.end.addingTimeInterval(-3_600)...Self.end)
        }
        .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--ui-testing-dark") ? .dark : .light)
        .dynamicTypeSize(ProcessInfo.processInfo.arguments.contains("--ui-testing-large-text") ? .accessibility3 : .large)
    }
}
#endif
