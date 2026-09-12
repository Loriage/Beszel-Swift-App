#if DEBUG
import SwiftUI

/// Recorded GPU history only; never contacts a hub or persists pin/settings changes.
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

    /// Sixty consecutive 1-minute samples recorded from a hub: a Windows box whose RTX 3090
    /// loads a ~22 GB model partway through, and a Linux box whose Intel iGPU idles on video decode.
    private enum Recorded {
        static let discreteUsage: [Double] = [4, 4.8, 4.53, 3.87, 4.13, 3.87, 9.6, 4.6, 3.93, 2.13, 4.14, 6.07, 0.4, 5.47, 0.27, 3.73, 0.27, 0.27, 0, 0, 2.87, 0.27, 2.33, 0.4, 4.13, 0, 1.27, 2.27, 2.53, 2.4, 2.47, 2.53, 2.27, 2.4, 2.4, 2.07, 2.53, 2.4, 2.4, 2.27, 2.33, 2.53, 2.29, 2.4, 2.33, 1.93, 2.67, 0.13, 0.13, 0.47, 0.2, 0.27, 0.2, 0.27, 0.33, 0.27, 0.73, 0, 10.6, 0.27]
        static let discretePower: [Double] = [46.05, 46.03, 45.96, 45.86, 45.89, 45.85, 58.11, 69.58, 53.41, 48.74, 71.3, 72.1, 53.03, 64.68, 82.46, 68.14, 45.41, 50.15, 37.95, 37.81, 44.99, 45.37, 47.33, 45.41, 58.83, 38.74, 51.71, 45.45, 45.55, 45.41, 45.37, 45.46, 45.39, 45.38, 45.53, 45.33, 45.36, 45.43, 45.59, 45.36, 45.3, 45.39, 45.38, 45.42, 45.43, 45.49, 43.61, 40.66, 40.48, 40.4, 40.55, 40.53, 40.45, 40.44, 40.4, 40.28, 40.36, 45.53, 82.71, 44.95]
        static let discreteMemoryUsed: [Double] = [1583.01, 1583.01, 1583.01, 1583.01, 1583.01, 1583.01, 1608.4, 1656.25, 1247.07, 1226.56, 21915, 23379.9, 23379.9, 20733.4, 23399.4, 23420.9, 23420.9, 23420.9, 23420.9, 23420.9, 23420.9, 23420.9, 23364.3, 23364.3, 23400.4, 23400.4, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23445.3, 23446.3, 20834, 20834]
        static let integratedUsage: [Double] = [6.5, 6.47, 6.47, 6.54, 6.57, 6.67, 6.56, 6.52, 6.56, 6.58, 6.59, 6.53, 6.55, 6.51, 6.55, 6.57, 6.52, 6.57, 6.52, 6.42, 6.57, 6.52, 6.53, 6.57, 6.54, 6.6, 6.61, 6.56, 6.53, 6.57, 6.58, 6.6, 6.53, 6.48, 6.48, 6.5, 6.52, 6.55, 6.49, 6.57, 6.5, 6.6, 6.59, 6.61, 6.55, 6.51, 6.53, 6.56, 6.52, 6.54, 6.56, 6.52, 6.55, 6.48, 6.45, 6.54, 6.5, 6.51, 6.52, 6.49]
        static let integratedPower: [Double] = [0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.06, 0.06, 0.05, 0.05, 0.05, 0.06, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05]
        static let integratedPackagePower: [Double] = [4.36, 4.14, 4.2, 4.51, 4.73, 5.24, 4.88, 4.01, 4.23, 3.99, 4.61, 4.23, 4.16, 4.04, 4.39, 4.59, 3.99, 4.06, 4.19, 5.49, 4.25, 3.82, 3.89, 4.12, 3.99, 4.71, 4.58, 4.22, 3.99, 4.58, 4.53, 4.31, 3.85, 3.89, 3.99, 4.21, 4.07, 4.21, 3.76, 4.25, 4.21, 4.41, 5.31, 5.58, 3.84, 4.32, 3.95, 3.85, 3.75, 3.89, 4.18, 3.75, 3.94, 3.97, 3.75, 3.9, 3.74, 3.85, 3.79, 3.66]
        static let integratedRender: [Double] = [0.69, 0.69, 0.69, 0.69, 0.7, 0.72, 0.7, 0.7, 0.69, 0.68, 0.69, 0.69, 0.69, 0.68, 0.82, 0.78, 0.69, 0.68, 0.69, 0.71, 0.69, 0.7, 0.68, 0.69, 0.68, 0.73, 0.69, 0.69, 0.68, 0.69, 0.7, 0.69, 0.69, 0.68, 0.68, 0.69, 0.69, 0.69, 0.68, 0.69, 0.68, 0.69, 0.71, 0.79, 0.68, 0.69, 0.69, 0.69, 0.68, 0.69, 0.69, 0.68, 0.69, 0.68, 0.68, 0.69, 0.68, 0.68, 0.68, 0.68]
        static let integratedVideo: [Double] = [6.5, 6.47, 6.47, 6.54, 6.57, 6.67, 6.56, 6.52, 6.56, 6.58, 6.59, 6.53, 6.55, 6.51, 6.55, 6.57, 6.52, 6.57, 6.52, 6.42, 6.57, 6.52, 6.53, 6.57, 6.54, 6.6, 6.61, 6.56, 6.53, 6.57, 6.58, 6.6, 6.53, 6.48, 6.48, 6.5, 6.52, 6.55, 6.49, 6.57, 6.5, 6.6, 6.59, 6.61, 6.55, 6.51, 6.53, 6.56, 6.52, 6.54, 6.56, 6.52, 6.55, 6.48, 6.45, 6.54, 6.5, 6.51, 6.52, 6.49]
    }

    private static func points(fixture: Fixture) -> [SystemDataPoint] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let count = Recorded.discreteUsage.count
        return (0..<count).map { index -> SystemStatsRecord in
            let discrete = """
            "0":{"n":"GeForce RTX 3090","mu":\(Recorded.discreteMemoryUsed[index]),"mt":24000,"u":\(Recorded.discreteUsage[index]),"p":\(Recorded.discretePower[index]),"pp":0}
            """
            let integrated = """
            "i0":{"n":"GPU","u":\(Recorded.integratedUsage[index]),"p":\(Recorded.integratedPower[index]),"e":{"Blitter":0,"Render/3D":\(Recorded.integratedRender[index]),"Video":\(Recorded.integratedVideo[index]),"VideoEnhance":0},"pp":\(Recorded.integratedPackagePower[index])}
            """
            let gpus: String
            switch fixture {
            case .both: gpus = "\(discrete),\(integrated)"
            case .discreteOnly: gpus = discrete
            case .integratedOnly: gpus = integrated
            }
            let created = end.addingTimeInterval(Double(index - (count - 1)) * 60)
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
