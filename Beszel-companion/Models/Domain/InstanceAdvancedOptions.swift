import Foundation
import Security

/// Optional connection settings collected during onboarding and applied when an
/// instance is created: a client identity (mTLS), a server CA to trust, and any
/// custom HTTP headers (e.g. Cloudflare Access), plus an optional fallback URL.
struct InstanceAdvancedOptions {
    var clientCert: ClientCertificatePayload?
    var caCert: ServerCACertificatePayload?
    var customHeaders: [String: String]
    var fallbackURL: String?
    private var storedInstanceID: UUID?

    var clientIdentity: SecIdentity? {
        clientCert?.identity ?? storedInstanceID.flatMap { ClientCertificateManager.loadIdentity(for: $0) }
    }

    var caCertificate: SecCertificate? {
        caCert?.certificate ?? storedInstanceID.flatMap { ServerCACertificateManager.loadCertificate(for: $0) }
    }

    static func stored(for instance: Instance) -> Self {
        var options = Self(customHeaders: CustomHeadersManager.load(for: instance.id), fallbackURL: instance.fallbackURL)
        options.storedInstanceID = instance.id
        return options
    }

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
