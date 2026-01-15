import WidgetKit
import AppIntents
import SwiftUI
import os

public struct SelectInstanceAndChartIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "widget.configuration.title"
    public static var description: IntentDescription = "widget.configuration.description"

    public static var openAppWhenRun: Bool = true

    @Parameter(title: "chart.configuration.instance.title")
    public var instance: InstanceEntity?

    @Parameter(title: "chart.configuration.system.title")
    public var system: SystemEntity?

    @Parameter(title: "chart.configuration.chartType.title")
    public var chart: ChartTypeEntity?

    @Parameter(title: "widget.configuration.metric.title")
    public var metric: MetricEntity?

    public init() {}

    public init(instance: InstanceEntity?, system: SystemEntity?, chart: ChartTypeEntity?, metric: MetricEntity?) {
        self.instance = instance
        self.system = system
        self.chart = chart
        self.metric = metric
    }
}

public struct SelectInstanceAndMetricIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "widget.configuration.title"
    public static var description: IntentDescription = "widget.configuration.description"

    public static var openAppWhenRun: Bool = true

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

public struct InstanceEntity: AppEntity {
    public let id: String
    public let name: String
    
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
    
    public var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Instance"
    public static var defaultQuery = InstanceQuery()
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
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Système"
    public static var defaultQuery = SystemQuery()
}

public struct SystemQuery: EntityQuery {
    private static let logger = Logger(subsystem: "com.nohitdev.Beszel.widget", category: "SystemQuery")

    public init() {}
    
    public func entities(for identifiers: [String]) async throws -> [SystemEntity] {
        let allSystems = await allSystemsForSelectedInstance()
        return allSystems.filter { identifiers.contains($0.id) }
    }
    
    public func suggestedEntities() async throws -> [SystemEntity] {
        return await allSystemsForSelectedInstance()
    }
    
    private func allSystemsForSelectedInstance() async -> [SystemEntity] {
        let apiService = await MainActor.run { () -> BeszelAPIService? in
            let manager = InstanceManager.shared
            let idString = UserDefaults(suiteName: "group.com.nohitdev.Beszel")?.string(forKey: "activeInstanceID")

            guard let activeIDString = idString,
                  let _ = UUID(uuidString: activeIDString),
                  let foundInstance = manager.instances.first(where: { $0.id.uuidString == idString }) else {
                return nil
            }

            return BeszelAPIService(instance: foundInstance, instanceManager: manager)
        }

        guard let apiService = apiService else {
            return []
        }

        do {
            let systems = try await apiService.fetchSystems()
            return systems.map { SystemEntity(id: $0.id, name: $0.name) }
        } catch {
            Self.logger.error("Failed to fetch systems for widget: \(error.localizedDescription)")
            return []
        }
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
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.configuration.title"
    public static var defaultQuery = ChartTypeQuery()
}

public struct ChartTypeQuery: EntityQuery {
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [ChartTypeEntity] {
        let all = try await suggestedEntities()
        return all.filter { identifiers.contains($0.id) }
    }
    public func suggestedEntities() async throws -> [ChartTypeEntity] {
        return [
            ChartTypeEntity(id: "systemInfo", title: "System Info"),
            ChartTypeEntity(id: "systemCPU", title: "widget.chart.systemCPU.title"),
            ChartTypeEntity(id: "systemMemory", title: "widget.chart.systemMemory.title"),
            ChartTypeEntity(id: "systemTemperature", title: "widget.chart.systemTemperature.title")
        ]
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
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.configuration.metric.title"
    public static var defaultQuery = MetricQuery()
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
