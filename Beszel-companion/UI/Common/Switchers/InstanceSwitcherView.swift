import SwiftUI

struct InstanceSwitcherView: View {
    let instanceManager: InstanceManager

    var body: some View {
        @Bindable var manager = instanceManager
        
        Menu {
            Picker("switcher.instances.title", selection: $manager.activeInstanceID) {
                ForEach(manager.instances) { instance in
                    Text(instance.name)
                        .tag(instance.id.uuidString as String?)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Text(instanceManager.activeInstance?.name ?? "...")
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
