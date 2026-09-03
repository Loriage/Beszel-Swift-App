import WidgetKit
import AppIntents
import SwiftUI

public struct SelectInstanceAndChartIntent: WidgetConfigurationIntent {
    public static let title: LocalizedStringResource = "widget.configuration.title"
    public static let description: IntentDescription = "widget.configuration.description"

    @Parameter(title: "chart.configuration.instance.title")
    public var instance: InstanceEntity?

    @Parameter(title: "chart.configuration.system.title")
    public var system: SystemEntity?

    @Parameter(title: "widget.configuration.category.title")
    public var category: WidgetChartCategory?

    @Parameter(title: "chart.configuration.chartType.title")
    public var chart: ChartTypeEntity?

    public static var parameterSummary: some ParameterSummary {
        Summary {
            \.$instance
            \.$system
            \.$category
            \.$chart
        }
    }

    public init() {}

    public init(instance: InstanceEntity?, system: SystemEntity?, chart: ChartTypeEntity?) {
        self.instance = instance
        self.system = system
        self.chart = chart
    }

    func snapshotChartType(isPreview: Bool, family: WidgetFamily) -> WidgetChartType {
        // Showcase a chart in the large gallery card without changing saved selections.
        if isPreview && family == .systemLarge {
            return .systemCPU
        }
        return WidgetChartType(rawValue: chart?.id ?? "") ?? .systemInfo
    }
}

// This file also belongs to the MainActor-default app target. Keep App Intents
// metadata nonisolated explicitly, including with the Xcode 26 compiler.
nonisolated extension WidgetChartCategory: AppEnum {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "widget.configuration.category.title"
    public static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .overview: "widget.category.overview",
        .processor: "widget.category.processor",
        .memory: "widget.category.memory",
        .disk: "widget.category.disk",
        .additionalDisks: "widget.category.additionalDisks",
        .network: "widget.category.network",
        .sensors: "widget.category.sensors"
    ]
}

nonisolated extension DockerWidgetMetric: AppEnum {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "widget.configuration.metric.title"
    public static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .cpu: "CPU", .memory: "Memory", .network: "widget.docker.network"
    ]
}

public struct SelectDockerContainerIntent: WidgetConfigurationIntent {
    public static let title: LocalizedStringResource = "widget.docker.displayName"
    public static let description: IntentDescription = "widget.docker.description"

    @Parameter(title: "chart.configuration.instance.title")
    public var instance: InstanceEntity?

    @Parameter(title: "chart.configuration.system.title")
    public var system: SystemEntity?

    @Parameter(title: "widget.configuration.container.title")
    public var container: DockerContainerEntity?

    @Parameter(title: "widget.configuration.metric.title", default: .cpu)
    public var metric: DockerWidgetMetric

    public static var parameterSummary: some ParameterSummary {
        Summary {
            \.$instance
            \.$system
            \.$container
            \.$metric
        }
    }

    public init() {}
}

public struct SelectInstanceAndMetricIntent: WidgetConfigurationIntent {
    public static let title: LocalizedStringResource = "widget.configuration.title"
    public static let description: IntentDescription = "widget.configuration.description"

    @Parameter(title: "chart.configuration.instance.title")
    public var instance: InstanceEntity?

    @Parameter(title: "chart.configuration.system.title")
    public var system: SystemEntity?

    @Parameter(title: "widget.configuration.metric.title")
    public var metric: MetricEntity?

    public init() {}

    public init(instance: InstanceEntity?, system: SystemEntity?, metric: MetricEntity?) {
        self.instance = instance
        self.system = system
        self.metric = metric
    }
}

public struct SelectInstanceIntent: WidgetConfigurationIntent {
    public static let title: LocalizedStringResource = "widget.configuration.title"
    public static let description: IntentDescription = "widget.configuration.description"

    @Parameter(title: "chart.configuration.instance.title")
    public var instance: InstanceEntity?

    @Parameter(title: "chart.configuration.system.title")
    public var system: SystemEntity?

    public init() {}

    public init(instance: InstanceEntity?, system: SystemEntity?) {
        self.instance = instance
        self.system = system
    }
}

public struct InstanceEntity: AppEntity {
    public let id: String
    public let name: String
    
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
    
    public var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Instance"
    public static let defaultQuery = InstanceQuery()
}

public struct InstanceQuery: EntityQuery {
    public init() {}
    
    public func entities(for identifiers: [String]) async throws -> [InstanceEntity] {
        let all = try await suggestedEntities()
        return all.filter { identifiers.contains($0.id) }
    }
    
    public func suggestedEntities() async throws -> [InstanceEntity] {
        let instances = await MainActor.run {
            return InstanceManager.shared.instances
        }
        return instances.map { InstanceEntity(id: $0.id.uuidString, name: $0.name) }
    }
}

public struct SystemEntity: AppEntity {
    public let id: String
    public let name: String
    
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
    
    public var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Système"
    public static let defaultQuery = SystemQuery()
}

