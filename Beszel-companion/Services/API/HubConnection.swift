import Foundation

nonisolated enum HubURL {
    static func normalized(_ value: String?) -> String? {
        guard var value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        while value.hasSuffix("/") { value.removeLast() }
        return value
    }

    static func baseURL(_ value: String) -> URL? {
        guard let value = normalized(value),
              let url = URL(string: value, encodingInvalidCharacters: false),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.port.map({ (1...65535).contains($0) }) ?? true else { return nil }
        return url
    }

    static func isValidFallback(_ value: String) -> Bool {
        normalized(value) == nil || baseURL(value) != nil
    }
}

/// One hub, two explicitly configured addresses, and the same security-configured
/// session. Only connectivity failures can select the alternate address.
actor HubConnection {
    typealias Send = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let baseURL: String
    private let fallbackURL: String?
    private let retryPrimaryAfter: Duration
    private let send: Send
    private var fallbackUntil: ContinuousClock.Instant?

    init(baseURL: String, fallbackURL: String? = nil, retryPrimaryAfter: Duration = .seconds(60), send: @escaping Send) {
        self.baseURL = baseURL
        self.fallbackURL = HubURL.normalized(fallbackURL)
        self.retryPrimaryAfter = retryPrimaryAfter
        self.send = send
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()
        guard let fallbackURL else { return try await send(request) }
        guard let primary = HubURL.baseURL(baseURL), let fallback = HubURL.baseURL(fallbackURL) else {
            throw URLError(.badURL)
        }
        guard primary != fallback else { return try await send(request) }

        // Validate scope before sending even a probe: never rebase unrelated URLs.
        _ = try rebased(request, from: primary, to: primary)
        let method = (request.httpMethod ?? "GET").uppercased()
        if method == "GET" || method == "HEAD" {
            let (data, response, _) = try await read(request, primary: primary, fallback: fallback)
            return (data, response)
        }

        // A timed-out POST/PATCH may already have succeeded. Select a reachable
        // address with a read-only probe, then send the actual mutation only once.
        let probe = URLRequest(
            url: primary.appendingPathComponent("api/health"),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 4
        )
        let (_, _, endpoint) = try await read(probe, primary: primary, fallback: fallback)
        try Task.checkCancellation()
        do {
            let result = try await send(rebased(request, from: primary, to: endpoint))
            try Task.checkCancellation()
            return result
        } catch {
            if Self.isConnectivityFailure(error) { fallbackUntil = nil }
            throw error
        }
    }

    private func read(_ request: URLRequest, primary: URL, fallback: URL) async throws -> (Data, URLResponse, URL) {
        let prefersFallback = fallbackUntil.map { ContinuousClock.now < $0 } ?? false
        let first = prefersFallback ? fallback : primary
        let second = prefersFallback ? primary : fallback

        do {
            return try await read(request, primary: primary, endpoint: first)
        } catch {
            try Task.checkCancellation()
            guard Self.isConnectivityFailure(error) else { throw error }
            return try await read(request, primary: primary, endpoint: second, rememberFallback: second == fallback)
        }
    }

    private func read(_ request: URLRequest, primary: URL, endpoint: URL, rememberFallback: Bool = false) async throws -> (Data, URLResponse, URL) {
        try Task.checkCancellation()
        var request = try rebased(request, from: primary, to: endpoint)
        // Bound the initial LAN wait. Keep normal timeouts for actual fallback
        // reads; the small health probe has its own four-second timeout.
        if endpoint == primary { request.timeoutInterval = min(request.timeoutInterval, 4) }
        let (data, response) = try await send(request)
        try Task.checkCancellation()
        // HTTP errors still prove connectivity and must be handled by the caller,
        // not hidden by switching hosts (especially authentication failures).
        if endpoint == primary {
            fallbackUntil = nil
        } else if rememberFallback {
            fallbackUntil = ContinuousClock.now.advanced(by: retryPrimaryAfter)
        }
        return (data, response, endpoint)
    }

    private func rebased(_ request: URLRequest, from primary: URL, to endpoint: URL) throws -> URLRequest {
        guard let url = request.url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let primaryComponents = URLComponents(url: primary, resolvingAgainstBaseURL: false),
              let endpointComponents = URLComponents(url: endpoint, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == primaryComponents.scheme?.lowercased(),
              components.host?.lowercased() == primaryComponents.host?.lowercased(),
              components.port == primaryComponents.port,
              components.user == nil, components.password == nil,
              components.percentEncodedPath.hasPrefix(primaryComponents.percentEncodedPath + "/") else {
            throw URLError(.badURL)
        }
        let path = components.percentEncodedPath.dropFirst(primaryComponents.percentEncodedPath.count)
        components.scheme = endpointComponents.scheme
        components.host = endpointComponents.host
        components.port = endpointComponents.port
        components.percentEncodedPath = endpointComponents.percentEncodedPath + String(path)
        guard let rebasedURL = components.url else { throw URLError(.badURL) }
        var result = request
        result.url = rebasedURL
        return result
    }

    private nonisolated static func isConnectivityFailure(_ error: Error) -> Bool {
        guard let error = error as? URLError else { return false }
        switch error.code {
        case .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
             .networkConnectionLost, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }
}
