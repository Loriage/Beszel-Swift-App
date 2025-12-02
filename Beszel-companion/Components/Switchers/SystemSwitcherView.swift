import SwiftUI

struct SystemSwitcherView: View {
    let instanceManager: InstanceManager

    var body: some View {
        @Bindable var manager = instanceManager
        
        Menu {
            Section(header: Text(manager.activeInstance?.name ?? String(localized: "switcher.instance.header"))) {
                Picker("Systèmes", selection: $manager.activeSystemID) {
                    ForEach(manager.systems) { system in
                        Text(system.name)
                            .tag(system.id as String?)
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                if let systemName = manager.activeSystem?.name {
                    Text(systemName)
                } else if manager.isLoadingSystems {
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
