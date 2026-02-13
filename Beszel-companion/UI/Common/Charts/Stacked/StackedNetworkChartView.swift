import SwiftUI
import Charts

struct StackedNetworkChartView: View {
    let stackedData: [StackedNetworkData]
    let domain: [String]

    @Environment(SettingsManager.self) var settingsManager

    let systemID: String?
    var systemName: String? = nil

    private var uniqueDates: [Date] {
        Array(Set(stackedData.map { $0.date })).sorted()
    }

    private var maxNetwork: Double {
        stackedData.max(by: { $0.yEnd < $1.yEnd })?.yEnd ?? 0
    }

    var networkUnit: String {
        maxNetwork >= 1 ? "MB/s" : "KB/s"
    }

    var networkLabelScale: Double {
        maxNetwork >= 1 ? 1 : 0.001
    }

    private var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }

    var body: some View {
        NavigationLink(destination: DetailedNetworkChartView(
            stackedData: stackedData,
            domain: domain,
            uniqueDates: uniqueDates,
            networkUnit: networkUnit,
            networkLabelScale: networkLabelScale,
            xAxisFormat: xAxisFormat,
            systemID: systemID,
            settingsManager: settingsManager
        )) {
            GroupBox(label: HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("charts.stacked_network.title \(networkUnit)")
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
                                let scaledValue = yValue / networkLabelScale
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
