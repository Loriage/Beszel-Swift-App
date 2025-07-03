import SwiftUI

struct SystemSwitcherView: View {
    @ObservedObject var instanceManager: InstanceManager

    var body: some View {
        Menu {
            Section(header: Text(instanceManager.activeInstance?.name ?? "Instance")) {
                Picker("Systèmes", selection: instanceManager.activeSystemSelection) {
                    ForEach(instanceManager.systems) { system in
                        Text(system.name).tag(system.id as String?)
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Text(instanceManager.activeSystem?.name ?? "Chargement...")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
    }
}
