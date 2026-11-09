#if DEBUG
import SwiftUI

/// Network-free coverage for a metric's first reading and sub-GB root disks.
struct LiveMetricsUITestView: View {
    private static let end = Date(timeIntervalSince1970: 1_800_000_000)
    private static let points: [SystemDataPoint] = {
        let json = #"{"cpu":10,"mu":1,"mp":20,"du":0.25,"dp":50,"d":0.5,"efs":{"New disk":{"d":228.4,"du":123.0}}}"#
        let stats = try! JSONDecoder().decode(SystemStatsDetail.self, from: Data(json.utf8))
        return [SystemStatsRecord(id: "live", created: end, stats: stats, type: "1m")].asDataPoints()
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SystemDiskUsageChartView(dataPoints: Self.points, xAxisFormat: .dateTime.hour().minute())
                    ExtraDiskUsageChartView(diskName: "New disk", dataPoints: Self.points, xAxisFormat: .dateTime.hour().minute())
                }.padding()
            }
            .navigationTitle("First metric readings")
            .groupBoxStyle(CardGroupBoxStyle())
            .environment(\.chartXDomain, Self.end.addingTimeInterval(-3_600)...Self.end.addingTimeInterval(120))
        }
    }
}
#endif
