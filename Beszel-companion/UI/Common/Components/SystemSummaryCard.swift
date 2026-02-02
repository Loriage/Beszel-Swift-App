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
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        Text(systemName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        PinButtonView(isPinned: isPinned, action: onPinToggle)
                    }

                    HStack(spacing: 8) {
                        if let model = cpuModel {
                            Text(model)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Spacer()
                        }

                        statusView
                    }
                }
                
                Divider()
                
                VStack(spacing: 8) {
                    MetricRow(label: "CPU:", value: stats.cpu / 100, displayValue: String(format: "%.1f%%", stats.cpu))
                    MetricRow(label: "MEM:", value: stats.memoryPercent / 100, displayValue: String(format: "%.1f%%", stats.memoryPercent))
                    MetricRow(label: "DSK:", value: stats.diskPercent / 100, displayValue: String(format: "%.1f%%", stats.diskPercent))
                    
                    if let load = stats.load, let oneMinLoad = load.first {
                        HStack(spacing: 8) {
                            Text("SYS:")
                                .font(.caption)
                                .fontWeight(.bold)
                                .monospaced()
                                .foregroundColor(.secondary)
                                .frame(width: 35, alignment: .leading)
                            Circle()
                                .fill(colorForLoad(oneMinLoad))
                                .frame(width: 8, height: 8)
                                .accessibilityLabel(Text("accessibility.loadIndicator"))
                                .accessibilityValue(Text(loadStatusDescription(oneMinLoad)))
                            Text(load.map { String(format: "%.2f", $0) }.joined(separator: " "))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.primary)
                            Spacer()

                            let netUsageMB = (stats.networkReceived ?? 0) + (stats.networkSent ?? 0)

                            HStack(spacing: 8) {
                                Text("NET:")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .monospaced()
                                    .foregroundColor(.secondary)
                                    .frame(width: 35, alignment: .leading)

                                Text("\(String(format: "%.2f", netUsageMB)) MB/s")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        if let currentStatus = status {
            switch currentStatus {
            case "up":
                if let uptime = systemInfo?.u {
                    Label("UP: \(formatUptime(uptime))", systemImage: "clock")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                } else {
                    Text("UP")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            case "down":
                Label("DOWN", systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            case "paused":
                Label("PAUSED", systemImage: "pause.circle.fill")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            case "pending":
                Label("PENDING", systemImage: "hourglass")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            default:
                EmptyView()
            }
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

struct MetricRow: View {
    let label: String
    let value: Double
    let displayValue: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .monospaced()
                .foregroundColor(.secondary)
                .frame(width: 35, alignment: .leading)
            
            Text(displayValue)
                .font(.caption)
                .monospacedDigit()
                .foregroundColor(.primary)
                .frame(width: 45, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(colorForValue(value))
                        .frame(width: max(0, min(geometry.size.width * CGFloat(value), geometry.size.width)), height: 6)
                }
                .frame(height: 6)
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }
    
    private func colorForValue(_ val: Double) -> Color {
        if val < 0.65 { return .green }
        if val < 0.90 { return .orange }
        return .red
    }
}
