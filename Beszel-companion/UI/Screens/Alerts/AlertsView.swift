import SwiftUI

struct AlertHistoryView: View {
    @Environment(AlertManager.self) var alertManager
    @Environment(InstanceManager.self) var instanceManager

    @State private var searchText = ""
    @State private var isShowingFilterSheet = false
    @State private var selectedSystemID: String?
    @State private var selectedAlertType: AlertType?
    @State private var selectedState: AlertStateFilter = .all

    private var hasActiveFilters: Bool {
        selectedSystemID != nil || selectedAlertType != nil || selectedState != .all
    }

    private var filteredHistory: [AlertHistoryRecord] {
        var result: [AlertHistoryRecord]
        if let systemID = selectedSystemID {
            result = alertManager.historyForSystem(systemID)
        } else {
            result = alertManager.alertHistory
        }

        if let alertType = selectedAlertType {
            result = result.filter { $0.alertType == alertType }
        }

        switch selectedState {
        case .all: break
        case .active: result = result.filter { !$0.isResolved }
        case .resolved: result = result.filter { $0.isResolved }
        }

        guard !searchText.isEmpty else { return result }

        return result.filter { alert in
            let systemName = instanceManager.systems.first { $0.id == alert.system }?.name ?? ""
            return systemName.localizedCaseInsensitiveContains(searchText) ||
                alert.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBarView

            contentView
        }
        .onAppear {
            alertManager.markAllAsRead()
            if alertManager.alertHistory.isEmpty {
                Task {
                    await refreshAlerts()
                }
            }
        }
        .sheet(isPresented: $isShowingFilterSheet) {
            AlertHistoryFilterView(
                selectedSystemID: $selectedSystemID,
                selectedAlertType: $selectedAlertType,
                selectedState: $selectedState
            )
        }
    }

    @ViewBuilder
    private var searchBarView: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search alerts", text: $searchText)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6), in: Capsule())

            Button {
                isShowingFilterSheet = true
            } label: {
                Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.title)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var contentView: some View {
        if filteredHistory.isEmpty {
            ContentUnavailableView {
                Label("alerts.history.empty.title", systemImage: "bell.slash")
            } description: {
                Text("alerts.history.empty.message")
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredHistory) { alert in
                        let systemName = instanceManager.systems.first { $0.id == alert.system }?.name
                        AlertHistoryRow(
                            alert: alert,
                            systemName: systemName
                        )
                    }
                }
                .padding()
            }
            .groupBoxStyle(CardGroupBoxStyle())
            .refreshable {
                await refreshAlerts()
            }
        }
    }

    private func refreshAlerts() async {
        guard let instance = instanceManager.activeInstance else { return }
        await alertManager.fetchAlerts(for: instance, instanceManager: instanceManager)
    }
}

struct ConfiguredAlertsView: View {
    @Environment(AlertManager.self) var alertManager
    @Environment(InstanceManager.self) var instanceManager

    @State private var selectedSystemID: String?
    @State private var alertStates: [AlertType: AlertTypeState] = [:]
    @State private var debounceTask: [AlertType: Task<Void, Never>] = [:]

    struct AlertTypeState {
        var isEnabled: Bool = false
        var threshold: Double = 50
        var duration: Double = 1
        var alertRecordId: String?
    }

    var body: some View {
        VStack(spacing: 0) {
            systemFilterView

            contentView
        }
        .onAppear {
            if selectedSystemID == nil, let first = instanceManager.systems.first {
                selectedSystemID = first.id
            }
            loadExistingAlerts()
        }
        .onChange(of: selectedSystemID) {
            loadExistingAlerts()
        }
    }

    @ViewBuilder
    private var systemFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(instanceManager.systems, id: \.id) { system in
                    FilterChip(
                        title: system.name,
                        isSelected: selectedSystemID == system.id
                    ) {
                        selectedSystemID = system.id
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if selectedSystemID == nil {
            ContentUnavailableView {
                Label("alerts.configured.empty.title", systemImage: "bell.badge")
            } description: {
                Text("alerts.configured.empty.message")
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(AlertType.allCases) { type in
                        alertTypeCard(for: type)
                    }
                }
                .padding()
            }
            .groupBoxStyle(CardGroupBoxStyle())
        }
    }

    // MARK: - Alert Type Card

    @ViewBuilder
    private func alertTypeCard(for type: AlertType) -> some View {
        let state = alertStates[type] ?? AlertTypeState()

        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(state.isEnabled ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                            .frame(width: 40, height: 40)

                        Image(systemName: type.iconName)
                            .foregroundColor(state.isEnabled ? .accentColor : .secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(type.displayNameKey))
                            .font(.headline)

                        Text(LocalizedStringKey(type.alertDescriptionKey))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: toggleBinding(for: type))
                        .labelsHidden()
                        .tint(.green)
                }

