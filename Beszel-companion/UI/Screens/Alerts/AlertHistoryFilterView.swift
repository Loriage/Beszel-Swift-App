import SwiftUI

enum AlertStateFilter: String, CaseIterable, Identifiable {
    case all = "alerts.filter.all"
    case active = "alerts.status.active"
    case resolved = "alerts.status.resolved"

    var id: String { rawValue }
}

struct AlertHistoryFilterView: View {
    @Environment(InstanceManager.self) var instanceManager
    @Environment(\.dismiss) var dismiss

    @Binding var selectedSystemID: String?
    @Binding var selectedAlertType: AlertType?
    @Binding var selectedState: AlertStateFilter

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("System")) {
                    Picker("System", selection: $selectedSystemID) {
                        Text("All Systems").tag(nil as String?)
                        ForEach(instanceManager.systems, id: \.id) { system in
                            Text(system.name).tag(system.id as String?)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section(header: Text("Type")) {
                    Picker("Type", selection: $selectedAlertType) {
                        Text("All Types").tag(nil as AlertType?)
                        ForEach(AlertType.allCases) { type in
                            Label(type.displayName, systemImage: type.iconName)
                                .foregroundColor(.primary)
                                .tag(type as AlertType?)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section(header: Text("State")) {
                    Picker("State", selection: $selectedState) {
                        ForEach(AlertStateFilter.allCases) { state in
                            Text(LocalizedStringKey(state.rawValue)).tag(state)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
        .tint(.primary)
    }
}
