import SwiftUI

struct NetworkMonitorEditor: View {
    let systemID: String
    let monitor: NetworkMonitorRecord?
    let monitoring: NetworkMonitorStore
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsManager.self) private var settings
    @State private var target = ""
    @State private var kind: NetworkMonitorProtocol = .icmp
    @State private var port = "443"
    @State private var interval = "30"
    @State private var enabled = true
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("monitor.protocol", selection: $kind) {
                        ForEach(NetworkMonitorProtocol.allCases) { Text(verbatim: $0.label).tag($0) }
                    }
                    TextField("monitor.target", text: $target)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.URL).accessibilityIdentifier("monitor-target")
                    if kind == .tcp {
                        TextField("monitor.port", text: $port).keyboardType(.numberPad)
                    }
                    TextField("monitor.interval", text: $interval).keyboardType(.numberPad)
                    Toggle("monitor.enabled", isOn: $enabled)
                } footer: { Text("monitor.editor.description") }
                if monitor != nil {
                    Section { Text("monitor.edit.history").foregroundStyle(.secondary) }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle(monitor == nil ? "monitor.add" : "monitor.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }.disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }.disabled(saving || target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .disabled(saving)
            .interactiveDismissDisabled(saving)
            .onAppear {
                if let monitor {
                    target = monitor.target
                    kind = NetworkMonitorProtocol(rawValue: monitor.protocol) ?? .icmp
                    port = String(monitor.port == 0 ? 443 : monitor.port)
                    interval = String(monitor.interval)
                    enabled = monitor.enabled
                }
            }
        }
    }

    private func save() {
        do {
            let config = try NetworkMonitorConfiguration(system: systemID, target: target, protocol: kind, port: port, interval: interval, enabled: enabled)
            saving = true
            error = nil
            Task {
                defer { saving = false }
                do {
                    try await monitoring.save(config, id: monitor?.id, range: settings.selectedTimeRange)
                    dismiss()
                } catch { self.error = error.localizedDescription }
            }
        } catch { self.error = error.localizedDescription }
    }
}
