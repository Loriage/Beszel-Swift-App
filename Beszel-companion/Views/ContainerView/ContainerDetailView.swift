import SwiftUI
import Charts

struct ContainerDetailView: View {
    @StateObject var viewModel: ContainerDetailViewModel

    init(container: ProcessedContainerData, settingsManager: SettingsManager, dashboardManager: DashboardManager) {
        _viewModel = StateObject(wrappedValue: ContainerDetailViewModel(
            container: container,
            dashboardManager: dashboardManager,
            settingsManager: settingsManager
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(viewModel.containerName)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            VStack(alignment: .leading, spacing: 24) {
                ContainerCpuChartView(
                    xAxisFormat: viewModel.xAxisFormat,
                    container: viewModel.container,
                    isPinned: viewModel.isCpuChartPinned,
                    onPinToggle: viewModel.toggleCpuPin
                )
                ContainerMemoryChartView(
                    xAxisFormat: viewModel.xAxisFormat,
                    container: viewModel.container,
                    isPinned: viewModel.isMemoryChartPinned,
                    onPinToggle: viewModel.toggleMemoryPin
                )
                Spacer()
            }
            .padding()
        }
    }
}
