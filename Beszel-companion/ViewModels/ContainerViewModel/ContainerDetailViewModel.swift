import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class ContainerDetailViewModel {
    let container: ProcessedContainerData
    private let dashboardManager: DashboardManager
    private let settingsManager: SettingsManager

    // Ces propriétés sont calculées dynamiquement pour refléter l'état réel sans duplication
    var isCpuChartPinned: Bool {
        dashboardManager.isPinned(.containerCPU(name: container.name))
    }
    
    var isMemoryChartPinned: Bool {
        dashboardManager.isPinned(.containerMemory(name: container.name))
    }

    init(container: ProcessedContainerData, dashboardManager: DashboardManager, settingsManager: SettingsManager) {
        self.container = container
        self.dashboardManager = dashboardManager
        self.settingsManager = settingsManager
    }

    var containerName: String {
        container.name
    }

    var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }

    func toggleCpuPin() {
        dashboardManager.togglePin(for: .containerCPU(name: container.name))
    }

    func toggleMemoryPin() {
        dashboardManager.togglePin(for: .containerMemory(name: container.name))
    }
}
