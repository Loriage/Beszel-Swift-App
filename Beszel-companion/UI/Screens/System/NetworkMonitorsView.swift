import SwiftUI

struct NetworkMonitorsCard: View {
    let system: SystemRecord
    let monitoring: NetworkMonitorStore

    private var monitors: [NetworkMonitorRecord] {
        monitoring.monitors(for: system.id).sorted { $0.targetLabel.localizedStandardCompare($1.targetLabel) == .orderedAscending }
    }

    var body: some View {
        NavigationLink {
            NetworkMonitorsView(system: system, monitoring: monitoring)
        } label: {
            GroupBox {
                VStack(spacing: 8) {
                    ForEach(monitors) { monitor in
                        NetworkMonitorCompactRow(monitor: monitor)
                        if monitor.id != monitors.last?.id {
                            Divider()
                        }
                    }
                    if monitoring.errorMessage != nil {
                        Text("monitor.unavailable").font(.caption).foregroundStyle(.orange)
                    } else if monitors.isEmpty {
                        Text("monitor.empty.description").font(.caption).foregroundStyle(.secondary)
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("monitor.title").font(.headline)
                        Text("monitor.count \(monitors.count)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("network-monitors")
    }
}

private struct NetworkMonitorCompactRow: View {
    let monitor: NetworkMonitorRecord
    @Environment(\.locale) private var locale

    var body: some View {
        let status = NetworkMonitorStatus(monitor: monitor)
        HStack(spacing: 8) {
            Image(systemName: status.symbol)
                .symbolVariant(.fill)
                .foregroundStyle(status.color)
                .font(.subheadline)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: monitor.targetLabel)
                    .font(.caption)
                    .lineLimit(1)
                Text(verbatim: monitor.protocol.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(status.title)
                    .font(.caption2)
                    .foregroundStyle(status.color)
                    .bold(status == .failed)
                if monitor.updatedDate != nil, let response = monitor.res, response.isFinite, response > 0 {
                    Text((response / 1000).formatted(.number.locale(locale).precision(.fractionLength(0...2))) + " ms")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private enum NetworkMonitorStatus {
    case active, paused, pending, stale, failed

    init(monitor: NetworkMonitorRecord) {
        if !monitor.enabled { self = .paused }
        else if monitor.updatedDate == nil { self = .pending }
        else if monitor.isStale(at: .now) { self = .stale }
        else if monitor.res == 0 && (monitor.loss1h ?? 0) > 0 { self = .failed }
        else { self = .active }
    }

    var title: LocalizedStringResource {
        switch self {
        case .active: "monitor.active"
        case .paused: "monitor.paused"
        case .pending: "monitor.pending"
        case .stale: "monitor.stale"
        case .failed: "monitor.failed"
        }
    }

    var symbol: String {
        switch self {
        case .active: "checkmark.circle"
        case .paused: "pause.circle"
        case .pending: "clock"
        case .stale: "clock.badge.exclamationmark"
        case .failed: "exclamationmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .active: .green
        case .paused, .pending: .secondary
        case .stale: .orange
        case .failed: .red
        }
    }
}

struct NetworkMonitorsView: View {
    let system: SystemRecord
    let monitoring: NetworkMonitorStore
    @Environment(SettingsManager.self) private var settings
    @State private var editor: MonitorEditorRoute?
    @State private var search = ""

    private var monitors: [NetworkMonitorRecord] {
        monitoring.monitors(for: system.id).filter {
            search.isEmpty || $0.targetLabel.localizedStandardContains(search) || $0.protocol.localizedStandardContains(search)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let error = monitoring.errorMessage {
                    Text(error).foregroundStyle(.orange)
                    Button("common.retry") { Task { await monitoring.refresh(range: settings.selectedTimeRange) } }
                }
                if monitors.isEmpty {
                    ContentUnavailableView("monitor.empty", systemImage: "network", description: Text("monitor.empty.description"))
                }
                ForEach(monitors) { monitor in
                    NavigationLink {
                        NetworkMonitorDetailView(monitorID: monitor.id, system: system, monitoring: monitoring)
                    } label: {
                        GroupBox { NetworkMonitorSummary(monitor: monitor) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("monitor-\(monitor.id)")
                }
            }.padding()
        }
        .navigationTitle("monitor.title")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search)
        .monitoringScreenBackground()
        .groupBoxStyle(CardGroupBoxStyle())
        .refreshable { await monitoring.refresh(range: settings.selectedTimeRange) }
        .toolbar {
            if monitoring.canManage && HubInfo(v: system.info?.v).supports020 {
                Button("monitor.add", systemImage: "plus") { editor = MonitorEditorRoute(monitor: nil) }
                    .accessibilityIdentifier("add-network-monitor")
            }
        }
        .sheet(item: $editor) { route in
            NetworkMonitorEditor(systemID: system.id, monitor: route.monitor, monitoring: monitoring)
        }
    }
}

private struct MonitorEditorRoute: Identifiable {
    let id = UUID()
    let monitor: NetworkMonitorRecord?
}

struct NetworkMonitorSummary: View {
    let monitor: NetworkMonitorRecord
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: monitor.targetLabel).font(.headline).textSelection(.enabled)
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(verbatim: monitor.protocol.uppercased()).fixedSize()
                    Spacer()
                    status.fixedSize()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: monitor.protocol.uppercased())
                    status
                }
            }.font(.caption.weight(.semibold))
            if monitor.updatedDate != nil {
                NetworkMonitorReading(title: "monitor.response", value: milliseconds(monitor.res))
                NetworkMonitorReading(title: "monitor.average1h", value: milliseconds(monitor.resAvg1h))
                NetworkMonitorReading(title: "monitor.loss1h", value: monitor.loss1h.map { MetricFormatter.percent($0, locale: locale) } ?? "—")
            }
            if let updated = monitor.updatedDate {
                NetworkMonitorReading(title: "monitor.updated", value: updated.formatted(.dateTime.locale(locale).day().month().hour().minute()))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var status: some View {
        let status = NetworkMonitorStatus(monitor: monitor)
        return Label { Text(status.title) } icon: { Image(systemName: status.symbol) }
            .foregroundStyle(status.color)
    }

    private func milliseconds(_ value: Double?) -> String {
        guard let value, value.isFinite, value > 0 else { return "—" }
        return (value / 1000).formatted(.number.locale(locale).precision(.fractionLength(0...2))) + " ms"
    }
}

private struct NetworkMonitorReading: View {
    let title: LocalizedStringResource
    let value: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(value).foregroundStyle(.secondary).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        } else {
            LabeledContent { Text(value).monospacedDigit() } label: { Text(title) }
        }
    }
}

struct NetworkMonitorDetailView: View {
    let monitorID: String
    let system: SystemRecord
    let monitoring: NetworkMonitorStore
    @Environment(SettingsManager.self) private var settings
    @Environment(InstanceManager.self) private var instances
    @Environment(DashboardManager.self) private var dashboard
    @Environment(\.dismiss) private var dismiss
    @State private var editor: MonitorEditorRoute?
    @State private var confirmDelete = false
    @State private var busy = false
    @State private var actionError: String?

    private var monitor: NetworkMonitorRecord? { monitoring.monitors.first { $0.id == monitorID && $0.system == system.id } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let monitor {
                    GroupBox { NetworkMonitorSummary(monitor: monitor) }
                    if let error = monitoring.historyError ?? monitoring.errorMessage { Text(error).foregroundStyle(.orange) }
                    if let history = monitoring.charts[monitorID] {
                        chart(history, metric: .latency)
                        chart(history, metric: .loss)
                    }
                    LabeledContent("monitor.interval", value: "\(monitor.interval) s").font(.caption)
                } else {
                    ContentUnavailableView("monitor.removed", systemImage: "network")
                }
            }
            .padding()
            .environment(\.chartXDomain, settings.selectedTimeRange.xDomain)
            .environment(\.chartShowXGridLines, settings.showChartGridLines)
        }
        .navigationTitle("monitor.details")
        .navigationBarTitleDisplayMode(.inline)
        .monitoringScreenBackground()
        .groupBoxStyle(CardGroupBoxStyle())
        .refreshable { await monitoring.refresh(range: settings.selectedTimeRange) }
        .onChange(of: settings.selectedTimeRange) {
            Task { await monitoring.refresh(range: settings.selectedTimeRange) }
        }
        .toolbar {
            if let monitor, monitoring.canManage {
                Menu {
                    Button("common.edit", systemImage: "pencil") { editor = MonitorEditorRoute(monitor: monitor) }
                    Button(monitor.enabled ? "monitor.pause" : "monitor.resume", systemImage: monitor.enabled ? "pause" : "play") {
                        perform { try await monitoring.setEnabled(monitor, range: settings.selectedTimeRange) }
                    }
                    Button("common.delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: { Image(systemName: "ellipsis") }
                    .disabled(busy)
                    .accessibilityLabel("monitor.actions")
            }
        }
        .sheet(item: $editor) { route in
            NetworkMonitorEditor(systemID: system.id, monitor: route.monitor, monitoring: monitoring)
        }
        .confirmationDialog("monitor.delete.confirm", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("common.delete", role: .destructive) {
                if let monitor {
                    perform {
                        try await monitoring.delete(monitor, range: settings.selectedTimeRange)
                        dismiss()
                    }
                }
            }
        } message: { Text("monitor.delete.description") }
        .alert("common.error", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: { Text(actionError ?? "") }
    }

    private func chart(_ history: NetworkMonitorChartData, metric: NetworkMonitorMetric) -> some View {
        let item = metric.pinnedItem(id: monitorID)
        let instanceID = instances.activeInstance?.id.uuidString ?? ""
        return NetworkMonitorChartView(
            history: history, metric: metric, xAxisFormat: settings.selectedTimeRange.xAxisFormat,
            isPinned: dashboard.isPinned(item, onSystem: system.id, inInstance: instanceID),
            onPinToggle: { dashboard.togglePin(for: item, onSystem: system.id, inInstance: instanceID) }
        )
    }

    private func perform(_ action: @escaping @MainActor () async throws -> Void) {
        busy = true
        Task {
            defer { busy = false }
            do { try await action() } catch { actionError = error.localizedDescription }
        }
    }
}
