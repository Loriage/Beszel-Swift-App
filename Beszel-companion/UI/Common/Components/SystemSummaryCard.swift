import SwiftUI

struct SystemSummaryCard: View {
    let systemInfo: SystemInfo?
    let stats: SystemStatsDetail
    let systemName: String
    let status: String?

    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}
    
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
                        if let model = systemInfo?.m {
                            Text(model)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()
                        
                        statusView
                    }
                }
                
                Divider()
                
                VStack(spacing: 8) {
                    MetricRow(label: "CPU:", value: stats.cpu / 100, displayValue: String(format: "%.1f%%", stats.cpu))
                    MetricRow(label: "MEM:", value: stats.memoryPercent / 100, displayValue: String(format: "%.1f%%", stats.memoryPercent))
                    
                    if let load = stats.load {
                        HStack(spacing: 8) {
                            Text("SYS:")
                                .font(.caption)
                                .fontWeight(.bold)
                                .monospaced()
                                .foregroundColor(.secondary)
                                .frame(width: 35, alignment: .leading)
                            Text(load.map { String(format: "%.2f", $0) }.joined(separator: "  "))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.primary)
                            Spacer()
                            Text("1/5/15")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                    }

                    if let bandwidth = systemInfo?.b {
                        HStack(spacing: 8) {
                            Text("NET:")
                                .font(.caption)
                                .fontWeight(.bold)
                                .monospaced()
                                .foregroundColor(.secondary)
                                .frame(width: 35, alignment: .leading)
                            Text("\(String(format: "%.2f", bandwidth)) MB/s")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.primary)
                            Spacer()
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
        if val < 0.6 { return .green }
        if val < 0.8 { return .orange }
        return .red
    }
}
