import SwiftUI
import Charts

struct ContainerDetailView: View {
    let container: ProcessedContainerData

    @Environment(SettingsManager.self) var settingsManager
    @Environment(DashboardManager.self) var dashboardManager
    @Environment(BeszelStore.self) var store
    @Environment(InstanceManager.self) var instanceManager

    @State private var logs: String = ""
    @State private var info: String = ""
    @State private var isLoadingLogs = false
    @State private var isLoadingInfo = false
    @State private var logsError: String?
    @State private var infoError: String?
    @State private var selectedTab: DetailTab = .info

    enum DetailTab: String, CaseIterable {
        case info
        case logs
        case details

        var title: LocalizedStringKey {
            switch self {
            case .info: return "container.tab.info"
            case .logs: return "container.tab.logs"
            case .details: return "container.tab.details"
            }
        }

        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .logs: return "doc.text"
            case .details: return "gearshape"
            }
        }
    }

    /// Find the matching ContainerRecord from the store
    private var containerRecord: ContainerRecord? {
        store.containerRecords.first { $0.name == container.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Content based on selected tab
            switch selectedTab {
            case .info:
                infoTabContent
            case .logs:
                logsTabContent
            case .details:
                detailsTabContent
            }
        }
        .navigationTitle(container.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if selectedTab == .logs || selectedTab == .details {
                ToolbarItem(placement: .topBarTrailing) {
                    refreshButton
                }
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .logs && logs.isEmpty && !isLoadingLogs {
                Task { await fetchLogs() }
            } else if newTab == .details && info.isEmpty && !isLoadingInfo {
                Task { await fetchInfo() }
            }
        }
    }

    // MARK: - Info Tab (Header + Charts)

    @ViewBuilder
    private var infoTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Container info header
                if let record = containerRecord {
                    ContainerInfoHeader(container: record, systemName: instanceManager.activeSystem?.name)
                        .padding(.horizontal)
                }

                // Charts
                VStack(spacing: 20) {
                    ContainerMetricChartView(
                        titleKey: "chart.container.cpuUsage.percent",
                        containerName: container.name,
                        xAxisFormat: settingsManager.selectedTimeRange.xAxisFormat,
                        container: container,
                        valueKeyPath: \.cpu,
                        color: .blue,
                        isPinned: dashboardManager.isPinned(.containerCPU(name: container.name)),
                        onPinToggle: { dashboardManager.togglePin(for: .containerCPU(name: container.name)) }
                    )

                    ContainerMetricChartView(
                        titleKey: "chart.container.memoryUsage.bytes",
                        containerName: container.name,
                        xAxisFormat: settingsManager.selectedTimeRange.xAxisFormat,
                        container: container,
                        valueKeyPath: \.memory,
                        color: .green,
                        isPinned: dashboardManager.isPinned(.containerMemory(name: container.name)),
                        onPinToggle: { dashboardManager.togglePin(for: .containerMemory(name: container.name)) }
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Logs Tab

    @ViewBuilder
    private var logsTabContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoadingLogs {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = logsError {
                Spacer()
                ContentUnavailableView {
                    Label("common.error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
                Spacer()
            } else if logs.isEmpty {
                Spacer()
                ContentUnavailableView {
                    Label("container.logs.empty", systemImage: "doc.text")
                } description: {
                    Text("container.logs.empty.description")
                }
                Spacer()
            } else {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    Text(formatLogs(logs))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding()
            }
        }
    }

    // MARK: - Details Tab

    @ViewBuilder
    private var detailsTabContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoadingInfo {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = infoError {
                Spacer()
                ContentUnavailableView {
                    Label("common.error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
                Spacer()
            } else if info.isEmpty {
                Spacer()
                ContentUnavailableView {
                    Label("container.details.empty", systemImage: "info.circle")
                } description: {
                    Text("container.details.empty.description")
                }
                Spacer()
            } else {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    JSONSyntaxView(jsonString: info)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding()
            }
        }
    }

    // MARK: - Toolbar Refresh Button

    private var refreshButton: some View {
        Button {
            Task {
                if selectedTab == .logs {
                    await fetchLogs()
                } else if selectedTab == .details {
                    await fetchInfo()
                }
            }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(selectedTab == .logs ? isLoadingLogs : isLoadingInfo)
    }

    // MARK: - Helpers

    private func formatLogs(_ rawLogs: String) -> String {
        if let data = rawLogs.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let logsContent = json["logs"] as? String {
            return logsContent
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\t", with: "\t")
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\/", with: "/")
        }

        if let data = rawLogs.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }

        return rawLogs
    }

    // MARK: - Data Fetching

    private func fetchLogs() async {
        guard let record = containerRecord,
              let instance = instanceManager.activeInstance else { return }

        isLoadingLogs = true
        logsError = nil

        let apiService = BeszelAPIService(instance: instance, instanceManager: instanceManager)

        do {
            logs = try await apiService.fetchContainerLogs(systemID: record.system, containerID: record.id)
        } catch {
            logsError = error.localizedDescription
        }

        isLoadingLogs = false
    }

    private func fetchInfo() async {
        guard let record = containerRecord,
              let instance = instanceManager.activeInstance else { return }

        isLoadingInfo = true
        infoError = nil

        let apiService = BeszelAPIService(instance: instance, instanceManager: instanceManager)

        do {
            info = try await apiService.fetchContainerInfo(systemID: record.system, containerID: record.id)
        } catch {
            infoError = error.localizedDescription
        }

        isLoadingInfo = false
    }
}

// MARK: - Container Info Header

struct ContainerInfoHeader: View {
    let container: ContainerRecord
    let systemName: String?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Row 1: System, Status, ID, Health
                HStack(spacing: 8) {
                    if let systemName = systemName {
                        Text(systemName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(container.status)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(container.id.prefix(12))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.secondary)

                    if container.health != .none {
                        HealthBadge(health: container.health)
                    }
                }

                // Row 2: Image
                Label(container.image, systemImage: "shippingbox")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Row 3: Stats
                HStack(spacing: 16) {
                    Label(String(format: "%.2f%%", container.cpu), systemImage: "cpu")
                    Label(formatMemory(container.memory), systemImage: "memorychip")
                    if container.net > 0 {
                        Label(formatNetwork(container.net), systemImage: "network")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func formatMemory(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }

    private func formatNetwork(_ mbs: Double) -> String {
        if mbs >= 1 {
            return String(format: "%.1f MB/s", mbs)
        }
        let kbs = mbs * 1024
        return String(format: "%.1f KB/s", kbs)
    }
}

// MARK: - JSON Syntax Highlighting View

struct JSONSyntaxView: UIViewRepresentable {
    let jsonString: String
    private let maxHighlightSize = 50_000

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let prettyJSON = prettyPrintJSON(jsonString)

        if prettyJSON.count > maxHighlightSize {
            let font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            textView.attributedText = NSAttributedString(string: prettyJSON, attributes: [.font: font, .foregroundColor: UIColor.label])
        } else {
            textView.attributedText = syntaxHighlight(prettyJSON)
        }
    }

    private func prettyPrintJSON(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return raw
        }

        if let dict = json as? [String: Any], let infoString = dict["info"] as? String {
            if let innerData = infoString.data(using: .utf8),
               let innerJson = try? JSONSerialization.jsonObject(with: innerData),
               let prettyData = try? JSONSerialization.data(withJSONObject: innerJson, options: [.prettyPrinted, .sortedKeys]),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                return prettyString
            }
            return infoString
        }

        if let dict = json as? [String: Any], let infoContent = dict["info"], infoContent is [Any] || infoContent is [String: Any] {
            if let prettyData = try? JSONSerialization.data(withJSONObject: infoContent, options: [.prettyPrinted, .sortedKeys]),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                return prettyString
            }
        }

        guard json is [Any] || json is [String: Any],
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return raw
        }

        return prettyString
    }

    private func syntaxHighlight(_ json: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let defaultAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label]

        for line in json.components(separatedBy: "\n") {
            if result.length > 0 {
                result.append(NSAttributedString(string: "\n", attributes: defaultAttrs))
            }
            result.append(highlightLine(line, font: font))
        }

        return result
    }

    private func highlightLine(_ line: String, font: UIFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var remaining = line[...]
        let defaultAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label]

        while !remaining.isEmpty {
            let whitespaceMatch = remaining.prefix(while: { $0.isWhitespace && $0 != "\n" })
            if !whitespaceMatch.isEmpty {
                result.append(NSAttributedString(string: String(whitespaceMatch), attributes: defaultAttrs))
                remaining = remaining.dropFirst(whitespaceMatch.count)
                continue
            }

            if remaining.first == "\"" {
                if let stringEnd = findStringEnd(in: remaining) {
                    let stringContent = String(remaining[...stringEnd])
                    let afterString = remaining[remaining.index(after: stringEnd)...]
                    let trimmed = afterString.drop(while: { $0.isWhitespace })
                    let color: UIColor = trimmed.first == ":" ? .systemBlue : UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1)
                    result.append(NSAttributedString(string: stringContent, attributes: [.font: font, .foregroundColor: color]))
                    remaining = remaining[remaining.index(after: stringEnd)...]
                    continue
                }
            }

            let numberMatch = remaining.prefix(while: { $0.isNumber || $0 == "." || $0 == "-" || $0 == "e" || $0 == "E" || $0 == "+" })
            if !numberMatch.isEmpty && (numberMatch.first?.isNumber == true || (numberMatch.first == "-" && numberMatch.count > 1)) {
                result.append(NSAttributedString(string: String(numberMatch), attributes: [.font: font, .foregroundColor: UIColor.systemOrange]))
                remaining = remaining.dropFirst(numberMatch.count)
                continue
            }

            if remaining.hasPrefix("true") {
                result.append(NSAttributedString(string: "true", attributes: [.font: font, .foregroundColor: UIColor.systemPurple]))
                remaining = remaining.dropFirst(4)
                continue
            }
            if remaining.hasPrefix("false") {
                result.append(NSAttributedString(string: "false", attributes: [.font: font, .foregroundColor: UIColor.systemPurple]))
                remaining = remaining.dropFirst(5)
                continue
            }
            if remaining.hasPrefix("null") {
                result.append(NSAttributedString(string: "null", attributes: [.font: font, .foregroundColor: UIColor.systemRed]))
                remaining = remaining.dropFirst(4)
                continue
            }

            if let first = remaining.first, "{}[],:".contains(first) {
                result.append(NSAttributedString(string: String(first), attributes: [.font: font, .foregroundColor: UIColor.secondaryLabel]))
                remaining = remaining.dropFirst()
                continue
            }

            if let first = remaining.first {
                result.append(NSAttributedString(string: String(first), attributes: defaultAttrs))
                remaining = remaining.dropFirst()
            }
        }

        return result
    }

    private func findStringEnd(in str: Substring) -> String.Index? {
        guard str.first == "\"" else { return nil }
        var index = str.index(after: str.startIndex)
        while index < str.endIndex {
            let char = str[index]
            if char == "\\" {
                index = str.index(after: index)
                if index < str.endIndex {
                    index = str.index(after: index)
                }
                continue
            }
            if char == "\"" {
                return index
            }
            index = str.index(after: index)
        }
        return nil
    }
}