public struct SystemQuery: EntityQuery {
    @IntentParameterDependency<SelectInstanceAndChartIntent>(\.$instance)
    private var chartIntent
    @IntentParameterDependency<SelectInstanceAndMetricIntent>(\.$instance)
    private var metricIntent
    @IntentParameterDependency<SelectInstanceIntent>(\.$instance)
    private var instanceIntent
    @IntentParameterDependency<SelectDockerContainerIntent>(\.$instance)
    private var dockerIntent

    public init() {}

    public func entities(for identifiers: [String]) async throws -> [SystemEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }

    public func suggestedEntities() async throws -> [SystemEntity] {
        let instanceID = chartIntent?.instance.id ?? metricIntent?.instance.id
            ?? instanceIntent?.instance.id ?? dockerIntent?.instance.id
        return try await WidgetConfigurationData.systems(instanceID: instanceID)
    }
}

public struct ChartTypeEntity: AppEntity {
    public let id: String
    public let title: LocalizedStringResource
    
    public init(id: String, title: LocalizedStringResource) {
        self.id = id
        self.title = title
    }
    
    public var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: title) }
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "widget.configuration.title"
    public static let defaultQuery = ChartTypeQuery()
}

public struct ChartTypeQuery: EntityStringQuery {
    @IntentParameterDependency<SelectInstanceAndChartIntent>(\.$category)
    private var intent

    public init() {}
    public func entities(for identifiers: [String]) async throws -> [ChartTypeEntity] {
        // Retired choices still resolve so existing widgets can ask the user
        // to reconfigure instead of silently switching to a different metric.
        identifiers.compactMap { identifier in
            guard let chartType = WidgetChartType(rawValue: identifier) else { return nil }
            return ChartTypeEntity(id: chartType.id, title: chartType.localizedTitle)
        }
    }

    public func suggestedEntities() async throws -> IntentItemCollection<ChartTypeEntity> {
        Self.choices(category: intent?.category)
    }

    public func entities(matching string: String) async throws -> IntentItemCollection<ChartTypeEntity> {
        Self.choices(category: intent?.category, search: string)
    }

    public static func choices(
        category: WidgetChartCategory?, search: String = ""
    ) -> IntentItemCollection<ChartTypeEntity> {
        let search = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let categories = category.map { [$0] } ?? WidgetChartCategory.allCases
        let sections = categories.compactMap { category -> IntentItemSection<ChartTypeEntity>? in
            let charts = category.chartTypes.filter { chart in
                search.isEmpty || String(localized: chart.localizedTitle).localizedStandardContains(search)
            }.map { ChartTypeEntity(id: $0.id, title: $0.localizedTitle) }
            guard !charts.isEmpty else { return nil }
            return IntentItemSection(category.title, items: charts)
        }
        return IntentItemCollection(sections: sections)
    }
}

public struct DockerContainerEntity: AppEntity {
    public let id: String
    public let name: String

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "widget.configuration.container.title"
    public static let defaultQuery = DockerContainerQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: "shippingbox"))
    }

    init(selection: WidgetContainerSelection) {
        id = selection.id
        name = selection.name
    }
}

public struct DockerContainerQuery: EntityStringQuery {
    @IntentParameterDependency<SelectDockerContainerIntent>(\.$instance, \.$system)
    private var intent

    private let catalog = WidgetContainerCatalog()

    public init() {}

    public func entities(for identifiers: [String]) async throws -> [DockerContainerEntity] {
        // Resolving an existing selection must not depend on the hub being online
        // or the container still running. Its scope is checked by the timeline.
        identifiers.compactMap { WidgetContainerSelection(id: $0) }.map(DockerContainerEntity.init)
    }

    public func suggestedEntities() async throws -> [DockerContainerEntity] {
        try await containers(matching: "")
    }

    public func entities(matching string: String) async throws -> [DockerContainerEntity] {
        try await containers(matching: string)
    }

    private func containers(matching search: String) async throws -> [DockerContainerEntity] {
        guard let systemID = intent?.system.id else { return [] }
        let connection = try await WidgetConfigurationData.connection(instanceID: intent?.instance.id)
        let records = try await catalog.records(connection: connection, systemID: systemID)
        return WidgetContainerSelection.runningSelections(
            in: records, instanceID: connection.instanceID, systemID: systemID, search: search
        ).map(DockerContainerEntity.init)
    }
}

public struct MetricEntity: AppEntity {
    public let id: String
    public let title: LocalizedStringResource

    public init(id: String, title: LocalizedStringResource) {
        self.id = id
        self.title = title
    }

    public var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: title) }
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "widget.configuration.metric.title"
    public static let defaultQuery = MetricQuery()
}

public struct MetricQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [MetricEntity] {
        let all = try await suggestedEntities()
        return all.filter { identifiers.contains($0.id) }
    }

    public func suggestedEntities() async throws -> [MetricEntity] {
        [
            MetricEntity(id: "cpu", title: "CPU"),
            MetricEntity(id: "memory", title: "Memory"),
            MetricEntity(id: "disk", title: "Disk")
        ]
    }
}
