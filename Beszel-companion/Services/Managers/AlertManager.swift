import Foundation
import SwiftUI
import Observation
import UserNotifications
import os

nonisolated private let logger = Logger(subsystem: "com.nohitdev.Beszel", category: "AlertManager")

@Observable
@MainActor
final class AlertManager {
    static let shared = AlertManager()
    
    private static let lastCheckedKey = "alertsLastCheckedTimestamp"
    private static let seenAlertIDsKey = "seenAlertHistoryIDs"
    private static let notificationsEnabledKey = "alertNotificationsEnabled"
    private static let mutedAlertIDsKey = "mutedAlertIDs"
    
    private var userDefaultsStore: UserDefaults {
        .sharedSuite
    }
    
    var alerts: [String: [AlertRecord]] = [:]
    var alertHistory: [AlertHistoryRecord] = []
    var unreadAlertCount: Int = 0
    var isLoading = false
    var errorMessage: String?
    var pendingAlertDetail: AlertDetail?

    /// IDs of active alerts the user has muted from the badge
    private(set) var mutedAlertIDs: Set<String> = [] {
        didSet {
            do {
                let data = try JSONEncoder().encode(Array(mutedAlertIDs))
                userDefaultsStore.set(data, forKey: Self.mutedAlertIDsKey)
            } catch {
                logger.error("Failed to encode mutedAlertIDs: \(error.localizedDescription)")
            }
        }
    }

    /// Number of active (unresolved) alerts not muted by the user
    var badgeCount: Int {
        let activeIDs = Set(alertHistory.filter { !$0.isResolved }.map { $0.id })
        return activeIDs.subtracting(mutedAlertIDs).count
    }

    func isAlertMuted(_ id: String) -> Bool {
        mutedAlertIDs.contains(id)
    }

    func toggleMute(for id: String) {
        if mutedAlertIDs.contains(id) {
            mutedAlertIDs.remove(id)
        } else {
            mutedAlertIDs.insert(id)
        }
    }

    func muteAllActiveAlerts() {
        let activeIDs = alertHistory.filter { !$0.isResolved }.map { $0.id }
        mutedAlertIDs.formUnion(activeIDs)
    }

    /// Remove muted IDs for alerts that are no longer active
    func pruneMutedAlertIDs() {
        let activeIDs = Set(alertHistory.filter { !$0.isResolved }.map { $0.id })
        let pruned = mutedAlertIDs.intersection(activeIDs)
        if pruned.count < mutedAlertIDs.count {
            mutedAlertIDs = pruned
        }
    }
    
    var notificationsEnabled: Bool {
        didSet {
            userDefaultsStore.set(notificationsEnabled, forKey: Self.notificationsEnabledKey)
            if notificationsEnabled {
                Task {
                    await requestNotificationPermission()
                    await PushNotificationService.shared.requestNotificationPermission()
                }
            }
        }
    }
    
    private var lastCheckedTimestamp: Date {
        didSet {
            userDefaultsStore.set(lastCheckedTimestamp.timeIntervalSince1970, forKey: Self.lastCheckedKey)
        }
    }
    
    private var seenAlertHistoryIDs: Set<String> {
        didSet {
            do {
                let data = try JSONEncoder().encode(Array(seenAlertHistoryIDs))
                userDefaultsStore.set(data, forKey: Self.seenAlertIDsKey)
            } catch {
                logger.error("Failed to encode seenAlertHistoryIDs: \(error.localizedDescription)")
            }
        }
    }
    
    // Cache API service to avoid creating new instances and auth conflicts
    private var cachedApiService: BeszelAPIService?
    private var cachedInstanceId: UUID?
    
    private func getApiService(for instance: Instance, instanceManager: InstanceManager) -> BeszelAPIService {
        if let cached = cachedApiService, cachedInstanceId == instance.id {
            return cached
        }
        let service = BeszelAPIService(instance: instance, instanceManager: instanceManager)
        cachedApiService = service
        cachedInstanceId = instance.id
        return service
    }
    
    /// Clears the cached API service to free memory (useful after background tasks)
    func clearCachedApiService() {
        cachedApiService = nil
        cachedInstanceId = nil
    }
    
