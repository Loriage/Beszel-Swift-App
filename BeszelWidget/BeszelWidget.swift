import WidgetKit
import SwiftUI
import Charts

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), chartType: .systemCPU, dataPoints: [], timeRange: .last24Hours)
    }

    func snapshot(for configuration: SelectChartIntent, in context: Context) async -> SimpleEntry {
        let entry = SimpleEntry(date: Date(), chartType: configuration.chart, dataPoints: sampleDataPoints(), timeRange: .last24Hours)
        return entry
    }

    func timeline(for configuration: SelectChartIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let credentialsManager = CredentialsManager.shared
        let settingsManager = SettingsManager()
        let selectedTimeRange = settingsManager.selectedTimeRange
        
        let refreshInterval: TimeInterval
        switch selectedTimeRange {
        case .lastHour:
            refreshInterval = 5 * 60
        case .last12Hours:
            refreshInterval = 15 * 60
        case .last24Hours, .last7Days, .last30Days:
            refreshInterval = 30 * 60
        }
        
        let currentDate = Date()
        let endDate = currentDate.addingTimeInterval(4 * 3600)
        
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
            
            var entries: [SimpleEntry] = []
            
            var entryDate = currentDate
            while entryDate < endDate {
                let entry = SimpleEntry(
                    date: entryDate,
                    chartType: configuration.chart,
                    dataPoints: dataPoints,
                    timeRange: selectedTimeRange
                )
                entries.append(entry)
                entryDate = entryDate.addingTimeInterval(refreshInterval)
            }
            
            if entries.isEmpty {
                let entry = SimpleEntry(date: currentDate, chartType: configuration.chart, dataPoints: dataPoints, timeRange: selectedTimeRange)
                entries.append(entry)
            }
            return Timeline(entries: entries, policy: .atEnd)
        } catch {
            let entry = SimpleEntry(date: .now, chartType: configuration.chart, dataPoints: [], timeRange: selectedTimeRange, errorMessage: "widget.loadingError")
            let nextUpdate = Date().addingTimeInterval(15 * 60)
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        }
    }
    
    private func sampleDataPoints() -> [SystemDataPoint] {
        var points: [SystemDataPoint] = []
        for i in 0..<10 {
            let date = Date().addingTimeInterval(TimeInterval(i * 3600))
            points.append(SystemDataPoint(date: date, cpu: Double.random(in: 20...80), memoryPercent: Double.random(in: 30...60), temperatures: []))
        }
        return points
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
