import SwiftUI
import Charts

struct SystemNetworkInterfacesChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var systemName: String? = nil

    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    private var interfaceNames: [String] {
        let allNames = dataPoints.flatMap { $0.networkInterfaces.map(\.name) }
        return Array(Set(allNames)).sorted()
    }

    private var hasInterfaceData: Bool {
        dataPoints.contains { !$0.networkInterfaces.isEmpty }
    }

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
            Text("chart.networkInterfaces")
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

                if !interfaceNames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(interfaceNames, id: \.self) { name in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(color(for: name, in: interfaceNames))
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
            ForEach(point.networkInterfaces) { iface in
                let total = iface.sent + iface.received
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Bandwidth", total)
                )
                .foregroundStyle(by: .value("Interface", iface.name))
            }
        }
        .chartForegroundStyleScale { name in
            color(for: name, in: interfaceNames)
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
                    if let bytes = value.as(Double.self) {
                        Text(formatBytes(bytes))
                            .font(.caption)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .padding(.top, 5)
        .drawingGroup()
    }

    private func formatBytes(_ bytes: Double) -> String {
        if bytes >= 1_073_741_824 {
            return String(format: "%.1f GB", bytes / 1_073_741_824)
        } else if bytes >= 1_048_576 {
            return String(format: "%.1f MB", bytes / 1_048_576)
        } else if bytes >= 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else {
            return String(format: "%.0f B", bytes)
        }
    }
}
