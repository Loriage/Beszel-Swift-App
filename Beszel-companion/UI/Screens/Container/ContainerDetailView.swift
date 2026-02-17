import SwiftUI
import Charts

struct ContainerDetailView: View {
    let container: ProcessedContainerData

    @Environment(SettingsManager.self) var settingsManager
    @Environment(DashboardManager.self) var dashboardManager
    @Environment(BeszelStore.self) var store
    @Environment(InstanceManager.self) var instanceManager

    @State private var logsState: ViewState<String> = .empty
    @State private var detailsState: ViewState<String> = .empty
    @State private var selectedTab: DetailTab = .info
    @State private var showFullLogs = false

    enum ViewState<T: Equatable>: Equatable {
        case loading
        case error(String)
        case empty
        case loaded(T)

        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
    }

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
                if selectedTab == .logs, case .loaded(let logs) = logsState, logs.count > LogHighlightView.maxDisplayLength {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showFullLogs.toggle()
                        } label: {
                            Image(systemName: showFullLogs ? "arrow.up.right.and.arrow.down.left" : "arrow.down.left.and.arrow.up.right")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    refreshButton
                }
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .logs, case .empty = logsState {
                Task { await fetchLogs() }
            } else if newTab == .details, case .empty = detailsState {
                Task { await fetchInfo() }
            }
        }
        .onChange(of: logsState) { _, _ in
            showFullLogs = false
        }
    }

    @ViewBuilder
    private var infoTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let record = containerRecord {
                    ContainerInfoHeader(container: record, systemName: instanceManager.activeSystem?.name)
                }
                
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
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    @ViewBuilder
    private var logsTabContent: some View {
        switch logsState {
        case .loading:
            centeredView { ProgressView() }
        case .error(let message):
            centeredView {
                ContentUnavailableView {
                    Label("common.error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                }
            }
        case .empty:
            centeredView {
                ContentUnavailableView {
                    Label("container.logs.empty", systemImage: "doc.text")
                } description: {
                    Text("container.logs.empty.description")
                }
            }
        case .loaded(let logs):
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    LogHighlightView(text: logs, showFull: showFullLogs)
                        .padding()
                        .frame(minHeight: geometry.size.height, alignment: .top)
                }
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding()
        }
    }

    @ViewBuilder
    private var detailsTabContent: some View {
        switch detailsState {
        case .loading:
            centeredView { ProgressView() }
        case .error(let message):
            centeredView {
                ContentUnavailableView {
                    Label("common.error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                }
            }
        case .empty:
            centeredView {
                ContentUnavailableView {
                    Label("container.details.empty", systemImage: "info.circle")
                } description: {
                    Text("container.details.empty.description")
                }
            }
        case .loaded(let info):
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    JSONHighlightView(text: info)
                        .padding()
                        .frame(minHeight: geometry.size.height, alignment: .top)
                }
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding()
        }
    }

    @ViewBuilder
    private func centeredView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            Spacer()
            content()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .disabled(selectedTab == .logs ? logsState.isLoading : detailsState.isLoading)
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
        guard let record = containerRecord else {
            logsState = .error(String(localized: "container.error.notFound"))
            return
        }
        guard let instance = instanceManager.activeInstance else {
            logsState = .error(String(localized: "container.error.noInstance"))
            return
        }

        logsState = .loading

        let apiService = BeszelAPIService(instance: instance, instanceManager: instanceManager)

        do {
            let rawLogs = try await apiService.fetchContainerLogs(systemID: record.system, containerID: record.id)
            let formattedLogs = formatLogs(rawLogs)
            logsState = formattedLogs.isEmpty ? .empty : .loaded(formattedLogs)
        } catch {
            logsState = .error(error.localizedDescription)
        }
    }

    private func fetchInfo() async {
        guard let record = containerRecord else {
            detailsState = .error(String(localized: "container.error.notFound"))
            return
        }
        guard let instance = instanceManager.activeInstance else {
            detailsState = .error(String(localized: "container.error.noInstance"))
            return
        }

        detailsState = .loading

        let apiService = BeszelAPIService(instance: instance, instanceManager: instanceManager)

        do {
            let rawInfo = try await apiService.fetchContainerInfo(systemID: record.system, containerID: record.id)
            let formattedInfo = prettyPrintJSON(rawInfo)
            detailsState = formattedInfo.isEmpty ? .empty : .loaded(formattedInfo)
        } catch {
            detailsState = .error(error.localizedDescription)
        }
    }
}

struct ContainerInfoHeader: View {
    let container: ContainerRecord
    let systemName: String?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(container.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    if let health = container.health, health != .none {
                        HealthBadge(health: health)
                    }
                }

                HStack(spacing: 4) {
                    if let systemName = systemName {
                        Text(systemName)
                        Text("•")
                    }
                    Text(container.status)
                    Text("•")
                    Text(container.id.prefix(12))
                        .monospaced()
                }
                .font(.caption)
                .foregroundColor(.secondary)

