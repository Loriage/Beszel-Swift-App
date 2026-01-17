import Foundation
import BackgroundTasks
import os

private let logger = Logger(subsystem: "com.nohitdev.Beszel", category: "BackgroundAlertChecker")

@MainActor
final class BackgroundAlertChecker {
    static let shared = BackgroundAlertChecker()
    static let taskIdentifier = Constants.backgroundTaskIdentifier
    
    private init() {}
    
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                logger.error("Unexpected task type: \(type(of: task))")
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await self.handleBackgroundTask(refreshTask)
            }
        }
        logger.info("Background task registered")
    }
    
    func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background task scheduled for ~15 minutes from now")
        } catch {
            logger.error("Failed to schedule background task: \(error.localizedDescription)")
        }
    }
    
    func cancelScheduledTask() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
        logger.info("Background task cancelled")
    }
    
    private func handleBackgroundTask(_ task: BGAppRefreshTask) async {
        scheduleBackgroundTask()
        
        task.expirationHandler = {
            logger.warning("Background task expired")
            task.setTaskCompleted(success: false)
        }
        
        guard AlertManager.shared.notificationsEnabled else {
            logger.info("Notifications disabled, skipping background check")
            task.setTaskCompleted(success: true)
            return
        }
        
        let instanceManager = InstanceManager.shared
        guard let activeInstance = instanceManager.activeInstance else {
            logger.info("No active instance, skipping background check")
            task.setTaskCompleted(success: true)
            return
        }
        
        if instanceManager.systems.isEmpty {
            logger.info("Systems not loaded, fetching for background task")
            let apiService = BeszelAPIService(instance: activeInstance, instanceManager: instanceManager)
            do {
                let fetchedSystems = try await apiService.fetchSystems()
                instanceManager.systems = fetchedSystems.sorted { $0.name < $1.name }
                instanceManager.refreshActiveSystem()
                logger.info("Loaded \(fetchedSystems.count) systems for background task")
            } catch {
                logger.error("Failed to fetch systems in background: \(error.localizedDescription)")
            }
        }
        
        let newAlerts = await AlertManager.shared.checkForNewAlerts(
            for: activeInstance,
            instanceManager: instanceManager
        )
        
        for alert in newAlerts {
            let systemName = instanceManager.systems.first { $0.id == alert.system }?.name ?? "Unknown"
            AlertManager.shared.sendLocalNotification(for: alert, systemName: systemName)
        }
        
        AlertManager.shared.clearCachedApiService()
        
        logger.info("Background check completed, found \(newAlerts.count) new alerts")
        task.setTaskCompleted(success: true)
    }
}
