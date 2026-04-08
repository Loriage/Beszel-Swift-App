import SwiftUI

struct SmartHealthView: View {
    let devices: [SmartDeviceRecord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(devices.sorted(by: { $0.name < $1.name })) { device in
                    SmartDeviceCard(device: device)
                }
            }
            .groupBoxStyle(CardGroupBoxStyle())
            .padding()
            .padding(.bottom, 24)
        }
        .navigationTitle(Text("smart.title"))
    }
}

// MARK: - Summary card (used on SystemView)

struct SmartHealthSummaryCard: View {
    let devices: [SmartDeviceRecord]

    private var failedCount: Int {
        devices.filter { $0.isFailed }.count
    }

    var body: some View {
        NavigationLink(destination: SmartHealthView(devices: devices)) {
            GroupBox(label: HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("smart.title")
                        .font(.headline)
                    Text("smart.deviceCount \(devices.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if failedCount > 0 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }) {
                VStack(spacing: 8) {
                    ForEach(devices.sorted(by: { $0.name < $1.name })) { device in
                        HStack(spacing: 8) {
                            Image(systemName: device.isFailed ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundColor(device.isFailed ? .red : (device.isPassed ? .green : .secondary))
                                .font(.subheadline)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(device.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                if let model = device.model, !model.isEmpty {
                                    Text(model)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 1) {
                                if let state = device.state, !state.isEmpty {
                                    Text(state)
                                        .font(.caption2)
                                        .foregroundColor(device.isFailed ? .red : (device.isPassed ? .green : .secondary))
                                        .bold(device.isFailed)
                                }
                                if let temp = device.temp, temp > 0 {
                                    Text("\(temp)°C")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        if device.id != devices.sorted(by: { $0.name < $1.name }).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Full device card (used in SmartHealthView)

private struct SmartDeviceCard: View {
    let device: SmartDeviceRecord
    @State private var showAttributes = false

    var body: some View {
        GroupBox(label: HStack(alignment: .center) {
            Image(systemName: device.isFailed ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(device.isFailed ? .red : (device.isPassed ? .green : .secondary))

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.headline)
                if let model = device.model, !model.isEmpty {
                    Text(model)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let state = device.state, !state.isEmpty {
                Text(state)
                    .font(.caption)
                    .bold()
                    .foregroundColor(device.isFailed ? .red : (device.isPassed ? .green : .secondary))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((device.isFailed ? Color.red : (device.isPassed ? Color.green : Color.secondary)).opacity(0.15))
                    .clipShape(Capsule())
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Info row
                HStack(spacing: 16) {
                    if let cap = device.formattedCapacity {
                        SmartInfoItem(label: "smart.capacity", value: cap)
                    }
                    if let temp = device.temp, temp > 0 {
                        SmartInfoItem(label: "smart.temperature", value: "\(temp)°C")
                    }
                    if let hours = device.hours, hours > 0 {
                        let days = hours / 24
                        SmartInfoItem(label: "smart.powerOn", value: days > 0 ? "\(days)d" : "\(hours)h")
                    }
                    if let cycles = device.cycles, cycles > 0 {
                        SmartInfoItem(label: "smart.cycles", value: "\(cycles)")
                    }
                }

                if let firmware = device.firmware, !firmware.isEmpty {
                    HStack(spacing: 4) {
                        Text("smart.firmware")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(firmware)
                            .font(.caption2)
                    }
                }

                if let serial = device.serial, !serial.isEmpty {
                    HStack(spacing: 4) {
                        Text("smart.serial")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(serial)
                            .font(.caption2)
                    }
                }

                // Attributes
                if let attributes = device.attributes, !attributes.isEmpty {
                    let failing = attributes.filter { $0.isFailing }
                    if !failing.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("smart.failingAttributes")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.red)
                            ForEach(failing) { attr in
                                SmartAttributeRow(attribute: attr, highlight: true)
                            }
                        }
                    }

                    Button {
                        showAttributes.toggle()
                    } label: {
                        HStack {
                            Text(showAttributes ? "smart.hideAttributes" : "smart.showAttributes \(attributes.count)")
                                .font(.caption)
                            Spacer()
                            Image(systemName: showAttributes ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    if showAttributes {
                        VStack(spacing: 0) {
                            ForEach(Array(attributes.sorted(by: { ($0.id ?? 0) < ($1.id ?? 0) }).enumerated()), id: \.element.id) { index, attr in
                                SmartAttributeRow(attribute: attr, highlight: attr.isFailing)
                                if index < attributes.count - 1 {
                                    Divider().padding(.horizontal)
                                }
                            }
                        }
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }
}

private struct SmartInfoItem: View {
    let label: LocalizedStringResource
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .bold()
        }
    }
}

private struct SmartAttributeRow: View {
    let attribute: SmartAttribute
    var highlight: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if let id = attribute.id {
                Text(String(format: "%3d", id))
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
                    .frame(width: 28, alignment: .trailing)
            }

            Text(attribute.name)
                .font(.caption2)
                .lineLimit(1)
                .foregroundColor(highlight ? .red : .primary)

            Spacer()

            if let rs = attribute.rawString, !rs.isEmpty {
                Text(rs)
                    .font(.caption2.monospaced())
                    .foregroundColor(highlight ? .red : .secondary)
            } else if let rv = attribute.rawValue {
                Text("\(rv)")
                    .font(.caption2.monospaced())
                    .foregroundColor(highlight ? .red : .secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}
