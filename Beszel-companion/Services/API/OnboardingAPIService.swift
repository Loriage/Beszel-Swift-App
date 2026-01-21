import Foundation

struct OnboardingAPIService {
    enum OnboardingError: Error, LocalizedError {
        case invalidURL
        case networkError(Error)
        case decodingError(Error)
        case hubUnreachable
        case authenticationFailed
        case mfaRequired(mfaId: String, otpId: String)
        case oauthMfaRequired(mfaId: String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return String(localized: "onboarding.error.invalidURL")
            case .networkError(let error):
                return String(localized: "onboarding.error.network") + ": \(error.localizedDescription)"
            case .decodingError:
                return String(localized: "onboarding.error.invalidResponse")
            case .hubUnreachable:
                return String(localized: "onboarding.error.hubUnreachable")
            case .authenticationFailed:
                return String(localized: "onboarding.error.authFailed")
            case .mfaRequired, .oauthMfaRequired:
                return String(localized: "onboarding.error.mfaRequired")
            }
        }
    }

    private struct MFAResponse: Decodable {
        let mfaId: String
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
        } catch let error as DecodingError {
            throw OnboardingError.decodingError(error)
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
            let provider: String, code: String, codeVerifier: String, redirectURL: String
        }

        let body = TokenRequestBody(provider: provider.name, code: code, codeVerifier: provider.codeVerifier, redirectURL: "beszel-companion://redirect")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                struct TokenResponseBody: Decodable {
                    let token: String
                    let record: SSOUserRecord
                }
                let responseBody = try JSONDecoder().decode(TokenResponseBody.self, from: data)
                return (responseBody.token, responseBody.record.email)
            }
            if httpResponse.statusCode == 401 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let mfaId = json["mfaId"] as? String {
                    throw OnboardingError.oauthMfaRequired(mfaId: mfaId)
                }
            }
        }
        throw OnboardingError.hubUnreachable
    }

    private struct AuthTokenResponse: Decodable {
        let token: String
    }

    func verifyCredentials(url: String, email: String, password: String) async throws {
        guard let authURL = URL(string: "\(url)/api/collections/users/auth-with-password") else {
            throw OnboardingError.invalidURL
        }

        var request = URLRequest(url: authURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["identity": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                return
            }
            if httpResponse.statusCode == 401 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let mfaId = json["mfaId"] as? String {
                    let otpId = try await requestOTP(url: url, email: email)
                    throw OnboardingError.mfaRequired(mfaId: mfaId, otpId: otpId)
                }
            }
            throw OnboardingError.authenticationFailed
        }
    }

    private struct OTPResponse: Decodable {
        let otpId: String
    }

    func requestOTP(url: String, email: String) async throws -> String {
        guard let otpURL = URL(string: "\(url)/api/collections/users/request-otp") else {
            throw OnboardingError.invalidURL
        }

        var request = URLRequest(url: otpURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["email": email]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OnboardingError.authenticationFailed
        }

        let otpResponse = try JSONDecoder().decode(OTPResponse.self, from: data)
        return otpResponse.otpId
    }

    func verifyCredentialsWithMFA(url: String, mfaId: String, otpId: String, otpCode: String) async throws -> String {
        guard let authURL = URL(string: "\(url)/api/collections/users/auth-with-otp") else {
            throw OnboardingError.invalidURL
        }

        var request = URLRequest(url: authURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "otpId": otpId,
            "password": otpCode,
            "mfaId": mfaId
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OnboardingError.authenticationFailed
        }

        let authResponse = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
        return authResponse.token
    }
}
