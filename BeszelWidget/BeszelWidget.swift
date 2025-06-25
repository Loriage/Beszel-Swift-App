import WidgetKit
import SwiftUI

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
