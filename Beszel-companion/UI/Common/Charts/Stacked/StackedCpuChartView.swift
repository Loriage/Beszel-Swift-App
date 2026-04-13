import SwiftUI
import Charts

struct StackedCpuChartView: View {
    let stackedData: [StackedCpuData]
    let domain: [String]
    
    @Environment(SettingsManager.self) var settingsManager
    @Environment(\.chartXDomain) private var chartXDomain
    
    let systemID: String?
    var systemName: String? = nil
    
    private var uniqueDates: [Date] {
        Array(Set(stackedData.map { $0.date })).sorted()
    }
    
    var body: some View {
        NavigationLink(destination: DetailedCpuChartView(
            stackedData: stackedData,
            domain: domain,
            uniqueDates: uniqueDates,
            xAxisFormat: settingsManager.selectedTimeRange.xAxisFormat,
            systemID: systemID,
            settingsManager: settingsManager,
            xDomain: chartXDomain
        )) {
            GroupBox(label: HStack {
                VStack(alignment: .leading, spacing: 2) {
                    (Text("charts.stacked_cpu.title") + Text(" (%)"))
                        .font(.headline)
                    if systemName == nil {
                        Text("charts.stacked_cpu.subtitle")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if let systemName = systemName {
                        Text(systemName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }) {
                ZStack {
                    Chart(stackedData) { data in
                        AreaMark(
                            x: .value("Date", data.date),
                            yStart: .value("Start", data.yStart),
                            yEnd: .value("End", data.yEnd)
                        )
                        .foregroundStyle(by: .value("Conteneur", data.name))
                        .interpolationMethod(.monotone)
                    }
                    .chartForegroundStyleScale(domain: domain, range: gradientRange(for: domain))
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(String(format: "%.0f", v)).font(.caption2).padding(.trailing, 6)
                                }
                            }
                        }
                    }
                    .padding(.top, 5)
                    .drawingGroup()
                }
                .commonChartCustomization(xAxisFormat: settingsManager.selectedTimeRange.xAxisFormat, xDomain: chartXDomain)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
