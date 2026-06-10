import Foundation
import Security

final class MTLSSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let instanceId: UUID?
    private let temporaryIdentity: SecIdentity?
    private let temporaryCACertificate: SecCertificate?

    init(instanceId: UUID) {
        self.instanceId = instanceId
        self.temporaryIdentity = nil
        self.temporaryCACertificate = nil
    }

    init(temporaryIdentity: SecIdentity? = nil, temporaryCACertificate: SecCertificate? = nil) {
        self.instanceId = nil
        self.temporaryIdentity = temporaryIdentity
        self.temporaryCACertificate = temporaryCACertificate
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            handleServerTrust(challenge, completionHandler: completionHandler)
        case NSURLAuthenticationMethodClientCertificate:
            handleClientCertificate(completionHandler: completionHandler)
        default:
            completionHandler(.performDefaultHandling, nil)
        }
    }

    // MARK: - Server trust (local / private CA)

    private var caCertificate: SecCertificate? {
        if let temp = temporaryCACertificate { return temp }
        if let id = instanceId { return ServerCACertificateManager.loadCertificate(for: id) }
        return nil
    }

    private func handleServerTrust(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let caCert = caCertificate,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            // No custom CA configured: defer to the system's default validation.
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Trust chains anchored at the imported CA, while still accepting the
        // system's built-in anchors so publicly-signed certificates keep working.
        // Hostname validation from the default SSL policy remains in effect.
        SecTrustSetAnchorCertificates(serverTrust, [caCert] as CFArray)
        SecTrustSetAnchorCertificatesOnly(serverTrust, false)

        if SecTrustEvaluateWithError(serverTrust, nil) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    // MARK: - Client certificate (mTLS)

    private var clientIdentity: SecIdentity? {
        if let temp = temporaryIdentity { return temp }
        if let id = instanceId { return ClientCertificateManager.loadIdentity(for: id) }
        return nil
    }

    private func handleClientCertificate(
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if let identity = clientIdentity {
            let credential = URLCredential(identity: identity, certificates: nil, persistence: .forSession)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