                if let image = container.image {
                    Text(image)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct JSONHighlightView: UIViewRepresentable {
    let text: String

    private static let maxDisplayLength = 100_000

    private static let keyColor = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0)
            : UIColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 1.0)
    }
    private static let stringColor = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1.0)
            : UIColor(red: 0.1, green: 0.4, blue: 0.7, alpha: 1.0)
    }
    private static let numberColor = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1.0)
            : UIColor(red: 0.05, green: 0.3, blue: 0.6, alpha: 1.0)
    }

    private static let patterns: [(regex: NSRegularExpression, color: UIColor)] = {
        let defs: [(String, UIColor)] = [
            (#":\s*-?\d+\.?\d*"#, numberColor),
            (#"\b(true|false|null)\b"#, numberColor),
            (#""[^"]*""#, stringColor),
            (#""[^"]+"\s*:"#, keyColor),
        ]
        return defs.compactMap { pattern, color in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            return (regex, color)
        }
    }()

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

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
        let attributed = context.coordinator.attributedString(for: text, highlight: Self.highlight)
        textView.attributedText = attributed
    }

    class Coordinator {
        private var cachedText: String?
        private var cachedAttributedString: NSAttributedString?

        func attributedString(for text: String, highlight: (String) -> NSAttributedString) -> NSAttributedString {
            if let cached = cachedAttributedString, cachedText == text {
                return cached
            }
            let result = highlight(text)
            cachedText = text
            cachedAttributedString = result
            return result
        }
    }

    private static func highlight(_ text: String) -> NSAttributedString {
        let font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        let displayText: String
        if text.count > maxDisplayLength {
            displayText = String(text.prefix(maxDisplayLength)) + "\n\n... [content truncated]"
        } else {
            displayText = text
        }

        let result = NSMutableAttributedString(string: displayText, attributes: [
            .font: font,
            .foregroundColor: UIColor.label
        ])

        let range = NSRange(displayText.startIndex..., in: displayText)
        for (regex, color) in patterns {
            for match in regex.matches(in: displayText, options: [], range: range) {
                result.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }

        return result
    }
}

struct LogHighlightView: UIViewRepresentable {
    let text: String
    var showFull: Bool = false

    static let maxDisplayLength = 20_000

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
            (#"\d{4}[-/]\d{2}[-/]\d{2}[T ]\d{2}:\d{2}:\d{2}([.,]\d+)?(Z|[+-]\d{2}:?\d{2})?"#, timestampColor),
            (#"\b(ERROR|FATAL|CRITICAL|ERR)\b"#, errorColor),
            (#"\b(WARN|WARNING|WRN)\b"#, warnColor),
            (#"\b(INFO|INF)\b"#, infoColor),
            (#"\b(DEBUG|DBG|TRACE|TRC)\b"#, debugColor),
            (#"(?i)(?:HTTP[/ ]|status[: ]+)[45]\d{2}\b"#, errorColor),
            (#"(?i)(?:HTTP[/ ]|status[: ]+)[23]\d{2}\b"#, infoColor),
            (#"https?://[^\s\]\)]+"#, .link),
            (#""[^"]*""#, stringColor),
        ]
        return defs.compactMap { pattern, color in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            return (regex, color)
        }
    }()

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

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
        let attributed = context.coordinator.attributedString(
            for: text,
            showFull: showFull,
            highlight: { Self.highlight($0, showFull: $1) }
        )
        textView.attributedText = attributed
    }

    class Coordinator {
        private var cachedText: String?
        private var cachedShowFull: Bool?
        private var cachedAttributedString: NSAttributedString?

        func attributedString(
            for text: String,
            showFull: Bool,
            highlight: (String, Bool) -> NSAttributedString
        ) -> NSAttributedString {
            if let cached = cachedAttributedString, cachedText == text, cachedShowFull == showFull {
                return cached
            }
            let result = highlight(text, showFull)
            cachedText = text
            cachedShowFull = showFull
            cachedAttributedString = result
            return result
        }
    }

    private static func highlight(_ text: String, showFull: Bool) -> NSAttributedString {
        let font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        let displayText: String
        if showFull || text.count <= maxDisplayLength {
            displayText = text
        } else {
            // Truncate middle at line boundaries (20% start, 80% end for recent logs)
            let targetStartLength = min(maxDisplayLength / 5, text.count)
            let targetEndLength = min(maxDisplayLength - targetStartLength, text.count)

            guard targetStartLength > 0, targetEndLength > 0 else {
                displayText = text
                return NSAttributedString(string: displayText, attributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.label
                ])
            }

            let startSearchIndex = text.index(text.startIndex, offsetBy: targetStartLength, limitedBy: text.endIndex) ?? text.endIndex
            let startCutIndex: String.Index
            if startSearchIndex < text.endIndex, let newlineIndex = text[startSearchIndex...].firstIndex(of: "\n") {
                startCutIndex = newlineIndex
            } else {
                startCutIndex = startSearchIndex
            }

            let endSearchStart = text.index(text.endIndex, offsetBy: -targetEndLength, limitedBy: text.startIndex) ?? text.startIndex
            let endCutIndex: String.Index
            if endSearchStart > text.startIndex, let newlineIndex = text[..<endSearchStart].lastIndex(of: "\n") {
                endCutIndex = text.index(after: newlineIndex)
            } else {
                endCutIndex = endSearchStart
            }

            guard startCutIndex < endCutIndex else {
                displayText = text
                return NSAttributedString(string: displayText, attributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.label
                ])
            }

            let start = String(text[..<startCutIndex])
            let end = String(text[endCutIndex...])
            let hiddenCount = text.count - start.count - end.count
            displayText = start + "\n\n... [\(hiddenCount) characters hidden] ...\n\n" + end
        }

        let result = NSMutableAttributedString(string: displayText, attributes: [
            .font: font,
            .foregroundColor: UIColor.label
        ])

        let range = NSRange(displayText.startIndex..., in: displayText)
        for (regex, color) in patterns {
            for match in regex.matches(in: displayText, options: [], range: range) {
                result.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }

        return result
    }
}
