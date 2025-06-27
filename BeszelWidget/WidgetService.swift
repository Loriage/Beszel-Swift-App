import Foundation
import WidgetKit

struct WidgetService {

    func generateTimeline(for configuration: SelectChartIntent) async -> Timeline<SimpleEntry> {
        let instanceManager = InstanceManager.shared
        let settingsManager = SettingsManager()

        guard let activeInstance = instanceManager.activeInstance else {
            let entry = SimpleEntry(date: .now, chartType: .systemCPU, dataPoints: [], timeRange: .last24Hours, errorMessage: "widget.notConnected")
            return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600)))
        }

        guard let password = instanceManager.loadPassword(for: activeInstance) else {
            let entry = SimpleEntry(date: .now, chartType: .systemCPU, dataPoints: [], timeRange: .last24Hours, errorMessage: "widget.loadingError")
            return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600)))
        }

        let apiService = BeszelAPIService(url: activeInstance.url, email: activeInstance.email, password: password)

        do {
            let filter = settingsManager.apiFilterString
            let records = try await apiService.fetchSystemStats(filter: filter)
            let dataPoints = DataProcessor.transformSystem(records: records)
            
            return createSuccessTimeline(
                for: configuration.chart,
                with: dataPoints,
                timeRange: settingsManager.selectedTimeRange
            )
        } catch {
            let entry = SimpleEntry(date: .now, chartType: configuration.chart, dataPoints: [], timeRange: settingsManager.selectedTimeRange, errorMessage: "widget.loadingError")
            let nextUpdate = Date().addingTimeInterval(15 * 60)
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        }
    }

    private func createSuccessTimeline(for chartType: WidgetChartType, with dataPoints: [SystemDataPoint], timeRange: TimeRangeOption) -> Timeline<SimpleEntry> {
        let currentDate = Date()

        let entry = SimpleEntry(
            date: currentDate,
            chartType: chartType,
            dataPoints: dataPoints,
            timeRange: timeRange
        )

        let refreshInterval = getRefreshInterval(for: timeRange)
        let nextUpdateDate = currentDate.addingTimeInterval(refreshInterval)

        return Timeline(entries: [entry], policy: .after(nextUpdateDate))
    }

    private func getRefreshInterval(for timeRange: TimeRangeOption) -> TimeInterval {
        switch timeRange {
        case .lastHour:
            return 5 * 60
        case .last12Hours:
            return 15 * 60
        case .last24Hours, .last7Days, .last30Days:
            return 30 * 60
        }
    }

    func getSnapshotEntry(for configuration: SelectChartIntent) -> SimpleEntry {
        var points: [SystemDataPoint] = []
        for i in 0..<10 {
            let date = Date().addingTimeInterval(TimeInterval(i * 3600))
            points.append(SystemDataPoint(date: date, cpu: Double.random(in: 20...80), memoryPercent: Double.random(in: 30...60), temperatures: []))
        }
        return SimpleEntry(date: Date(), chartType: configuration.chart, dataPoints: points, timeRange: .last24Hours)
    }
}
