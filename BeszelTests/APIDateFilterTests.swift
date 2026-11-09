import Foundation
import Testing
@testable import Beszel

@Suite(.serialized)
@MainActor
struct APIDateFilterTests {
    @Test(arguments: TimeRangeOption.allCases)
    func rangeFiltersUseFixedUTCDates(range: TimeRangeOption) throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-06T19:19:25Z"))
        let expected: [TimeRangeOption: String] = [
            .lastHour: "created >= '2026-10-06 18:18:25' && type = '1m'",
            .last12Hours: "created >= '2026-10-06 07:09:25' && type = '10m'",
            .last24Hours: "created >= '2026-10-05 18:59:25' && type = '20m'",
            .last7Days: "created >= '2026-09-29 17:19:25' && type = '120m'",
            .last30Days: "created >= '2026-09-06 11:19:25' && type = '480m'",
        ]
        #expect(range.apiFilterString(relativeTo: now) == expected[range])
    }

    @Test(arguments: [
        ("2026-10-06T00:00:00Z", "2026-10-05 22:59:00"),
        ("2026-10-06T12:00:00Z", "2026-10-06 10:59:00"),
        ("2027-01-01T00:00:00Z", "2026-12-31 22:59:00"),
        ("2024-03-01T00:00:00Z", "2024-02-29 22:59:00"),
    ])
    func hourFiltersHandleDateBoundaries(sample: (String, String)) throws {
        let now = try #require(ISO8601DateFormatter().date(from: sample.0))
        #expect(TimeRangeOption.lastHour.apiFilterString(relativeTo: now) == "created >= '\(sample.1)' && type = '1m'")
    }

    @Test func currentFiltersUseASCII24HourDates() {
        let pattern = #"^created >= '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' && type = '[0-9]+m'$"#
        for range in TimeRangeOption.allCases {
            #expect(range.apiFilterString.range(of: pattern, options: .regularExpression) != nil)
        }
    }

    @Test func alertRequestUsesFixedUTCDate() async throws {
        let instance = Instance(id: UUID(), name: "Test", url: "https://hub.invalid", email: "test@example.invalid")
        let recorder = DateFilterRequestRecorder()
        let api = BeszelAPIService(instance: instance, instanceManager: InstanceManager(), testToken: "test") { request in
            await recorder.send(request)
        }
        let date = try #require(ISO8601DateFormatter().date(from: "2026-10-06T19:19:25Z"))
        _ = try await api.fetchAlertHistorySince(date: date)
        let request = try #require(await recorder.request)
        let url = try #require(request.url)
        #expect(url.path == "/api/collections/alerts_history/records")
        let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(query.first { $0.name == "filter" }?.value == "created >= '2026-10-06 19:19:25.000Z'")
    }
}

private actor DateFilterRequestRecorder {
    private(set) var request: URLRequest?

    func send(_ request: URLRequest) -> (Data, URLResponse) {
        self.request = request
        let body = Data(#"{"page":1,"perPage":100,"totalPages":1,"totalItems":0,"items":[]}"#.utf8)
        return (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}
