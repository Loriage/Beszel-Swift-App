import SwiftUI
import Charts

struct HomeView: View {
    let homeViewModel: HomeViewModel
    @Environment(DashboardManager.self) var dashboardManager
    @Environment(SettingsManager.self) var settingsManager
    
    var body: some View {
        @Bindable var viewModel = homeViewModel
        
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeaderView(title: "home.title", subtitle: "home.subtitle")
                HStack {
                    TextField("dashboard.searchPlaceholder", text: $viewModel.searchText)
                        .padding(8)
                        .padding(.leading, 24)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .overlay(
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 8)
                            }
                        )
                    Button(action: {
                        homeViewModel.isShowingFilterSheet = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title)
                    }
                }
                .padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 24) {
                    ForEach(homeViewModel.filteredAndSortedPins) { resolvedItem in
                        pinnedItemView(for: resolvedItem)
                    }
                }
                .padding(.horizontal)
            }
        }
        .overlay {
            if dashboardManager.allPinsForActiveInstance.isEmpty {
                ContentUnavailableView {
                    Label("home.empty.title", systemImage: "pin.slash")
                } description: {
                    Text("home.empty.message")
                }
            }
        }
        .task {
            await homeViewModel.chartDataManager.fetchData()
            homeViewModel.updatePins()
        }
        .onChange(of: dashboardManager.allPinsForActiveInstance) {
            homeViewModel.updatePins()
        }
        .sheet(isPresented: $viewModel.isShowingFilterSheet) {
            FilterView(
                sortOption: $viewModel.sortOption,
                sortDescending: $viewModel.sortDescending
            )
        }
    }
    
    @ViewBuilder
    private func pinnedItemView(for resolvedItem: ResolvedPinnedItem) -> some View {
        let systemData = homeViewModel.chartDataManager.systemData(forSystemID: resolvedItem.systemID)
        let containerData = homeViewModel.chartDataManager.containerData(forSystemID: resolvedItem.systemID)
        let systemName = homeViewModel.chartDataManager.systemName(forSystemID: resolvedItem.systemID)
        
        switch resolvedItem.item {
        case .systemCPU:
            SystemCpuChartView(
                xAxisFormat: homeViewModel.chartDataManager.xAxisFormat,
                dataPoints: systemData,
                systemName: systemName,
                isPinned: homeViewModel.chartDataManager.isPinned(.systemCPU, onSystem: resolvedItem.systemID),
                onPinToggle: { homeViewModel.chartDataManager.togglePin(for: .systemCPU, onSystem: resolvedItem.systemID) }
            )
        case .systemMemory:
            SystemMemoryChartView(
                xAxisFormat: homeViewModel.chartDataManager.xAxisFormat,
                dataPoints: systemData,
                systemName: systemName,
                isPinned: homeViewModel.chartDataManager.isPinned(.systemMemory, onSystem: resolvedItem.systemID),
                onPinToggle: { homeViewModel.chartDataManager.togglePin(for: .systemMemory, onSystem: resolvedItem.systemID) }
            )
        case .systemTemperature:
            SystemTemperatureChartView(
                xAxisFormat: homeViewModel.chartDataManager.xAxisFormat,
                dataPoints: systemData,
                systemName: systemName,
                isPinned: homeViewModel.chartDataManager.isPinned(.systemTemperature, onSystem: resolvedItem.systemID),
                onPinToggle: { homeViewModel.chartDataManager.togglePin(for: .systemTemperature, onSystem: resolvedItem.systemID) }
            )
        case .containerCPU(let name):
            if let container = containerData.first(where: { $0.id == name }) {
                ContainerCpuChartView(
                    xAxisFormat: homeViewModel.chartDataManager.xAxisFormat,
                    container: container,
                    systemName: systemName,
                    isPinned: homeViewModel.chartDataManager.isPinned(.containerCPU(name: container.name), onSystem: resolvedItem.systemID),
                    onPinToggle: { homeViewModel.chartDataManager.togglePin(for: .containerCPU(name: container.name), onSystem: resolvedItem.systemID) }
                )
            }
        case .containerMemory(let name):
            if let container = containerData.first(where: { $0.id == name }) {
                ContainerMemoryChartView(
                    xAxisFormat: homeViewModel.chartDataManager.xAxisFormat,
                    container: container,
                    systemName: systemName,
                    isPinned: homeViewModel.chartDataManager.isPinned(.containerMemory(name: container.name), onSystem: resolvedItem.systemID),
                    onPinToggle: { homeViewModel.chartDataManager.togglePin(for: .containerMemory(name: container.name), onSystem: resolvedItem.systemID) }
                )
            }
        case .stackedContainerCPU:
            StackedCpuChartView(
                settingsManager: settingsManager,
                processedData: containerData,
                systemID: resolvedItem.systemID,
                systemName: systemName
            )
        case .stackedContainerMemory:
            StackedMemoryChartView(
                settingsManager: settingsManager,
                processedData: containerData,
                systemID: resolvedItem.systemID,
                systemName: systemName
            )
        }
    }
}
