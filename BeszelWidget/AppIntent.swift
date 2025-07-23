import WidgetKit
import AppIntents
import SwiftUI

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
        return InstanceManager.shared.instances.map { InstanceEntity(id: $0.id.uuidString, name: $0.name) }
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
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [SystemEntity] {
        let allSystems = await allSystemsForSelectedInstance()
        return allSystems.filter { identifiers.contains($0.id) }
    }

    public func suggestedEntities() async throws -> [SystemEntity] {
        return await allSystemsForSelectedInstance()
    }

    private func allSystemsForSelectedInstance() async -> [SystemEntity] {
        let instanceManager = InstanceManager.shared

        guard let activeInstanceIDString = UserDefaults(suiteName: InstanceManager.appGroupIdentifier)?.string(forKey: "activeInstanceID"),
              let instanceID = UUID(uuidString: activeInstanceIDString),
              let instance = instanceManager.instances.first(where: { $0.id == instanceID })
        else {
            return []
        }
        
        let apiService = BeszelAPIService(instance: instance, instanceManager: instanceManager)
        
        do {
            let systems = try await apiService.fetchSystems()
            return systems.map { SystemEntity(id: $0.id, name: $0.name) }
        } catch {
            print("Failed to fetch systems for widget: \(error)")
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
            ChartTypeEntity(id: "systemCPU", title: "widget.chart.systemCPU.title"),
            ChartTypeEntity(id: "systemMemory", title: "widget.chart.systemMemory.title"),
            ChartTypeEntity(id: "systemTemperature", title: "widget.chart.systemTemperature.title")
        ]
    }
}

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
