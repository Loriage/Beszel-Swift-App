import SwiftUI
import WidgetKit

struct DockerWidgetEntry: TimelineEntry {
    let date: Date
    let containerName: String
    let systemName: String
    let metric: DockerWidgetMetric
    let timeRange: TimeRangeOption
    var availability: WidgetContainerAvailability = .running
    var points: [StatPoint] = []

    var chartEntry: SimpleEntry {
        SimpleEntry(
            date: date, chartType: metric.chartType, dataPoints: [],
            containerData: [ProcessedContainerData(id: containerName, statPoints: points)],
            systemInfo: nil, systemDetails: nil, latestStats: nil,
            systemName: systemName, status: nil, timeRange: timeRange, lockScreenMetric: .cpu
        )
    }
}

struct DockerWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DockerWidgetEntry {
        .sample()
    }

    func snapshot(for configuration: SelectDockerContainerIntent, in context: Context) async -> DockerWidgetEntry {
        if context.isPreview { return .sample(metric: configuration.metric) }
        return await entry(for: configuration)
    }

    func timeline(for configuration: SelectDockerContainerIntent, in context: Context) async -> Timeline<DockerWidgetEntry> {
        let entry = await entry(for: configuration)
        let needsConfiguration = entry.availability == .notConfigured || entry.availability == .selectionChanged
        return Timeline(
            entries: [entry],
            policy: needsConfiguration ? .never : .after(.now.addingTimeInterval(15 * 60))
        )
    }

    private func entry(for configuration: SelectDockerContainerIntent) async -> DockerWidgetEntry {
        let selection = configuration.container.flatMap { WidgetContainerSelection(id: $0.id) }
        let timeRange = await MainActor.run { SettingsManager().selectedTimeRange }
        var entry = DockerWidgetEntry(
            date: .now,
            containerName: selection?.name ?? String(localized: "widget.docker.displayName"),
            systemName: configuration.system?.name ?? String(localized: "System"),
            metric: configuration.metric, timeRange: timeRange
        )

        guard let selection else {
            entry.availability = .notConfigured
            return entry
        }
        guard selection.matches(instanceID: configuration.instance?.id, systemID: configuration.system?.id) else {
            entry.availability = .selectionChanged
            return entry
        }

        do {
            try Task.checkCancellation()
            // Never fall back to the app's currently active hub or another container.
            let connection = try await WidgetConfigurationData.connection(instanceID: selection.instanceID.uuidString)
            let systemFilter = try WidgetConfigurationData.systemFilter(selection.systemID)
            async let systems = connection.apiService.fetchSystems()
            async let containers = connection.apiService.fetchContainers(filter: systemFilter)
            let (systemRecords, containerRecords) = try await (systems, containers)
            try Task.checkCancellation()

            guard let system = systemRecords.first(where: { $0.id == selection.systemID }),
                  system.status?.lowercased() == "up" else {
                entry.availability = .unavailable
                return entry
            }
            entry.availability = selection.availability(in: containerRecords)
            guard entry.availability == .running else { return entry }

            let records = try await connection.apiService.fetchMonitors(
                filter: "(\(timeRange.apiFilterString) && \(systemFilter))"
            )
            try Task.checkCancellation()
            entry.points = selection.history(in: records)
        } catch {
            // Avoid logging transport errors: they can contain private hub URLs.
            entry.availability = .unavailable
        }
        return entry
    }
}

struct DockerWidgetEntryView: View {
    private let languageManager = LanguageManager()
    let entry: DockerWidgetEntry

    var body: some View {
        Group {
            if entry.availability == .running {
                WidgetMetricChartView(
                    entry: entry.chartEntry, containerMetric: entry.metric, containerName: entry.containerName
                )
            } else {
                DockerWidgetStatusView(
                    containerName: entry.containerName, systemName: entry.systemName,
                    availability: entry.availability
                )
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .environment(\.locale, Locale(identifier: languageManager.currentLanguageCode))
    }
}

private struct DockerWidgetStatusView: View {
    let containerName: String
    let systemName: String
    let availability: WidgetContainerAvailability

    private var message: LocalizedStringResource {
        switch availability {
        case .notConfigured: "widget.docker.chooseContainer"
        case .selectionChanged: "widget.docker.selectionChanged"
        case .stopped: "widget.docker.stopped"
        case .missing: "widget.docker.missing"
        case .unavailable, .running: "widget.docker.unavailable"
        }
    }

    private var symbol: String {
        switch availability {
        case .notConfigured, .selectionChanged: "slider.horizontal.3"
        case .stopped: "stop.circle"
        case .missing: "shippingbox"
        case .unavailable, .running: "wifi.exclamationmark"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: containerName)
                .font(.headline)
                .lineLimit(2)
            Text(verbatim: systemName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)
            Label {
                Text(message)
            } icon: {
                Image(systemName: symbol)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct BeszelDockerWidget: Widget {
    let kind = "BeszelDockerWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind, intent: SelectDockerContainerIntent.self, provider: DockerWidgetProvider()
        ) { entry in
            DockerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("widget.docker.displayName")
        .description("widget.docker.description")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

extension DockerWidgetEntry {
    static func sample(metric: DockerWidgetMetric = .cpu) -> Self {
        let date = Date.now
        let points = (0..<30).map { index in
            let wave = (sin(Double(index) * 0.55) + 1) / 2
            return StatPoint(
                date: date.addingTimeInterval(Double(index - 29) * 120),
                cpu: 8 + wave * 14 + (index == 20 ? 25 : 0),
                memory: 380 + wave * 35,
                netSent: 80_000 + wave * 140_000,
                netReceived: 250_000 + wave * 850_000
            )
        }
        return Self(
            date: date, containerName: "web-server",
            systemName: String(localized: "widget.sample.system"),
            metric: metric, timeRange: .lastHour, points: points
        )
    }
}

#Preview("Docker CPU", as: .systemMedium) {
    BeszelDockerWidget()
} timeline: {
    DockerWidgetEntry.sample()
}

#Preview("Docker network", as: .systemLarge) {
    BeszelDockerWidget()
} timeline: {
    DockerWidgetEntry.sample(metric: .network)
}

#Preview("Stopped container", as: .systemMedium) {
    BeszelDockerWidget()
} timeline: {
    DockerWidgetEntry(
        date: .now, containerName: "web-server", systemName: "Server", metric: .cpu,
        timeRange: .lastHour, availability: .stopped
    )
}
