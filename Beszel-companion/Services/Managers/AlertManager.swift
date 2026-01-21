import Foundation
import SwiftUI
import Observation
import UserNotifications
import os

private let logger = Logger(subsystem: "com.nohitdev.Beszel", category: "AlertManager")

@Observable
@MainActor
final class AlertManager {
    static let shared = AlertManager()

    private static let appGroupIdentifier = Constants.appGroupId
    private static let lastCheckedKey = "alertsLastCheckedTimestamp"
    private static let seenAlertIDsKey = "seenAlertHistoryIDs"
    private static let notificationsEnabledKey = "alertNotificationsEnabled"

    private var userDefaultsStore: UserDefaults {
        UserDefaults(suiteName: Self.appGroupIdentifier) ?? .standard
    }

    var alerts: [String: [AlertRecord]] = [:]
    var alertHistory: [AlertHistoryRecord] = []
    var unreadAlertCount: Int = 0
    var isLoading = false
    var errorMessage: String?
    var pendingAlertDetail: AlertDetail?

    var notificationsEnabled: Bool {
        didSet {
            userDefaultsStore.set(notificationsEnabled, forKey: Self.notificationsEnabledKey)
            if notificationsEnabled {
                Task {
                    await requestNotificationPermission()
                    BackgroundAlertChecker.shared.scheduleBackgroundTask()
                }
            } else {
                BackgroundAlertChecker.shared.cancelScheduledTask()
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
        let store = UserDefaults(suiteName: Self.appGroupIdentifier) ?? .standard

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

    /// Lightweight alert refresh for fast polling - fetches recent alerts and configured alerts
    func refreshAlertsQuick(for instance: Instance, instanceManager: InstanceManager) async {
        let apiService = getApiService(for: instance, instanceManager: instanceManager)

        do {
            // Fetch both alerts config and recent history in parallel
            async let alertsTask = apiService.fetchAlerts(filter: nil)
            async let historyTask = apiService.fetchLatestAlertHistory(limit: 20)

            let (fetchedAlerts, fetchedHistory) = try await (alertsTask, historyTask)

            // Update configured alerts
            var alertsBySystem: [String: [AlertRecord]] = [:]
            for alert in fetchedAlerts {
                alertsBySystem[alert.system, default: []].append(alert)
            }
            self.alerts = alertsBySystem

            // Merge new history records
            let existingIDs = Set(alertHistory.map { $0.id })
            let newRecords = fetchedHistory.filter { !existingIDs.contains($0.id) }

            if !newRecords.isEmpty {
                alertHistory.insert(contentsOf: newRecords, at: 0)
                alertHistory.sort { $0.created > $1.created }

                // Keep history at reasonable size
                if alertHistory.count > 200 {
                    alertHistory = Array(alertHistory.prefix(200))
                }

                // Prune seen IDs to prevent unbounded growth
                pruneSeenAlertIDs()

                updateUnreadCount()
            }
        } catch {
            // Silent fail for quick refresh - don't spam logs
            logger.debug("Quick alert refresh failed: \(error.localizedDescription)")
        }
    }

    func markAllAsRead() {
        for alert in alertHistory {
            seenAlertHistoryIDs.insert(alert.id)
        }
        unreadAlertCount = 0
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

    /// Prunes seenAlertHistoryIDs to only keep IDs that are in current alertHistory
    /// This prevents unbounded memory growth from storing IDs forever
    private func pruneSeenAlertIDs() {
        let currentHistoryIDs = Set(alertHistory.map { $0.id })
        let prunedIDs = seenAlertHistoryIDs.intersection(currentHistoryIDs)

        // Only update if we actually removed something (to avoid unnecessary UserDefaults writes)
        if prunedIDs.count < seenAlertHistoryIDs.count {
            let oldCount = seenAlertHistoryIDs.count
            seenAlertHistoryIDs = prunedIDs
            logger.debug("Pruned seen alert IDs from \(oldCount) to \(prunedIDs.count)")
        }
    }
}
