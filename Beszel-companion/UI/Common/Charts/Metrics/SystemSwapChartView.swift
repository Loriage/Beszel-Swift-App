import SwiftUI
import Charts

struct SystemSwapChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var systemName: String? = nil

    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    private var hasSwapData: Bool {
        dataPoints.contains { $0.swap != nil }
    }

    private var totalSwap: Double {
        dataPoints.compactMap { $0.swap?.total }.max() ?? 0
    }

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
            Text("chart.swapUsage")
                .font(.headline)
                if let systemName = systemName {
                    Text(systemName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
            VStack(spacing: 4) {
            Chart {
                ForEach(dataPoints) { point in
                    if let swap = point.swap {
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
                }
                RuleMark(y: .value("Total", totalSwap))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
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
            .chartLegend(.hidden)
            .padding(.top, 5)
            .frame(height: 185)
            .drawingGroup()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("chart.swapUsage"))
            .accessibilityValue(accessibilityDescription)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle().fill(.orange).frame(width: 8, height: 8)
                    Text("chart.swap.used").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(.gray.opacity(0.5))
                        .frame(width: 12, height: 1.5)
                    Text("chart.swap.total").font(.caption2).foregroundStyle(.secondary)
                }
            }
            }
            .frame(height: 200)
        }
    }

    private var accessibilityDescription: String {
        guard let latest = dataPoints.last?.swap else { return "" }
        return String(format: "Used: %.1f GB of %.1f GB", latest.used, latest.total)
    }
}