    init() {
        let store = UserDefaults.sharedSuite

        let timestamp = store.double(forKey: Self.lastCheckedKey)
        self.lastCheckedTimestamp = timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : Date()
        
        if let data = store.data(forKey: Self.seenAlertIDsKey) {
            do {
                let ids = try JSONDecoder().decode([String].self, from: data)
                self.seenAlertHistoryIDs = Set(ids)
            } catch {
                logger.error("Failed to decode seenAlertHistoryIDs on init: \(error.localizedDescription)")
                self.seenAlertHistoryIDs = []
            }
        } else {
            self.seenAlertHistoryIDs = []
        }
        
        self.notificationsEnabled = store.bool(forKey: Self.notificationsEnabledKey)

        if let data = store.data(forKey: Self.mutedAlertIDsKey) {
            do {
                let ids = try JSONDecoder().decode([String].self, from: data)
                self.mutedAlertIDs = Set(ids)
            } catch {
                logger.error("Failed to decode mutedAlertIDs on init: \(error.localizedDescription)")
                self.mutedAlertIDs = []
            }
        }
    }
    
    func fetchAlerts(for instance: Instance, instanceManager: InstanceManager) async {
        isLoading = true
        errorMessage = nil
        
        let apiService = getApiService(for: instance, instanceManager: instanceManager)
        
        do {
            async let alertsTask = apiService.fetchAlerts(filter: nil)
            async let historyTask = apiService.fetchLatestAlertHistory(limit: 100)
            
            let (fetchedAlerts, fetchedHistory) = try await (alertsTask, historyTask)
            
            var alertsBySystem: [String: [AlertRecord]] = [:]
            for alert in fetchedAlerts {
                alertsBySystem[alert.system, default: []].append(alert)
            }
            self.alerts = alertsBySystem
            
            self.alertHistory = fetchedHistory.sorted { $0.created > $1.created }
            
            // Keep history at reasonable size
            if alertHistory.count > 200 {
                alertHistory = Array(alertHistory.prefix(200))
            }
            
            // Prune seen IDs to prevent unbounded growth
            pruneSeenAlertIDs()
            pruneMutedAlertIDs()

            updateUnreadCount()
            
            logger.info("Fetched \(fetchedAlerts.count) alerts and \(fetchedHistory.count) history records")
        } catch let error as BeszelAPIService.BeszelAPIError {
            logger.error("Failed to fetch alerts: \(error.localizedDescription)")
            if case .httpError(let statusCode, _) = error, statusCode == 404 {
                errorMessage = String(localized: "alerts.error.notAvailable")
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            logger.error("Failed to fetch alerts: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func checkForNewAlerts(for instance: Instance, instanceManager: InstanceManager) async -> [AlertHistoryRecord] {
        let apiService = getApiService(for: instance, instanceManager: instanceManager)
        
        do {
            let newAlerts = try await apiService.fetchAlertHistorySince(date: lastCheckedTimestamp)
            
            let unseenAlerts = newAlerts.filter { !seenAlertHistoryIDs.contains($0.id) }
            
            if !unseenAlerts.isEmpty {
                for alert in unseenAlerts {
                    seenAlertHistoryIDs.insert(alert.id)
                }
                
                let existingIDs = Set(alertHistory.map { $0.id })
                let newUniqueAlerts = unseenAlerts.filter { !existingIDs.contains($0.id) }
                alertHistory.insert(contentsOf: newUniqueAlerts, at: 0)
                alertHistory.sort { $0.created > $1.created }
                
                // Keep history at reasonable size to prevent memory growth
                if alertHistory.count > 200 {
                    alertHistory = Array(alertHistory.prefix(200))
                }
                
                // Prune seen IDs to prevent unbounded growth
                pruneSeenAlertIDs()
                
                updateUnreadCount()
            }
            
            lastCheckedTimestamp = Date()
            
            return unseenAlerts
        } catch {
            logger.error("Failed to check for new alerts: \(error.localizedDescription)")
            return []
        }
    }
    
    @discardableResult
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            logger.info("Notification permission granted: \(granted)")
            return granted
        } catch {
            logger.error("Failed to request notification permission: \(error.localizedDescription)")
            return false
        }
    }
    
    func sendLocalNotification(for alert: AlertHistoryRecord, systemName: String) {
        guard notificationsEnabled else { return }
        
        let alertDetail = AlertDetail(alert: alert, systemName: systemName)
        
        let content = UNMutableNotificationContent()
        content.title = String(localized: "alerts.notification.title")
        content.body = String(format: String(localized: "alerts.notification.body"), alert.displayName, systemName, alert.triggeredValueDescription)
        content.sound = .default
        content.userInfo = alertDetail.userInfoPayload()
        
        let request = UNNotificationRequest(
            identifier: "alert-\(alert.id)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                logger.error("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }
    
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        if let alertDetail = AlertDetail(userInfo: userInfo) {
            pendingAlertDetail = alertDetail
        }
    }
    
    func refreshAlertsQuick(for instance: Instance, instanceManager: InstanceManager) async {
        let apiService = getApiService(for: instance, instanceManager: instanceManager)
        
        do {
            async let alertsTask = apiService.fetchAlerts(filter: nil)
            async let historyTask = apiService.fetchLatestAlertHistory(limit: 20)
            
            let (fetchedAlerts, fetchedHistory) = try await (alertsTask, historyTask)
            
            var alertsBySystem: [String: [AlertRecord]] = [:]
            for alert in fetchedAlerts {
                alertsBySystem[alert.system, default: []].append(alert)
            }
            self.alerts = alertsBySystem
            
            let existingIDs = Set(alertHistory.map { $0.id })
            let newRecords = fetchedHistory.filter { !existingIDs.contains($0.id) }
            
            if !newRecords.isEmpty {
                alertHistory.insert(contentsOf: newRecords, at: 0)
                alertHistory.sort { $0.created > $1.created }
                
                if alertHistory.count > 200 {
                    alertHistory = Array(alertHistory.prefix(200))
                }
                
                pruneSeenAlertIDs()
                pruneMutedAlertIDs()

                updateUnreadCount()
            }
        } catch {
            logger.debug("Quick alert refresh failed: \(error.localizedDescription)")
        }
    }
    
    func createAlert(system: String, name: String, value: Double, min: Double, instance: Instance, instanceManager: InstanceManager) async throws {
        let apiService = getApiService(for: instance, instanceManager: instanceManager)
        _ = try await apiService.createAlert(system: system, name: name, value: value, min: min)
        await fetchAlerts(for: instance, instanceManager: instanceManager)
    }

    func updateAlert(id: String, system: String, name: String, value: Double, min: Double, instance: Instance, instanceManager: InstanceManager) async throws {
        let apiService = getApiService(for: instance, instanceManager: instanceManager)
        _ = try await apiService.updateAlert(id: id, system: system, name: name, value: value, min: min)
        await fetchAlerts(for: instance, instanceManager: instanceManager)
    }

    func deleteAlert(id: String, instance: Instance, instanceManager: InstanceManager) async throws {
        let apiService = getApiService(for: instance, instanceManager: instanceManager)
        try await apiService.deleteAlert(id: id)
        // Remove locally first for immediate UI feedback
        for key in alerts.keys {
            alerts[key]?.removeAll { $0.id == id }
        }
        await fetchAlerts(for: instance, instanceManager: instanceManager)
    }

    func markAllAsRead() {
        for alert in alertHistory {
            seenAlertHistoryIDs.insert(alert.id)
        }
        unreadAlertCount = 0
    }
    
    func configuredAlert(for historyRecord: AlertHistoryRecord) -> AlertRecord? {
        guard let alertId = historyRecord.alertId else { return nil }
        return alerts.values.flatMap { $0 }.first { $0.id == alertId }
    }

    func alertsForSystem(_ systemID: String) -> [AlertRecord] {
        alerts[systemID] ?? []
    }
    
    func historyForSystem(_ systemID: String) -> [AlertHistoryRecord] {
        alertHistory.filter { $0.system == systemID }
    }
    
    private func updateUnreadCount() {
        unreadAlertCount = alertHistory.filter { !seenAlertHistoryIDs.contains($0.id) }.count
    }
    
    
    private func pruneSeenAlertIDs() {
        let currentHistoryIDs = Set(alertHistory.map { $0.id })
        let prunedIDs = seenAlertHistoryIDs.intersection(currentHistoryIDs)
        
        if prunedIDs.count < seenAlertHistoryIDs.count {
            let oldCount = seenAlertHistoryIDs.count
            seenAlertHistoryIDs = prunedIDs
            logger.debug("Pruned seen alert IDs from \(oldCount) to \(prunedIDs.count)")
        }
    }
}
