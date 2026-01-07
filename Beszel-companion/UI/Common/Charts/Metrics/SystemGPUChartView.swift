import SwiftUI
import Charts

struct SystemGPUChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    private var gpuNames: [String] {
        let allNames = dataPoints.flatMap { $0.gpuMetrics.map(\.name) }
        return Array(Set(allNames)).sorted()
    }

    private var hasGPUData: Bool {
        dataPoints.contains { !$0.gpuMetrics.isEmpty }
    }

    var body: some View {
        GroupBox(label: HStack {
            Text("chart.gpuUsage")
                .font(.headline)
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
            VStack(spacing: 8) {
                chartBody

                if !gpuNames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(gpuNames, id: \.self) { name in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(color(for: name, in: gpuNames))
                                        .frame(width: 8, height: 8)
                                    Text(name)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .frame(height: 20)
                }
            }
            .frame(height: 220)
        }
    }

    private var chartBody: some View {
        Chart(dataPoints) { point in
            ForEach(point.gpuMetrics) { gpu in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Usage", gpu.usage)
                )
                .foregroundStyle(by: .value("GPU", gpu.name))

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Usage", gpu.usage)
                )
                .foregroundStyle(by: .value("GPU", gpu.name))
                .opacity(0.2)
            }
        }
        .chartForegroundStyleScale { name in
            color(for: name, in: gpuNames)
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
                    if let percent = value.as(Double.self) {
                        Text(String(format: "%.0f%%", percent))
                            .font(.caption)
                    }
                }
            }
        }
        .chartYScale(domain: 0...100)
        .chartLegend(.hidden)
        .padding(.top, 5)
        .drawingGroup()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("chart.gpuUsage"))
        .accessibilityValue(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        guard let latest = dataPoints.last, !latest.gpuMetrics.isEmpty else { return "" }
        let descriptions = latest.gpuMetrics.map { "\($0.name): \(String(format: "%.0f", $0.usage))%" }
        return descriptions.joined(separator: ", ")
    }
}
