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
                WidgetMetricRow(label: "CPU", value: stats.cpu / 100, displayValue: String(format: "%.1f%%", stats.cpu))
                WidgetMetricRow(label: "MEM", value: stats.memoryPercent / 100, displayValue: String(format: "%.1f%%", stats.memoryPercent))
                WidgetMetricRow(label: "DSK", value: stats.diskPercent / 100, displayValue: String(format: "%.1f%%", stats.diskPercent))
                
                HStack {
                    if let load = stats.load, let oneMin = load.first {
                         HStack(spacing: 8) {
                            Text("SYS")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            Circle()
                                .fill(colorForLoad(oneMin))
                                .frame(width: 6, height: 6)
                             Text(load.map { String(format: "%.2f", $0) }.joined(separator: " "))
                                .font(.caption2)
                                .monospacedDigit()
                        }
                    }
                    
                    Spacer()

                    let netUsageMB = (stats.networkReceived + stats.networkSent)
                    HStack(spacing: 6) {
                        Text("NET")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.2f", netUsageMB)) MB/s")
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
}

struct StatusBadge: View {
    let status: String?
    let uptime: Double?
    
    var body: some View {
        if let currentStatus = status {
            switch currentStatus {
            case "up":
                if let u = uptime {
                    Text(formatUptime(u))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.green)
                        .font(.caption2)
                }
            case "down":
                Text("DOWN")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            default:
                Image(systemName: "circle.fill")
                    .foregroundColor(.gray)
                    .font(.caption2)
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

struct WidgetMetricRow: View {
    let label: String
    let value: Double
    let displayValue: String
    
    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .monospaced()
                .foregroundColor(.secondary)
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
                .foregroundColor(.primary)
                .frame(width: 40, alignment: .trailing)
        }
        .frame(height: 12)
    }
    
    private func colorForValue(_ val: Double) -> Color {
        if val < 0.6 { return .green }
        if val < 0.8 { return .orange }
        return .red
    }
}