                if state.isEnabled {
                    slidersView(for: type, state: state)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.isEnabled)
    }

    @ViewBuilder
    private func slidersView(for type: AlertType, state: AlertTypeState) -> some View {
        Divider()

        if type.needsThreshold {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("alerts.form.threshold")
                        .font(.subheadline)
                    Spacer()
                    Text(type.formatValue(state.threshold))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: thresholdBinding(for: type),
                    in: thresholdRange(for: type),
                    step: 1
                )
                .tint(.accentColor)
            }
        }

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("alerts.form.duration")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(state.duration)) min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Slider(value: durationBinding(for: type), in: 1...60, step: 1)
                .tint(.accentColor)
        }
    }

    // MARK: - Bindings

    private func toggleBinding(for type: AlertType) -> Binding<Bool> {
        Binding(
            get: { alertStates[type]?.isEnabled ?? false },
            set: { newValue in
                alertStates[type, default: AlertTypeState()].isEnabled = newValue
                if newValue {
                    createAlert(for: type)
                } else {
                    deleteAlert(for: type)
                }
            }
        )
    }

    private func thresholdBinding(for type: AlertType) -> Binding<Double> {
        Binding(
            get: { alertStates[type]?.threshold ?? 50 },
            set: { newValue in
                alertStates[type, default: AlertTypeState()].threshold = newValue
                debouncedUpdate(for: type)
            }
        )
    }

    private func durationBinding(for type: AlertType) -> Binding<Double> {
        Binding(
            get: { alertStates[type]?.duration ?? 1 },
            set: { newValue in
                alertStates[type, default: AlertTypeState()].duration = newValue
                debouncedUpdate(for: type)
            }
        )
    }

    // MARK: - Threshold config per type

    private func thresholdRange(for type: AlertType) -> ClosedRange<Double> {
        switch type {
        case .cpu, .memory, .disk, .gpu, .battery: return 1...99
        case .bandwidth: return 1...125
        case .temperature: return 1...100
        case .loadAverage1m, .loadAverage5m, .loadAverage15m: return 1...100
        case .status: return 0...1
        }
    }

    private func defaultThreshold(for type: AlertType) -> Double {
        switch type {
        case .loadAverage1m, .loadAverage5m, .loadAverage15m: return 10
        case .battery: return 20
        default: return 50
        }
    }

    // MARK: - Data loading

    private func loadExistingAlerts() {
        guard let systemID = selectedSystemID else { return }

        let existingAlerts = alertManager.alertsForSystem(systemID)

        var newStates: [AlertType: AlertTypeState] = [:]
        for type in AlertType.allCases {
            if let alert = existingAlerts.first(where: { $0.alertType == type }) {
                newStates[type] = AlertTypeState(
                    isEnabled: true,
                    threshold: alert.value ?? 50,
                    duration: alert.min ?? 1,
                    alertRecordId: alert.id
                )
            } else {
                newStates[type] = AlertTypeState(threshold: defaultThreshold(for: type))
            }
        }
        alertStates = newStates
    }

    // MARK: - API actions

    private func createAlert(for type: AlertType) {
        guard let systemID = selectedSystemID,
              let instance = instanceManager.activeInstance else { return }

        let state = alertStates[type] ?? AlertTypeState()
        let thresholdValue: Double = type.needsThreshold ? state.threshold : 0
        let durationValue: Double = state.duration

        Task {
            do {
                try await alertManager.createAlert(
                    system: systemID,
                    name: type.rawValue,
                    value: thresholdValue,
                    min: durationValue,
                    instance: instance,
                    instanceManager: instanceManager
                )
                let alerts = alertManager.alertsForSystem(systemID)
                if let created = alerts.first(where: { $0.alertType == type }) {
                    alertStates[type]?.alertRecordId = created.id
                }
            } catch {
                alertStates[type]?.isEnabled = false
                alertManager.errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteAlert(for type: AlertType) {
        guard let recordId = alertStates[type]?.alertRecordId,
              let instance = instanceManager.activeInstance else { return }

        Task {
            do {
                try await alertManager.deleteAlert(
                    id: recordId,
                    instance: instance,
                    instanceManager: instanceManager
                )
                alertStates[type]?.alertRecordId = nil
            } catch {
                alertStates[type]?.isEnabled = true
                alertManager.errorMessage = error.localizedDescription
            }
        }
    }

    private func debouncedUpdate(for type: AlertType) {
        debounceTask[type]?.cancel()
        debounceTask[type] = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await updateAlert(for: type)
        }
    }

    private func updateAlert(for type: AlertType) async {
        guard let state = alertStates[type],
              let recordId = state.alertRecordId,
              let systemID = selectedSystemID,
              let instance = instanceManager.activeInstance else { return }

        let thresholdValue: Double = type.needsThreshold ? state.threshold : 0

        do {
            try await alertManager.updateAlert(
                id: recordId,
                system: systemID,
                name: type.rawValue,
                value: thresholdValue,
                min: state.duration,
                instance: instance,
                instanceManager: instanceManager
            )
        } catch {
            alertManager.errorMessage = error.localizedDescription
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
