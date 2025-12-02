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
        // CORRECTION : Accès sécurisé à InstanceManager via MainActor.run
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
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [SystemEntity] {
        let allSystems = await allSystemsForSelectedInstance()
        return allSystems.filter { identifiers.contains($0.id) }
    }

    public func suggestedEntities() async throws -> [SystemEntity] {
        // CORRECTION : Ajout de await manquant
        return await allSystemsForSelectedInstance()
    }

    private func allSystemsForSelectedInstance() async -> [SystemEntity] {
        // CORRECTION : Récupération isolée de l'instance et de l'ID
        let (instance, instanceIDString) = await MainActor.run {
            let manager = InstanceManager.shared
            let idString = UserDefaults(suiteName: "group.com.nohitdev.Beszel")?.string(forKey: "activeInstanceID")
            // On cherche l'instance correspondante
            let foundInstance = manager.instances.first(where: { $0.id.uuidString == idString })
            return (foundInstance, idString)
        }

        guard let activeInstanceIDString = instanceIDString,
              let _ = UUID(uuidString: activeInstanceIDString),
              let instance = instance // Instance récupérée plus haut
        else {
            return []
        }
        
        // On recrée un service API temporaire pour le widget (qui est un actor, donc OK)
        // Note: BeszelAPIService attend un InstanceManager.
        // Comme nous sommes dans une Query async, nous pouvons utiliser le singleton partagé,
        // mais nous devons passer une référence safe.
        // L'idéal ici est de créer une version allégée du service ou d'utiliser le shared via MainActor.
        
        // Pour simplifier et faire fonctionner le code :
        let apiService = await MainActor.run {
             return BeszelAPIService(instance: instance, instanceManager: InstanceManager.shared)
        }
        
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
