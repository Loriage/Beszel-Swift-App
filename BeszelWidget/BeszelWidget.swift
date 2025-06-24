import WidgetKit
import SwiftUI
import Charts

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), chartType: .systemCPU, dataPoints: [])
    }

    func snapshot(for configuration: SelectChartIntent, in context: Context) async -> SimpleEntry {
        let entry = SimpleEntry(date: Date(), chartType: configuration.chart, dataPoints: sampleDataPoints())
        return entry
    }

    func timeline(for configuration: SelectChartIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let credentialsManager = CredentialsManager.shared
        let settingsManager = SettingsManager()
        
        let creds = credentialsManager.loadCredentials()
        guard let url = creds.url, let email = creds.email, let password = creds.password else {
            let entry = SimpleEntry(date: .now, chartType: configuration.chart, dataPoints: [], errorMessage: "Non connecté")
            return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600)))
        }
        
        let apiService = BeszelAPIService(url: url, email: email, password: password)
        
        do {
            let filter = settingsManager.apiFilterString
            let records = try await apiService.fetchSystemStats(filter: filter)
            let dataPoints = transformSystem(records: records)
            
            let entry = SimpleEntry(date: .now, chartType: configuration.chart, dataPoints: dataPoints)
            
            let nextUpdate = Date().addingTimeInterval(15 * 60)
            return Timeline(entries: [entry], policy: .after(nextUpdate))
            
        } catch {
            let entry = SimpleEntry(date: .now, chartType: configuration.chart, dataPoints: [], errorMessage: "Erreur de chargement")
            let nextUpdate = Date().addingTimeInterval(15 * 60)
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        }
    }

    private func transformSystem(records: [SystemStatsRecord]) -> [SystemDataPoint] {
        let dataPoints = records.compactMap { record -> SystemDataPoint? in
            guard let date = DateFormatter.pocketBase.date(from: record.created) else {
                return nil
            }

            let tempsArray = record.stats.temperatures.map { (name: $0.key, value: $0.value) }

            return SystemDataPoint(
                date: date,
                cpu: record.stats.cpu,
                memoryPercent: record.stats.memoryPercent,
                temperatures: tempsArray
            )
        }

        return dataPoints.sorted(by: { $0.date < $1.date })
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

struct SimpleEntry: TimelineEntry {
    let date: Date
    let chartType: WidgetChartType
    let dataPoints: [SystemDataPoint]
    var errorMessage: String? = nil
}

struct BeszelWidgetEntryView : View {
    var entry: Provider.Entry
    
    private var widgetXAxisFormat: Date.FormatStyle {
        return TimeRangeOption.last24Hours.xAxisFormat
    }

    var body: some View {
        VStack(alignment: .leading) {
            if let errorMessage = entry.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if entry.dataPoints.isEmpty {
                Text("Aucune donnée disponible pour la période sélectionnée.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                chartView
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private var chartView: some View {
        switch entry.chartType {
        case .systemCPU:
            SystemCpuChartView(xAxisFormat: widgetXAxisFormat, dataPoints: entry.dataPoints, isForWidget: true )
        case .systemMemory:
            SystemMemoryChartView(xAxisFormat: widgetXAxisFormat, dataPoints: entry.dataPoints, isForWidget: true)
        case .systemTemperature:
            SystemTemperatureChartView(xAxisFormat: widgetXAxisFormat, dataPoints: entry.dataPoints, isForWidget: true)
        }
    }
}

struct BeszelWidget: Widget {
    let kind: String = "BeszelWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectChartIntent.self, provider: Provider()) { entry in
            BeszelWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Graphique Beszel")
        .description("Affichez un graphique de monitoring de votre serveur.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
