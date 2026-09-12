#if DEBUG
import SwiftUI

/// Network-free GPU fixtures using the production summary, details and pin persistence.
struct GPUChartsUITestView: View {
    @State private var dashboardManager: DashboardManager = {
        let suite = "com.nohitdev.Beszel.GPUChartUITests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return DashboardManager(userDefaults: defaults)
    }()

    static let end = Date(timeIntervalSince1970: 1_788_480_000)
    static let points: [SystemDataPoint] = (0..<30).map { index in
        let wave = Double(index % 10) / 10
        let gpu: String
        if ProcessInfo.processInfo.arguments.contains("--gpu-legacy") {
            gpu = #"{"0":{"n":"GeForce RTX 3090","u":2.4}}"#
        } else {
            gpu = """
            {"0":{"n":"GeForce RTX 3090","mu":\(1004.88 + wave * 12000),"mt":24000,"u":\(2.4 + wave * 60),"p":\(125.05 + wave * 100),"pp":0},
             "i0":{"n":"Intel GPU","u":\(6.52 + wave * 30),"p":\(0.05 + wave * 4),"pp":\(4.09 + wave * 20),"e":{"Blitter":0,"Render/3D":\(0.68 + wave * 50),"Video":\(6.52 + wave * 20),"VideoEnhance":0}}}
            """
        }
        let json = "{\"cpu\":0,\"mu\":0,\"mp\":0,\"du\":0,\"dp\":0,\"g\":\(gpu)}"
        let stats = try! JSONDecoder().decode(SystemStatsDetail.self, from: Data(json.utf8))
        return SystemStatsRecord(id: "gpu-\(index)", created: end.addingTimeInterval(Double(index - 29) * 120), stats: stats, type: "1m")
    }.asDataPoints()
    private static let charts = SystemGPUCharts(dataPoints: points)

    var body: some View {
        NavigationStack {
            ScrollView {
                SystemGPUSummaryChartView(
                    charts: Self.charts, xAxisFormat: .dateTime.hour().minute(), systemID: "gpu-fixture", instanceID: "gpu-fixture-hub"
                )
                .padding()
            }
            .navigationTitle("system.title")
            .monitoringScreenBackground()
            .groupBoxStyle(CardGroupBoxStyle())
            .environment(\.chartXDomain, Self.end.addingTimeInterval(-3600)...Self.end)
        }
        .environment(dashboardManager)
        .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--gpu-dark") ? .dark : .light)
        .dynamicTypeSize(ProcessInfo.processInfo.arguments.contains("--large-text") ? .accessibility3 : .large)
    }
}

#Preview("GPU Details") { GPUChartsUITestView() }
#Preview("GPU without readings") {
    SystemGPUChartView(history: GPUChartData(metric: .power, dataPoints: []), xAxisFormat: .dateTime.hour().minute())
        .groupBoxStyle(CardGroupBoxStyle())
        .padding()
}
#endif
