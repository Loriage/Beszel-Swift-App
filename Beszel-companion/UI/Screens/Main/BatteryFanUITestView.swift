#if DEBUG
import SwiftUI

/// Synthetic sensor history only; never contacts a hub or persists pin/settings changes.
struct BatteryFanUITestView: View {
    @State private var batteryPinned = false
    @State private var fansPinned = false

    private static let end = Date(timeIntervalSince1970: 1_788_480_000)
    private static let charts = SystemSensorCharts(dataPoints: points(legacy: false))
    private static let legacyCharts = SystemSensorCharts(dataPoints: points(legacy: true))

    private static func points(legacy: Bool) -> [SystemDataPoint] {
        (0..<30).map { index in
            var point = [SystemStatsRecord(
                id: "sensor-\(index)", created: end.addingTimeInterval(Double(index - 29) * 120),
                stats: .sample(), type: "1m"
            )].asDataPoints()[0]
            point.batteryPercent = 90 - Double(index)
            if !legacy {
                point.batteries = ["BAT0": 90 - Double(index), "BAT1": 80 - Double(index) / 2]
                point.fans = ["CPU": 1_200 + Double(index % 6) * 200, "Case": 850 + Double(index % 4) * 100, "Stopped": 0]
                if index == 12 || index == 13 { point.fans.removeValue(forKey: "Case") }
            }
            return point
        }
    }

    var body: some View {
        let arguments = ProcessInfo.processInfo.arguments
        let charts = arguments.contains("--no-sensors") ? .empty
            : arguments.contains("--legacy-battery") ? Self.legacyCharts : Self.charts
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if charts.battery.series.isEmpty && charts.fans.series.isEmpty {
                        Text(verbatim: "No sensor data")
                    }
                    if !charts.battery.series.isEmpty {
                        SensorHistoryChart(
                            history: charts.battery, xAxisFormat: .dateTime.hour().minute(),
                            isPinned: batteryPinned, onPinToggle: { batteryPinned.toggle() }
                        )
                    }
                    if !charts.fans.series.isEmpty {
                        SensorHistoryChart(
                            history: charts.fans, xAxisFormat: .dateTime.hour().minute(),
                            isPinned: fansPinned, onPinToggle: { fansPinned.toggle() }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Sensor charts")
            .monitoringScreenBackground()
            .groupBoxStyle(CardGroupBoxStyle())
            .environment(\.chartXDomain, Self.end.addingTimeInterval(-3_600)...Self.end)
        }
        .dynamicTypeSize(arguments.contains("--large-text") ? .accessibility3 : .large)
    }
}
#endif
