import WidgetKit
import AppIntents
import SwiftUI
import os

public struct SelectInstanceAndChartIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "widget.configuration.title"
    public static var description: IntentDescription = "widget.configuration.description"

    @Parameter(title: "chart.configuration.instance.title")
    public var instance: InstanceEntity?

    @Parameter(title: "chart.configuration.system.title")
    public var system: SystemEntity?

    @Parameter(title: "chart.configuration.chartType.title")
    public var chart: ChartTypeEntity?

    public init() {}

    public init(instance: InstanceEntity?, system: SystemEntity?, chart: ChartTypeEntity?) {
        self.instance = instance
        self.system = system
        self.chart = chart
    }
}

public struct SelectInstanceAndMetricIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "widget.configuration.title"
    public static var description: IntentDescription = "widget.configuration.description"

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
    public static var title: LocalizedStringResource = "widget.configuration.title"
    public static var description: IntentDescription = "widget.configuration.description"

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
    private static let userDefaults = UserDefaults(suiteName: "group.com.nohitdev.Beszel")
    private static let cacheKey = "cachedSystemEntities"

    public init() {}

    public func entities(for identifiers: [String]) async throws -> [SystemEntity] {
        // First try to get from API
        let allSystems = await allSystemsForSelectedInstance()
        let found = allSystems.filter { identifiers.contains($0.id) }

        // If we found all requested entities, return them
        if found.count == identifiers.count {
            return found
        }

        // If some entities are missing, try to get them from cache
        // This prevents iOS from seeing the entity as nil when API fails
        let cachedSystems = Self.loadCachedSystems()
        let missingIds = Set(identifiers).subtracting(found.map { $0.id })
        let fromCache = cachedSystems.filter { missingIds.contains($0.id) }

        return found + fromCache
    }

    public func suggestedEntities() async throws -> [SystemEntity] {
        return await allSystemsForSelectedInstance()
    }

    private func allSystemsForSelectedInstance() async -> [SystemEntity] {
        let apiService = await MainActor.run { () -> BeszelAPIService? in
            let manager = InstanceManager.shared
            let idString = Self.userDefaults?.string(forKey: "activeInstanceID")

            guard let activeIDString = idString,
                  let _ = UUID(uuidString: activeIDString),
                  let foundInstance = manager.instances.first(where: { $0.id.uuidString == idString }) else {
                return nil
            }

            return BeszelAPIService(instance: foundInstance, instanceManager: manager)
        }

        guard let apiService = apiService else {
            return Self.loadCachedSystems()
        }

        do {
            let systems = try await apiService.fetchSystems()
            let entities = systems.map { SystemEntity(id: $0.id, name: $0.name) }
            // Cache the systems for future use when API fails
            Self.saveCachedSystems(entities)
            return entities
        } catch {
            Self.logger.error("Failed to fetch systems for widget: \(error.localizedDescription)")
            // Return cached systems when API fails
            return Self.loadCachedSystems()
        }
    }

    // MARK: - Cache helpers

    private static func saveCachedSystems(_ systems: [SystemEntity]) {
        let data = systems.map { ["id": $0.id, "name": $0.name] }
        userDefaults?.set(data, forKey: cacheKey)
    }

    private static func loadCachedSystems() -> [SystemEntity] {
        guard let data = userDefaults?.array(forKey: cacheKey) as? [[String: String]] else {
            return []
        }
        return data.compactMap { dict in
            guard let id = dict["id"], let name = dict["name"] else { return nil }
            return SystemEntity(id: id, name: name)
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
