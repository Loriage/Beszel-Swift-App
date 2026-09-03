import SwiftUI

struct SystemSummaryCard: View {
    @Environment(InstanceManager.self) private var instanceManager

    let system: SystemRecord?
    let systemInfo: SystemInfo?
    let stats: SystemStatsDetail
    let systemName: String
    let status: String?

    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    /// CPU model from either system_details endpoint (0.18.0+) or legacy info field
    private var cpuModel: String? {
        if let system = system {
            return instanceManager.cpuModel(for: system)
        }
        return systemInfo?.m
    }

    /// CPU cores from either system_details endpoint (0.18.0+) or legacy info field
    private var cpuCores: Int? {
        if let system = system {
            return instanceManager.cpuCores(for: system)
        }
        return systemInfo?.c
    }

    /// Network usage in MB/s — supports both legacy ns/nr fields and newer bandwidth bytes array
    private var netMBps: Double {
        if let b = stats.bandwidth, b.count >= 2 {
            let bytesPerSec = b[0] + b[1]
            return bytesPerSec / 1_048_576.0
        }
        return (stats.networkSent ?? 0) + (stats.networkReceived ?? 0)
    }
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: MonitoringSpacing.standard) {
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Text(systemName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .accessibilityAddTraits(.isHeader)

                        statusView
                            .fixedSize(horizontal: true, vertical: false)

                        Spacer(minLength: 0)
                        PinButtonView(isPinned: isPinned, action: onPinToggle)
                    }

                    HStack(spacing: 8) {
                        if let model = cpuModel {
                            Text(model)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                }
                
                Divider()
                
                VStack(spacing: MonitoringSpacing.standard) {
                    MonitoringMetricRow(
                        label: "chart.cpuUsage",
                        fraction: stats.cpu / 100,
                        displayValue: MetricFormatter.percent(stats.cpu)
                    )
                    MonitoringMetricRow(
                        label: "chart.memoryUsage",
                        fraction: stats.memoryPercent / 100,
                        displayValue: MetricFormatter.percent(stats.memoryPercent)
                    )
                    MonitoringMetricRow(
                        label: "chart.diskUsage",
                        fraction: stats.diskPercent / 100,
                        displayValue: MetricFormatter.percent(stats.diskPercent)
                    )
                    
                    let netUsageMB = netMBps

                    if let load = stats.load, let oneMinLoad = load.first {
                        HStack(spacing: 8) {
                            Text("chart.loadAverage")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Image(systemName: loadIcon(oneMinLoad))
                                .font(.caption)
                                .foregroundStyle(colorForLoad(oneMinLoad))
                                .accessibilityHidden(true)
                            Text(load.map { String(format: "%.2f", $0) }.joined(separator: " "))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                            Spacer()

                            HStack(spacing: 8) {
                                Text("metric.network")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(MetricFormatter.throughput(bytesPerSecond: netUsageMB * 1_048_576))
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("accessibility.loadIndicator")
                        .accessibilityValue("\(load.map { String(format: "%.2f", $0) }.joined(separator: " ")), \(loadStatusDescription(oneMinLoad))")
                    } else if netUsageMB > 0 {
                        HStack(spacing: 8) {
                            Text("metric.network")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(MetricFormatter.throughput(bytesPerSecond: netUsageMB * 1_048_576))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        if status != nil {
            let semanticStatus = MonitoringStatus(status)
            let uptime = semanticStatus == .operational ? systemInfo?.u.map(formatUptime) : nil
            MonitoringStatusBadge(status: semanticStatus, detail: uptime)
        }
    }
    
    private func formatUptime(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(seconds)) ?? ""
    }
    private func colorForLoad(_ val: Double) -> Color {
        guard let cores = cpuCores, cores > 0 else { return .primary }

        let limit = Double(cores)

        if val >= limit * 1.5 {
            return .red
        } else if val >= limit {
            return .orange
        } else {
            return .green
        }
    }

    private func loadIcon(_ value: Double) -> String {
        guard let cores = cpuCores, cores > 0 else { return "questionmark.circle.fill" }
        let limit = Double(cores)
        if value >= limit * 1.5 { return "exclamationmark.triangle.fill" }
        if value >= limit { return "exclamationmark.circle.fill" }
        return "checkmark.circle.fill"
    }

    private func loadStatusDescription(_ val: Double) -> String {
        guard let cores = cpuCores, cores > 0 else {
            return String(localized: "accessibility.loadStatus.unknown")
        }
        let limit = Double(cores)
        if val >= limit * 1.5 {
            return String(localized: "accessibility.loadStatus.critical")
        } else if val >= limit {
            return String(localized: "accessibility.loadStatus.high")
        } else {
            return String(localized: "accessibility.loadStatus.normal")
        }
    }
}
