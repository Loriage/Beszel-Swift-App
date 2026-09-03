import Foundation

nonisolated struct WidgetQueryConnection: Sendable {
    let instanceID: UUID
    let apiService: BeszelAPIService
}

nonisolated enum WidgetConfigurationError: Error {
    case noInstance
    case invalidSystem
}

nonisolated enum WidgetConfigurationData {
    @MainActor
    static func connection(instanceID: String?) throws -> WidgetQueryConnection {
        try Task.checkCancellation()
        let manager = InstanceManager.shared
        manager.reloadFromStore()
        let resolvedID = instanceID ?? UserDefaults.sharedSuite.string(forKey: "activeInstanceID")
        guard let resolvedID, let id = UUID(uuidString: resolvedID),
              let instance = manager.instances.first(where: { $0.id == id }) else {
            throw WidgetConfigurationError.noInstance
        }
        return WidgetQueryConnection(
            instanceID: id,
            apiService: BeszelAPIService(instance: instance, instanceManager: manager)
        )
    }

    static func systemFilter(_ systemID: String) throws -> String {
        // PocketBase IDs are ASCII alphanumeric; never interpolate arbitrary text
        // into a filter expression received from a saved intent parameter.
        guard !systemID.isEmpty,
              systemID.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) }) else {
            throw WidgetConfigurationError.invalidSystem
        }
        return "system = '\(systemID)'"
    }

    static func systems(instanceID: String?) async throws -> [SystemEntity] {
        let connection = try await connection(instanceID: instanceID)
        let cacheKey = systemCacheKey(instanceID: connection.instanceID)
        do {
            let records = try await connection.apiService.fetchSystems()
            try Task.checkCancellation()
            let systems = records.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                .map { SystemEntity(id: $0.id, name: $0.name) }
            UserDefaults.sharedSuite.set(systems.map { ["id": $0.id, "name": $0.name] }, forKey: cacheKey)
            return systems
        } catch {
            try Task.checkCancellation()
            guard let cached = UserDefaults.sharedSuite.array(forKey: cacheKey) as? [[String: String]] else {
                throw error
            }
            return cached.compactMap { value in
                guard let id = value["id"], let name = value["name"] else { return nil }
                return SystemEntity(id: id, name: name)
            }
        }
    }

    static func systemCacheKey(instanceID: UUID) -> String {
        "widgetSystemEntities.v2.\(instanceID.uuidString)"
    }
}

/// A query-owned cache avoids fetching the same small catalog for every keystroke.
actor WidgetContainerCatalog {
    private struct Scope: Hashable {
        let instanceID: UUID
        let systemID: String
    }
    private var scope: Scope?
    private var cachedRecords: [ContainerRecord] = []
    private var expiresAt = Date.distantPast

    func records(connection: WidgetQueryConnection, systemID: String) async throws -> [ContainerRecord] {
        try Task.checkCancellation()
        let requestedScope = Scope(instanceID: connection.instanceID, systemID: systemID)
        if scope == requestedScope, expiresAt > .now {
            return cachedRecords
        }
        let records = try await connection.apiService.fetchContainers(
            filter: WidgetConfigurationData.systemFilter(systemID)
        )
        try Task.checkCancellation()
        scope = requestedScope
        cachedRecords = records
        expiresAt = .now.addingTimeInterval(30)
        return records
    }
}
