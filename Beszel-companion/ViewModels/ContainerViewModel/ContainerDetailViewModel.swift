import Foundation
import SwiftUI
import Combine

class ContainerDetailViewModel: ObservableObject {
    let container: ProcessedContainerData
    private let dashboardManager: DashboardManager
    private let settingsManager: SettingsManager
    private var cancellables = Set<AnyCancellable>()

    @Published var isCpuChartPinned: Bool
    @Published var isMemoryChartPinned: Bool

    init(container: ProcessedContainerData, dashboardManager: DashboardManager, settingsManager: SettingsManager) {
        self.container = container
        self.dashboardManager = dashboardManager
        self.settingsManager = settingsManager

        self.isCpuChartPinned = dashboardManager.isPinned(.containerCPU(name: container.name))
        self.isMemoryChartPinned = dashboardManager.isPinned(.containerMemory(name: container.name))

        dashboardManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePinState()
            }
            .store(in: &cancellables)
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

    private func updatePinState() {
        self.isCpuChartPinned = dashboardManager.isPinned(.containerCPU(name: container.name))
        self.isMemoryChartPinned = dashboardManager.isPinned(.containerMemory(name: container.name))
    }
}
