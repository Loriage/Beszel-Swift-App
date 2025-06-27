import WidgetKit
import SwiftUI
import Charts

struct Provider: AppIntentTimelineProvider {
    private let service = WidgetService()

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), chartType: .systemCPU, dataPoints: [], timeRange: .last24Hours)
    }

    func snapshot(for configuration: SelectChartIntent, in context: Context) async -> SimpleEntry {
        return service.getSnapshotEntry(for: configuration)
    }

    func timeline(for configuration: SelectChartIntent, in context: Context) async -> Timeline<SimpleEntry> {
        return await service.generateTimeline(for: configuration)
    }
}

struct BeszelWidget: Widget {
    let kind: String = "BeszelWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectChartIntent.self, provider: Provider()) { entry in
            BeszelWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("widget.displayName")
        .description("widget.description")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
