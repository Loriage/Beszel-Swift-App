import Foundation

/// Optional connection settings collected during onboarding and applied when an
/// instance is created: a client identity (mTLS), a server CA to trust, and any
/// custom HTTP headers (e.g. Cloudflare Access), plus an optional fallback URL.
struct InstanceAdvancedOptions {
    var clientCert: ClientCertificatePayload?
    var caCert: ServerCACertificatePayload?
    var customHeaders: [String: String]
    var fallbackURL: String?

    init(
        clientCert: ClientCertificatePayload? = nil,
        caCert: ServerCACertificatePayload? = nil,
        customHeaders: [String: String] = [:],
        fallbackURL: String? = nil
    ) {
        self.clientCert = clientCert
        self.caCert = caCert
        self.customHeaders = customHeaders
        self.fallbackURL = fallbackURL
    }
}
