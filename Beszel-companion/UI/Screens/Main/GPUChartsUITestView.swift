#if DEBUG
import SwiftUI

/// Synthetic GPU history only; never contacts a hub or persists pin/settings changes.
/// The fixture is decoded from JSON shaped exactly like the agent's `g` payload so the
/// `mt` / `pp` / `e` field mapping is exercised, not just the chart views.
struct GPUChartsUITestView: View {
    @State private var pinned: Set<PinnedItem> = []

    private static let end = Date(timeIntervalSince1970: 1_788_480_000)

    enum Fixture {
        case both, discreteOnly, integratedOnly

        /// Real-world shapes: a Windows box with an RTX 3090 and a Linux box with an Intel iGPU.
        static var fromArguments: Fixture {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--single-gpu") { return .discreteOnly }
            if arguments.contains("--intel-gpu") { return .integratedOnly }
            return .both
        }
    }

    private static func points(fixture: Fixture) -> [SystemDataPoint] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (0..<30).map { index -> SystemStatsRecord in
            let wave = (sin(Double(index) / 4) + 1) / 2
            let discrete = """
            "0":{"n":"GeForce RTX 3090","mu":\(1_004.88 + wave * 6_000),"mt":24000,"u":\(2.4 + wave * 60),"p":\(45 + wave * 180),"pp":0}
            """
            let integrated = """
            "i0":{"n":"GPU","u":\(6.52 + wave * 30),"p":\(0.05 + wave * 4),"e":{"Blitter":0,"Render/3D":\(0.68 + wave * 25),"Video":\(6.52 + wave * 30),"VideoEnhance":0},"pp":\(4.09 + wave * 8)}
            """
            let gpus: String
            switch fixture {
            case .both: gpus = "\(discrete),\(integrated)"
            case .discreteOnly: gpus = discrete
            case .integratedOnly: gpus = integrated
            }
            let created = end.addingTimeInterval(Double(index - 29) * 120)
            let json = """
            {"id":"gpu-\(index)","created":"\(created.ISO8601Format())","type":"1m","stats":{"cpu":12,"mu":4,"mp":25,"du":50,"dp":10,"g":{\(gpus)}}}
            """
            do {
                return try decoder.decode(SystemStatsRecord.self, from: Data(json.utf8))
            } catch {
                preconditionFailure("GPU fixture failed to decode: \(error)")
            }
        }.asDataPoints()
    }

    var body: some View {
        let arguments = ProcessInfo.processInfo.arguments
        let points = Self.points(fixture: .fromArguments)
        let memoryNames = Set(points.flatMap { $0.gpuMetrics.filter { ($0.memoryTotal ?? 0) > 0 }.map(\.name) }).sorted()
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SystemGPUChartView(
                        dataPoints: points, xAxisFormat: .dateTime.hour().minute(),
                        isPinned: pinned.contains(.systemGPU), onPinToggle: { toggle(.systemGPU) }
                    )
                    SystemGPUPowerChartView(
                        dataPoints: points, xAxisFormat: .dateTime.hour().minute(),
                        isPinned: pinned.contains(.systemGPUPower), onPinToggle: { toggle(.systemGPUPower) }
                    )
                    if points.contains(where: { $0.gpuMetrics.contains { !$0.engines.isEmpty } }) {
                        SystemGPUEnginesChartView(
                            dataPoints: points, xAxisFormat: .dateTime.hour().minute(),
                            isPinned: pinned.contains(.systemGPUEngines), onPinToggle: { toggle(.systemGPUEngines) }
                        )
                    }
                    ForEach(memoryNames, id: \.self) { name in
                        SystemGPUMemoryChartView(
                            gpuName: name, dataPoints: points, xAxisFormat: .dateTime.hour().minute(),
                            isPinned: pinned.contains(.gpuMemory(name: name)), onPinToggle: { toggle(.gpuMemory(name: name)) }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("GPU charts")
            .monitoringScreenBackground()
            .groupBoxStyle(CardGroupBoxStyle())
            .environment(\.chartXDomain, Self.end.addingTimeInterval(-3_600)...Self.end)
        }
        .dynamicTypeSize(arguments.contains("--large-text") ? .accessibility3 : .large)
    }

    private func toggle(_ item: PinnedItem) {
        if pinned.contains(item) { pinned.remove(item) } else { pinned.insert(item) }
    }
}
#endif
