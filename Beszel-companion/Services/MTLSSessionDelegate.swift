import Foundation
import Security

/// URLSessionDelegate that handles mutual TLS (mTLS) client certificate challenges.
///
/// Used by both `BeszelAPIService` (loads the identity from the keychain by instance ID)
/// and `OnboardingAPIService` (uses a temporary in-memory identity during onboarding).
final class MTLSSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let instanceId: UUID?
    private let temporaryIdentity: SecIdentity?

    /// Create a delegate that loads the client identity from the keychain at challenge time.
    init(instanceId: UUID) {
        self.instanceId = instanceId
        self.temporaryIdentity = nil
    }

    /// Create a delegate that uses a pre-imported identity (for onboarding, before the instance is saved).
    init(temporaryIdentity: SecIdentity) {
        self.instanceId = nil
        self.temporaryIdentity = temporaryIdentity
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let identity: SecIdentity?
        if let temp = temporaryIdentity {
            identity = temp
        } else if let id = instanceId {
            identity = ClientCertificateManager.loadIdentity(for: id)
        } else {
            identity = nil
        }

        if let identity {
            let credential = URLCredential(identity: identity, certificates: nil, persistence: .forSession)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
