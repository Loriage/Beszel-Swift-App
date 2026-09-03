import SwiftUI

struct ZFSPoolsCard: View {
    let names: [String]
    let stats: [String: ZFSPoolStats]
    let records: [ZFSPoolRecord]
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    let detailsUnavailable: Bool
    @Environment(\.chartXDomain) private var chartXDomain

    var body: some View {
        GroupBox("zfs.title") {
            VStack(spacing: 12) {
                ForEach(names, id: \.self) { name in
                    NavigationLink {
                        ZFSPoolDetailView(
                            name: name, stats: stats[name], record: records.first { $0.name == name },
                            dataPoints: dataPoints, xAxisFormat: xAxisFormat,
                            detailsUnavailable: detailsUnavailable
                        )
                        .environment(\.chartXDomain, chartXDomain)
                    } label: {
                        ZFSPoolRow(name: name, stats: stats[name])
                    }
                    .buttonStyle(.plain)
                    if name != names.last { Divider() }
                }
            }
        }
    }
}

private struct ZFSPoolRow: View {
    let name: String
    let stats: ZFSPoolStats?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: name).font(.headline)
                if let used = stats?.du, let total = stats?.d {
                    Text("\(StorageValueFormatter.bytes(used * 1_073_741_824)) / \(StorageValueFormatter.bytes(total * 1_073_741_824))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if dynamicTypeSize.isAccessibilitySize {
                    ZFSHealthLabel(health: stats?.h)
                }
            }
            Spacer()
            if !dynamicTypeSize.isAccessibilitySize {
                ZFSHealthLabel(health: stats?.h)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

struct ZFSPoolDetailView: View {
    let name: String
    let stats: ZFSPoolStats?
    let record: ZFSPoolRecord?
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    let detailsUnavailable: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("zfs.health") {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            ZFSHealthLabel(health: stats?.h ?? record?.health)
                            Spacer()
                            if let percent = stats?.percent {
                                Text(MetricFormatter.percent(percent)).monospacedDigit().fixedSize()
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            ZFSHealthLabel(health: stats?.h ?? record?.health)
                            if let percent = stats?.percent {
                                Text(MetricFormatter.percent(percent)).monospacedDigit()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let record {
                        LabeledContent("zfs.allocated", value: StorageValueFormatter.bytes(record.alloc))
                        LabeledContent("zfs.free", value: StorageValueFormatter.bytes(record.free))
                    }
                }

                StorageHistoryChart(metric: .poolUsage(name), dataPoints: dataPoints, xAxisFormat: xAxisFormat)
                StorageHistoryChart(metric: .poolIO(name), dataPoints: dataPoints, xAxisFormat: xAxisFormat)

                if let record {
                    ZFSPoolDetailsContent(record: record)
                } else {
                    Text(detailsUnavailable ? "zfs.details.unavailable" : "zfs.details.pending")
                        .font(.callout).foregroundStyle(.secondary)
                }
                if detailsUnavailable, record != nil {
                    Text("zfs.details.unavailable").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .monitoringScreenBackground()
        .groupBoxStyle(CardGroupBoxStyle())
    }
}

private struct ZFSPoolDetailsContent: View {
    let record: ZFSPoolRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let dateString = record.detailsUpdated,
               let date = DateFormatter.pocketBase.date(from: dateString) {
                LabeledContent("zfs.details.updated") {
                    Text(date, format: .dateTime.month().day().hour().minute())
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            if let scrub = record.scrub {
                GroupBox("zfs.scrub") {
                    LabeledContent("zfs.state", value: scrub.state ?? "—")
                    if let progress = scrub.progress, !progress.isEmpty {
                        LabeledContent("zfs.progress", value: progress)
                    }
                    LabeledContent("zfs.errors", value: (scrub.errors ?? 0).formatted())
                }
            }
            if let vdevs = record.vdevs, !vdevs.isEmpty {
                GroupBox("zfs.devices") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(vdevs) { device in
                            ZFSDeviceRow(device: device)
                            if device.id != vdevs.last?.id { Divider() }
                        }
                    }
                }
            }
            if let datasets = record.datasets, !datasets.isEmpty {
                GroupBox("zfs.datasets") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(datasets) { dataset in
                            ZFSDatasetRow(dataset: dataset)
                            if dataset.id != datasets.last?.id { Divider() }
                        }
                    }
                }
            }
        }
    }
}

private struct ZFSDeviceRow: View {
    let device: ZFSVdev
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: device.name).font(.headline)
            ZFSHealthLabel(health: device.state)
            LabeledContent("zfs.errors.read", value: (device.readErrs ?? 0).formatted())
            LabeledContent("zfs.errors.write", value: (device.writeErrs ?? 0).formatted())
            LabeledContent("zfs.errors.checksum", value: (device.checksumErrs ?? 0).formatted())
        }
        .font(.caption)
    }
}

private struct ZFSDatasetRow: View {
    let dataset: ZFSDataset
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: dataset.name).font(.headline)
            if let mount = dataset.mount, !mount.isEmpty {
                Text(verbatim: mount).foregroundStyle(.secondary)
            }
            LabeledContent("zfs.allocated", value: StorageValueFormatter.bytes(dataset.used))
            LabeledContent("zfs.free", value: StorageValueFormatter.bytes(dataset.avail))
        }
        .font(.caption)
    }
}

struct ZFSHealthLabel: View {
    let health: String?

    private var color: Color {
        switch health {
        case "ONLINE": .green
        case "DEGRADED": .orange
        case "FAULTED", "OFFLINE", "UNAVAIL", "REMOVED", "SUSPENDED": .red
        default: .secondary
        }
    }

    var body: some View {
        Label {
            Text(verbatim: health ?? "—")
        } icon: {
            Image(systemName: health == "ONLINE" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .fixedSize()
    }
}
