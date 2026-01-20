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

    private var containerRecord: ContainerRecord? {
        store.containerRecords.first { $0.name == container.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

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

    @ViewBuilder
    private var infoTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let record = containerRecord {
                    ContainerInfoHeader(container: record, systemName: instanceManager.activeSystem?.name)
                        .padding(.horizontal)
                }

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
                    LogHighlightView(text: formatLogs(logs))
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding()
            }
        }
    }

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
                    JSONHighlightView(text: prettyPrintJSON(info))
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding()
            }
        }
    }

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

struct ContainerInfoHeader: View {
    let container: ContainerRecord
    let systemName: String?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
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

                Label(container.image, systemImage: "shippingbox")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

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

struct JSONHighlightView: UIViewRepresentable {
    let text: String

    private static let keyColor = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0)   // bright green
            : UIColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 1.0)   // dark green
    }
    private static let stringColor = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1.0)   // bright blue
            : UIColor(red: 0.1, green: 0.4, blue: 0.7, alpha: 1.0)   // dark blue
    }
    private static let numberColor = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1.0)   // darker blue
            : UIColor(red: 0.05, green: 0.3, blue: 0.6, alpha: 1.0)  // darker blue
    }

    private static let patterns: [(regex: NSRegularExpression, color: UIColor)] = {
        let defs: [(String, UIColor)] = [
            (#":\s*-?\d+\.?\d*"#, numberColor),  // Numbers
            (#"\b(true|false|null)\b"#, numberColor), // Booleans and null
            (#""[^"]*""#, stringColor),          // ALL strings (includes array items)
            (#""[^"]+"\s*:"#, keyColor),         // Keys (highest priority, overwrites string color)
        ]
        return defs.compactMap { pattern, color in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            return (regex, color)
        }
    }()

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
        textView.attributedText = highlight(text)
    }

    private func highlight(_ text: String) -> NSAttributedString {
        let font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: UIColor.label
        ])

        let range = NSRange(text.startIndex..., in: text)
        for (regex, color) in Self.patterns {
            for match in regex.matches(in: text, options: [], range: range) {
                result.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }

        return result
    }
}

struct LogHighlightView: UIViewRepresentable {
    let text: String

    private static let timestampColor = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0)
            : UIColor(red: 0.1, green: 0.4, blue: 0.7, alpha: 1.0)
    }
    private static let errorColor = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
            : UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1.0)
    }
    private static let warnColor = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.75, blue: 0.3, alpha: 1.0)
            : UIColor(red: 0.8, green: 0.5, blue: 0.0, alpha: 1.0)
    }
    private static let infoColor = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 1.0)
            : UIColor(red: 0.15, green: 0.55, blue: 0.15, alpha: 1.0)
    }
    private static let debugColor = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.8, green: 0.6, blue: 1.0, alpha: 1.0)
            : UIColor(red: 0.5, green: 0.3, blue: 0.7, alpha: 1.0)
    }
    private static let stringColor = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1.0)
            : UIColor(red: 0.1, green: 0.4, blue: 0.7, alpha: 1.0)
    }

    private static let patterns: [(regex: NSRegularExpression, color: UIColor)] = {
        let defs: [(String, UIColor)] = [
            (#"\d{4}[-/]\d{2}[-/]\d{2}[T ]\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:?\d{2})?"#, timestampColor),
            (#"\b(ERROR|FATAL|CRITICAL|ERR)\b"#, errorColor),
            (#"\b(WARN|WARNING|WRN)\b"#, warnColor),
            (#"\b(INFO|INF)\b"#, infoColor),
            (#"\b(DEBUG|DBG|TRACE|TRC)\b"#, debugColor),
            (#"\b[45]\d{2}\b"#, errorColor),
            (#"\b[23]\d{2}\b"#, infoColor),
            (#"https?://[^\s\]\)]+"#, .link),
            (#""[^"]*""#, stringColor),
        ]
        return defs.compactMap { pattern, color in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            return (regex, color)
        }
    }()

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
        textView.attributedText = highlight(text)
    }

    private func highlight(_ text: String) -> NSAttributedString {
        let font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: UIColor.label
        ])

        let range = NSRange(text.startIndex..., in: text)
        for (regex, color) in Self.patterns {
            for match in regex.matches(in: text, options: [], range: range) {
                result.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }

        return result
    }
}
