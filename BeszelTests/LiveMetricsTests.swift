import Foundation
import Testing
@testable import Beszel

@Suite(.serialized)
@MainActor
struct LiveMetricsTests {
    @Test func quickRefreshIncludesPinnedSystemsWithoutHistory() async throws {
        let fixture = Fixture()
        await fixture.store.refreshLatestStatsOnly()

        #expect(await fixture.hub.requestedSystems == Set(["a", "b"]))
        #expect(fixture.store.systemData(forSystemID: "b").last?.cpu == 20)
        #expect(fixture.store.systemData(forSystemID: "c").isEmpty)
        #expect(fixture.store.systemDataPoints.last?.cpu == 10)
    }

    @Test func changingSystemDuringRefreshKeepsCurrentSelection() async throws {
        let fixture = Fixture()
        await fixture.store.refreshLatestStatsOnly()
        await fixture.hub.prepareDelayedRefresh()

        let refresh = Task { await fixture.store.refreshLatestStatsOnly() }
        await fixture.hub.waitUntilRequestIsSuspended()
        fixture.manager.activeSystemID = "b"
        fixture.store.updateDataForActiveSystem()
        await fixture.hub.resumeRequest()
        await refresh.value

        #expect(fixture.manager.activeSystem?.id == "b")
        #expect(fixture.store.systemDataPoints.last?.cpu == 20)
        #expect(fixture.store.latestSystemStats?.id == "b-2")
        #expect(fixture.store.systemData(forSystemID: "a").last?.cpu == 10)
    }

    @Test func pinnedReadingFitsTheSharedChartDomain() async throws {
        let fixture = Fixture()
        await fixture.store.fetchData()
        await fixture.hub.makePinnedSystemNewer()
        await fixture.store.refreshLatestStatsOnly()
        let pinnedDate = try #require(fixture.store.systemData(forSystemID: "b").last?.date)
        #expect(pinnedDate > fixture.store.systemDataPoints.last!.date)
        #expect(fixture.store.xDomain.contains(pinnedDate))
    }

    @Test func quickRefreshDoesNotAccumulateOrRegressLiveSamples() async throws {
        let fixture = Fixture()
        await fixture.store.refreshLatestStatsOnly()
        let originalDate = try #require(fixture.store.systemDataPoints.last?.date)
        await fixture.hub.setRevision(2)
        await fixture.store.refreshLatestStatsOnly()
        let newerDate = try #require(fixture.store.systemDataPoints.last?.date)
        #expect(newerDate > originalDate)
        #expect(fixture.store.systemDataPoints.count == 1)

        await fixture.hub.setRevision(1)
        await fixture.store.refreshLatestStatsOnly()
        #expect(fixture.store.systemDataPoints.last?.date == newerDate)
    }

    @Test func liveRecordKeepsHistoryAndDoesNotDuplicateItsLastPoint() throws {
        let first = SystemStatsRecord(id: "first", created: Date(timeIntervalSince1970: 100), stats: .sample(), type: "20m")
        let next = SystemStatsRecord(id: "next", created: Date(timeIntervalSince1970: 200), stats: .sample(), type: "1m")
        let history = [first].asDataPoints()
        #expect(BeszelStore.appendingLiveRecord(first, to: history).count == 1)
        let merged = BeszelStore.appendingLiveRecord(next, to: history)
        #expect(merged.map(\.date) == [first.created, next.created])
        #expect(BeszelStore.appendingLiveRecord(nil, to: history).count == 1)
    }

    @Test func diskAxisEndsAtCapacityIncludingSmallDisks() {
        for total in [0.0005, 0.5, 228.4, 917.03, 1843.2] {
            #expect(capacityDomain(total: total).upperBound == total)
            let ticks = capacityTicks(total: total)
            #expect(ticks.count == 4)
            #expect(ticks.first == 0)
            #expect(ticks.last == total)
            #expect(ticks.allSatisfy { capacityDomain(total: total).contains($0) })
        }
        #expect(capacityDomain(total: 0) == 0...1)
        #expect(capacityTicks(total: .infinity).isEmpty)
    }

    private struct Fixture {
        let manager: InstanceManager
        let store: BeszelStore
        let hub: MockHub

        init() {
            let instance = Instance(id: UUID(), name: "Test", url: "https://hub.invalid", email: "test@example.invalid")
            manager = InstanceManager()
            manager.systems = ["a", "b", "c"].map {
                SystemRecord(id: $0, name: $0, status: "up", host: nil, port: nil, info: nil, v: nil, updated: nil)
            }
            manager.activeSystemID = "a"
            manager.refreshActiveSystem()
            let defaults = UserDefaults(suiteName: "LiveMetricsTests.\(instance.id)")!
            let dashboard = DashboardManager(userDefaults: defaults)
            dashboard.allPins = ["\(instance.id.uuidString)-b": [.systemCPU]]
            hub = MockHub()
            let hub = hub
            let api = BeszelAPIService(instance: instance, instanceManager: manager, testToken: "test") { request in
                try await hub.send(request)
            }
            store = BeszelStore(instance: instance, settingsManager: SettingsManager(), dashboardManager: dashboard, instanceManager: manager, apiService: api)
        }
    }
}

private actor MockHub {
    private(set) var requestedSystems: Set<String> = []
    private var revision = 1
    private var delayA = false
    private var pinnedSystemIsNewer = false
    private var suspendedRequest: CheckedContinuation<Void, Never>?
    private var requestObserver: CheckedContinuation<Void, Never>?

    func setRevision(_ value: Int) { revision = value }
    func makePinnedSystemNewer() { pinnedSystemIsNewer = true }
    func prepareDelayedRefresh() { revision = 2; delayA = true }
    func waitUntilRequestIsSuspended() async {
        if suspendedRequest != nil { return }
        await withCheckedContinuation { requestObserver = $0 }
    }
    func resumeRequest() {
        suspendedRequest?.resume()
        suspendedRequest = nil
    }

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let url = request.url!
        var items: [[String: Any]] = []
        if url.path.contains("/systems/") {
            items = ["a", "b", "c"].map { ["id": $0, "name": $0, "status": "up"] }
        } else if url.path.contains("/system_stats/") {
            let filter = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "filter" }?.value ?? ""
            let systemID = filter.contains("'b'") ? "b" : "a"
            requestedSystems.insert(systemID)
            if systemID == "a", delayA {
                delayA = false
                await withCheckedContinuation { continuation in
                    suspendedRequest = continuation
                    requestObserver?.resume()
                    requestObserver = nil
                }
            }
            let minute = revision + (systemID == "b" && pinnedSystemIsNewer ? 1 : 0)
            items = [[
                "id": "\(systemID)-\(revision)", "created": "2026-11-09 10:0\(minute):00.000Z", "type": "1m",
                "stats": ["cpu": systemID == "a" ? 10 : 20, "mu": 1, "mp": 20, "du": 0.25, "dp": 50, "d": 0.5]
            ]]
            if filter.contains("type =") {
                items[0]["created"] = "2026-11-09 09:00:00.000Z"
                var second = items[0]
                second["created"] = "2026-11-09 09:20:00.000Z"
                second["id"] = "\(systemID)-history"
                items.append(second)
            }
        }
        let body: [String: Any] = ["page": 1, "perPage": 100, "totalPages": 1, "totalItems": items.count, "items": items]
        return (try JSONSerialization.data(withJSONObject: body), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}
