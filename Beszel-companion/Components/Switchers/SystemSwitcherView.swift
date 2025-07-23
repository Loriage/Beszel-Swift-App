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
                if let systemName = instanceManager.activeSystem?.name {
                    Text(systemName)
                } else {
                    Text("switcher.loading")
                }
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .font(.headline.weight(.semibold))
            .foregroundColor(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
    }
}
