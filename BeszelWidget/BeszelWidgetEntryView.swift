import SwiftUI
import WidgetKit

struct BeszelWidgetEntryView : View {
    private let languageManager = LanguageManager()
    @Environment(\.widgetFamily) private var widgetFamily
    var entry: SimpleEntry
    
    var body: some View {
        VStack(alignment: .leading) {
            if let errorMessage = entry.errorMessage {
                ErrorView(message: errorMessage)
            }
            else if widgetFamily.isLockScreen {
                LockScreenSystemInfoView(
                    systemName: entry.systemName,
                    status: entry.status,
                    stats: entry.latestStats,
                    metric: entry.lockScreenMetric
                )
            }
            else {
                contentView
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .environment(\.locale, Locale(identifier: languageManager.currentLanguageCode))
        .overlay(alignment: .topTrailing) {
            if entry.isFromCache && (entry.chartType == .systemInfo || widgetFamily.isLockScreen) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("widget.cached")
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch entry.chartType {
        case .systemInfo:
            if let stats = entry.latestStats {
                WidgetSystemSummaryView(
                    systemInfo: entry.systemInfo,
                    systemDetails: entry.systemDetails,
                    stats: stats,
                    systemName: entry.systemName,
                    status: entry.status
                )
            } else {
                NoDataPlaceholderView(metricName: "widget.systemInfo")
            }
        default:
            WidgetMetricChartView(entry: entry)
        }
    }
}

struct ErrorView: View {
    let message: LocalizedStringKey
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            Spacer()
        }
    }
}

struct NoDataPlaceholderView: View {
    var metricName: LocalizedStringResource? = nil
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    if let metricName = metricName {
                        Text("chart.noDataForMetric \(Text(metricName))")
                    } else {
                        Text("widget.noData")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                Spacer()
            }
            Spacer()
        }
    }
}
