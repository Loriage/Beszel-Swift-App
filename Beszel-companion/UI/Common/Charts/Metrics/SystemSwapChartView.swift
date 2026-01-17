import SwiftUI
import Charts

struct SystemSwapChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    private var hasSwapData: Bool {
        dataPoints.contains { $0.swap != nil }
    }

    var body: some View {
        GroupBox(label: HStack {
            Text("chart.swapUsage")
                .font(.headline)
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
            Chart(dataPoints) { point in
                if let swap = point.swap {
                    Plot {
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Used", swap.used),
                            series: .value("Type", "Used")
                        )
                        .foregroundStyle(.orange)

                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("Type", 0),
                            yEnd: .value("Used", swap.used),
                            series: .value("Type", "Used")
                        )
                        .foregroundStyle(LinearGradient(colors: [.orange.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                    }

                    Plot {
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Total", swap.total),
                            series: .value("Type", "Total")
                        )
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: xAxisFormat, centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let gb = value.as(Double.self) {
                            Text(String(format: "%.1f GB", gb))
                                .font(.caption)
                        }
                    }
                }
            }
            .chartForegroundStyleScale([
                String(localized: "chart.swap.used"): .orange,
                String(localized: "chart.swap.total"): .gray.opacity(0.5)
            ])
            .chartLegend(position: .bottom, alignment: .center)
            .padding(.top, 5)
            .frame(height: 200)
            .drawingGroup()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("chart.swapUsage"))
            .accessibilityValue(accessibilityDescription)
        }
    }

    private var accessibilityDescription: String {
        guard let latest = dataPoints.last?.swap else { return "" }
        return String(format: "Used: %.1f GB of %.1f GB", latest.used, latest.total)
    }
}
