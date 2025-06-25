import WidgetKit
import SwiftUI
import AppIntents
import Foundation

struct Provider: AppIntentTimelineProvider {
    typealias Entry = SimpleEntry
    typealias Intent = SelectChartIntent

    private let service = WidgetService()

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            chartType: .systemCPU,
            dataPoints: [],
            timeRange: .last24Hours
        )
    }

    func snapshot(
        for configuration: SelectChartIntent,
        in context: Context
    ) async -> SimpleEntry {
        return service.getSnapshotEntry(for: configuration)
    }

    func timeline(
        for configuration: SelectChartIntent,
        in context: Context
    ) async -> Timeline<SimpleEntry> {
        return await service.generateTimeline(for: configuration)
    }
}
