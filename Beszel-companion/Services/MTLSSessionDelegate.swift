import Foundation
import Security

final class MTLSSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let instanceId: UUID?
    private let temporaryIdentity: SecIdentity?
    
    init(instanceId: UUID) {
        self.instanceId = instanceId
        self.temporaryIdentity = nil
    }
    
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
