import SwiftUI
import Charts

struct SystemExtraFilesystemsChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var systemName: String? = nil

    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    private var filesystemNames: [String] {
        let allNames = dataPoints.flatMap { $0.extraFilesystems.map(\.name) }
        return Array(Set(allNames)).sorted()
    }

    private var hasFilesystemData: Bool {
        dataPoints.contains { !$0.extraFilesystems.isEmpty }
    }

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
            Text("chart.extraFilesystems")
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
            VStack(spacing: 8) {
                chartBody

                if !filesystemNames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(filesystemNames, id: \.self) { name in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(color(for: name, in: filesystemNames))
                                        .frame(width: 8, height: 8)
                                    Text(name)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
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
            ForEach(point.extraFilesystems) { fs in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Usage", fs.percent)
                )
                .foregroundStyle(by: .value("Filesystem", fs.name))

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Usage", fs.percent)
                )
                .foregroundStyle(by: .value("Filesystem", fs.name))
                .opacity(0.2)
            }
        }
        .chartForegroundStyleScale { name in
            color(for: name, in: filesystemNames)
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
    }
}
