import SwiftUI

struct WidgetSystemSummaryView: View {
    let systemInfo: SystemInfo?
    let systemDetails: SystemDetailsRecord?
    let stats: SystemStatsDetail
    let systemName: String
    let status: String?

    /// CPU model from either system_details endpoint (0.18.0+) or legacy info field
    private var cpuModel: String? {
        if let cpu = systemDetails?.cpu {
            return cpu
        }
        return systemInfo?.m
    }

    /// CPU cores from either system_details endpoint (0.18.0+) or legacy info field
    private var cpuCores: Int? {
        if let cores = systemDetails?.cores {
            return cores
        }
        return systemInfo?.c
    }

    private var networkBytesPerSecond: Double {
        if let bandwidth = stats.bandwidth, bandwidth.count >= 2 {
            return bandwidth[0] + bandwidth[1]
        }
        return ((stats.networkReceived ?? 0) + (stats.networkSent ?? 0)) * 1_048_576
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(systemName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    StatusBadge(status: status, uptime: systemInfo?.u)
                }
                
                if let model = cpuModel {
                    Text(model)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Divider()

            VStack(spacing: 6) {
                WidgetMetricRow(label: "metric.cpu.short", value: stats.cpu / 100, displayValue: MetricFormatter.percent(stats.cpu))
                WidgetMetricRow(label: "metric.memory.short", value: stats.memoryPercent / 100, displayValue: MetricFormatter.percent(stats.memoryPercent))
                WidgetMetricRow(label: "metric.disk.short", value: stats.diskPercent / 100, displayValue: MetricFormatter.percent(stats.diskPercent))
                
                HStack {
                    if let load = stats.load, let oneMin = load.first {
                         HStack(spacing: 8) {
                            Text("metric.systemLoad.short")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            Image(systemName: loadIcon(oneMin))
                                .font(.caption2)
                                .foregroundStyle(colorForLoad(oneMin))
                                .accessibilityHidden(true)
                             Text(load.map { String(format: "%.2f", $0) }.joined(separator: " "))
                                .font(.caption2)
                                .monospacedDigit()
                        }
                    }
                    
                    Spacer()

                    HStack(spacing: 6) {
                        Text("metric.network.short")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        Text(MetricFormatter.throughput(bytesPerSecond: networkBytesPerSecond))
                            .font(.caption2)
                            .monospacedDigit()
                    }
                }
            }
        }
    }
    
    private func colorForLoad(_ val: Double) -> Color {
        guard let cores = cpuCores, cores > 0 else { return .green }
        let limit = Double(cores)
        if val >= limit * 1.5 { return .red }
        else if val >= limit { return .orange }
        else { return .green }
    }

    private func loadIcon(_ value: Double) -> String {
        guard let cores = cpuCores, cores > 0 else { return "questionmark.circle.fill" }
        let limit = Double(cores)
        if value >= limit * 1.5 { return "exclamationmark.triangle.fill" }
        if value >= limit { return "exclamationmark.circle.fill" }
        return "checkmark.circle.fill"
    }
}

struct StatusBadge: View {
    let status: String?
    let uptime: Double?

    private var semanticStatus: MonitoringStatus {
        MonitoringStatus(status)
    }
    
    var body: some View {
        if status != nil {
            HStack(spacing: 4) {
                Image(systemName: semanticStatus.iconName)
                    .accessibilityHidden(true)
                if semanticStatus == .operational, let uptime {
                    Text(formatUptime(uptime))
                        .monospacedDigit()
                } else {
                    Text(semanticStatus.title)
                }
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(semanticStatus.color)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(semanticStatus.title))
            .accessibilityValue(
                semanticStatus == .operational
                    ? uptime.map(formatUptime) ?? ""
                    : ""
            )
        }
    }
    
    private func formatUptime(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(seconds)) ?? ""
    }
}

struct WidgetMetricRow: View {
    let label: LocalizedStringResource
    let value: Double
    let displayValue: String
    
    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .monospaced()
                .foregroundStyle(.secondary)
                .frame(width: 25, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 5)
                    
                    Capsule()
                        .fill(colorForValue(value))
                        .frame(width: max(0, min(geometry.size.width * CGFloat(value), geometry.size.width)), height: 5)
                }
                .frame(height: 5)
                .frame(maxHeight: .infinity, alignment: .center)
            }
            
            Text(displayValue)
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(width: 40, alignment: .trailing)
        }
        .frame(height: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(displayValue)
    }
    
    private func colorForValue(_ val: Double) -> Color {
        if val < 0.6 { return .green }
        if val < 0.8 { return .orange }
        return .red
    }
}
