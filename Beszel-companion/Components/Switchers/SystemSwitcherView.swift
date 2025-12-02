import SwiftUI

struct SystemSwitcherView: View {
    @ObservedObject var instanceManager: InstanceManager

    var body: some View {
        Menu {
            Section(header: Text(instanceManager.activeInstance?.name ?? String(localized: "switcher.instance.header"))) {
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
                } else if instanceManager.isLoadingSystems {
                    Text("switcher.loading")
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Text("No system found")
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
