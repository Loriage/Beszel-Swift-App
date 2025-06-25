import Foundation
import WidgetKit
import os

struct WidgetService {
    private let logger = Logger(subsystem: "com.nohitdev.Beszel.BeszelWidget", category: "TimelineGeneration")
    
    func generateTimeline(for configuration: SelectChartIntent) async -> Timeline<SimpleEntry> {
        logger.info("--- Starting timeline generation ---")
        let credentialsManager = CredentialsManager.shared
        let settingsManager = SettingsManager()
        let selectedTimeRange = settingsManager.selectedTimeRange

        let creds = credentialsManager.loadCredentials()
        guard let url = creds.url, let email = creds.email, let password = creds.password else {
            let entry = SimpleEntry(date: .now, chartType: configuration.chart, dataPoints: [], timeRange: settingsManager.selectedTimeRange, errorMessage: "widget.notConnected")
            return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600)))
        }
        
        let apiService = BeszelAPIService(url: url, email: email, password: password)
        do {
            let filter = settingsManager.apiFilterString
            let records = try await apiService.fetchSystemStats(filter: filter)
            let dataPoints = DataProcessor.transformSystem(records: records)
            
            logger.log("Successfully fetched \(dataPoints.count) data points.")
            
            return createSuccessTimeline(
                for: configuration.chart,
                with: dataPoints,
                timeRange: selectedTimeRange
            )
        } catch {
            logger.error("Failed to generate timeline: \(error.localizedDescription)")
            
            let entry = SimpleEntry(date: .now, chartType: configuration.chart, dataPoints: [], timeRange: selectedTimeRange, errorMessage: "widget.loadingError")
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
        
        logger.log("Creating a single-entry timeline. Next refresh scheduled for \(nextUpdateDate.formatted(date: .omitted, time: .standard))")
        
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
