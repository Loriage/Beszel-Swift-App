import SwiftUI
import Charts

struct StackedMemoryChartView: View {
    let stackedData: [StackedMemoryData]
    let domain: [String]
    
    @Environment(SettingsManager.self) var settingsManager
    
    let systemID: String?
    var systemName: String? = nil
    
    private var uniqueDates: [Date] {
        Array(Set(stackedData.map { $0.date })).sorted()
    }
    
    private var maxMemory: Double {
        stackedData.max(by: { $0.yEnd < $1.yEnd })?.yEnd ?? 0
    }
    
    var memoryUnit: String {
        maxMemory >= 1024 ? "GB" : "MB"
    }
    
    var memoryLabelScale: Double {
        maxMemory >= 1024 ? 1024 : 1
    }
    
    private var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }
    
    var body: some View {
        NavigationLink(destination: DetailedMemoryChartView(
            stackedData: stackedData,
            domain: domain,
            uniqueDates: uniqueDates,
            memoryUnit: memoryUnit,
            memoryLabelScale: memoryLabelScale,
            xAxisFormat: xAxisFormat,
            systemID: systemID,
            settingsManager: settingsManager
        )) {
            GroupBox(label: HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("charts.stacked_memory.title \(memoryUnit)")
                        .font(.headline)
                    if let systemName = systemName {
                        Text(systemName)
                            .font(.caption)
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
                        AxisMarks { value in
                            if let yValue = value.as(Double.self) {
                                let scaledValue = yValue / memoryLabelScale
                                let labelText = String(format: "%.1f", scaledValue)
                                AxisGridLine()
                                AxisValueLabel {
                                    Text(labelText)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .padding(.top, 5)
                    .drawingGroup()
                }
                .commonChartCustomization(xAxisFormat: xAxisFormat)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
