import SwiftUI
import Charts

struct SystemNetworkInterfacesChartView: View {
    @Environment(\.chartXDomain) private var chartXDomain
    @Environment(\.chartShowXGridLines) private var chartShowXGridLines
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
                (Text("chart.networkInterfaces") + Text(" (\(yAxisUnit))"))
                    .font(.headline)
                if systemName == nil {
                    Text("chart.networkInterfaces.subtitle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let systemName = systemName {
                    Text(systemName)
                        .font(.caption2)
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
            AxisMarks(values: insetTickDates(for: chartXDomain)) { _ in
                    if chartShowXGridLines {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    }
                    AxisValueLabel(format: xAxisFormat, anchor: .top, collisionResolution: .disabled)
                        .font(.caption2)
                }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let bytes = value.as(Double.self) {
                        Text(formatNumber(bytes)).font(.caption2).padding(.trailing, 6)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartXScaleIfNeeded(chartXDomain)
        .padding(.top, 5)
        .drawingGroup()
    }

    private var maxTotal: Double {
        dataPoints.flatMap { $0.networkInterfaces.map { $0.sent + $0.received } }.max() ?? 0
    }

    private var yAxisUnit: String {
        if maxTotal >= 1_073_741_824 { return "GB" }
        if maxTotal >= 1_048_576     { return "MB" }
        if maxTotal >= 1024          { return "KB" }
        return "B"
    }

    private func formatNumber(_ bytes: Double) -> String {
        func fmt(_ v: Double) -> String {
            v.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", v) : String(format: "%.1f", v)
        }
        if bytes == 0 { return "0" }
        if bytes >= 1_073_741_824 { return fmt(bytes / 1_073_741_824) }
        if bytes >= 1_048_576     { return fmt(bytes / 1_048_576) }
        if bytes >= 1024          { return fmt(bytes / 1024) }
        return String(format: "%.0f", bytes)
    }
}
