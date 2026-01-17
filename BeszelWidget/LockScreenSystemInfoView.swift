import SwiftUI
import WidgetKit

struct LockScreenSystemInfoView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let systemName: String
    let status: String?
    let stats: SystemStatsDetail?
    let metric: LockScreenMetric

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            EmptyView()
        }
    }

    private var circularView: some View {
        Group {
            if let stats {
                let metricValue = metric.value(from: stats)
                let tintColor = status == "down" ? statusColor : metricColor(metricValue)
                VStack(spacing: 1) {
                    CircularGaugeView(
                        value: metricValue,
                        label: metric.shortLabel,
                        displayValue: formatPercent(metricValue),
                        tintColor: tintColor
                    )

                    Text(systemName)
                        .font(.caption2)
                        .lineLimit(1)
                }
            } else {
                LockScreenNoDataView()
                    .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private var rectangularView: some View {
        Group {
            if let stats {
                VStack(spacing: 1) {
                    VStack(spacing: 2) {
                        LockScreenMetricGaugeRow(label: "CPU", value: stats.cpu)
                        LockScreenMetricGaugeRow(label: "MEM", value: stats.memoryPercent)
                        LockScreenMetricGaugeRow(label: "DSK", value: stats.diskPercent)
                    }
                    HStack(spacing: 6) {
                        Text(systemName)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            } else {
                LockScreenNoDataView()
                    .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private var inlineView: some View {
        Group {
            if let stats {
                let metricValue = metric.value(from: stats)
                HStack(spacing: 4) {
                    statusDot
                    Text("\(systemName) \(metric.shortLabel) \(formatPercent(metricValue))")
                        .lineLimit(1)
                }
                .font(.caption2)
                .frame(maxHeight: .infinity, alignment: .center)
            } else {
                Text("widget.noData")
                    .font(.caption2)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 6, height: 6)
    }

    private var statusColor: Color {
        switch status {
        case "up":
            return .green
        case "down":
            return .red
        case "paused":
            return .yellow
        case "pending":
            return .orange
        default:
            return .gray
        }
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    private func metricColor(_ value: Double) -> Color {
        if value < 60 { return .green }
        if value < 80 { return .orange }
        return .red
    }
}

struct LockScreenNoDataView: View {
    var body: some View {
        Text("widget.noData")
            .font(.caption2)
            .foregroundColor(.secondary)
    }
}

struct LockScreenMetricGaugeRow: View {
    let label: String
    let value: Double

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .monospaced()
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(height: 6)

                    Capsule()
                        .fill(colorForValue(value))
                        .frame(width: max(0, min(geometry.size.width * CGFloat(value / 100.0), geometry.size.width)), height: 6)
                }
                .frame(height: 6)
                .frame(maxHeight: .infinity, alignment: .center)
            }

            Text(String(format: "%.0f%%", value))
                .font(.caption)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundColor(.primary)
                .frame(width: 30, alignment: .trailing)
        }
        .frame(height: 14)
    }

    private func colorForValue(_ value: Double) -> Color {
        if value < 60 { return .green }
        if value < 80 { return .orange }
        return .red
    }
}

struct CircularGaugeView: View {
    let value: Double
    let label: String
    let displayValue: String
    let tintColor: Color

    private let startTrim: CGFloat = 0.15
    private let endTrim: CGFloat = 0.85

    var body: some View {
        ZStack {
            Circle()
                .trim(from: startTrim, to: endTrim)
                .stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(90))

            Circle()
                .trim(from: startTrim, to: progressTrim)
                .stroke(tintColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(90))

            Text(displayValue)
                .font(.caption)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .monospaced()
                .foregroundColor(.secondary)
                .offset(y: 16)
        }
        .frame(width: 48, height: 48, alignment: .center)
        .padding(.top, 4)
    }

    private var progressTrim: CGFloat {
        let clamped = max(0, min(value / 100.0, 1))
        return startTrim + (endTrim - startTrim) * CGFloat(clamped)
    }
}
