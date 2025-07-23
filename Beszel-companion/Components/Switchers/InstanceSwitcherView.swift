import SwiftUI

struct InstanceSwitcherView: View {
    @ObservedObject var instanceManager: InstanceManager

    var body: some View {
        Menu {
            Picker("switcher.instances.title", selection: instanceManager.activeInstanceSelection) {
                ForEach(instanceManager.instances) { instance in
                    Text(instance.name).tag(instance.id.uuidString as String?)
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
