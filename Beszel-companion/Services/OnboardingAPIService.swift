import Foundation

class OnboardingAPIService {
    enum OnboardingError: Error, LocalizedError {
        case invalidURL
        case networkError(Error)
        case decodingError(Error)
        case hubUnreachable

        var errorDescription: String? {
            switch self {
            case .hubUnreachable:
                return "Impossible de joindre le hub. Vérifiez l'URL et votre connexion."
            default:
                return "Une erreur est survenue."
            }
        }
    }

    func fetchAuthMethods(from urlString: String) async throws -> AuthMethodsResponse {
        guard let hubURL = URL(string: urlString) else {
            throw OnboardingError.invalidURL
        }
        
        let requestURL = hubURL.appendingPathComponent("/api/collections/users/auth-methods")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: requestURL)
            let decodedMethods = try JSONDecoder().decode(AuthMethodsResponse.self, from: data)
            return decodedMethods
        } catch let error as URLError {
            throw OnboardingError.networkError(error)
        } catch {
            throw OnboardingError.hubUnreachable
        }
    }

    private struct SSOUserRecord: Decodable {
        let email: String
    }
    
    func exchangeCodeForToken(code: String, provider: OAuth2Provider, hubURL: String) async throws -> (token: String, email: String) {
        guard let tokenURL = URL(string: "\(hubURL)/api/collections/users/auth-with-oauth2") else {
            throw OnboardingError.invalidURL
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct TokenRequestBody: Encodable {
            let provider: String, code: String, codeVerifier: String, redirectUrl: String
        }
        
        let body = TokenRequestBody(provider: provider.name, code: code, codeVerifier: provider.codeVerifier, redirectUrl: "beszel-companion://redirect")
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OnboardingError.hubUnreachable
        }
        
        struct TokenResponseBody: Decodable {
            let token: String
            let record: SSOUserRecord
        }
        
        let responseBody = try JSONDecoder().decode(TokenResponseBody.self, from: data)
        return (responseBody.token, responseBody.record.email)
    }
}
