import SwiftUI

struct MFAView: View {
    let url: String
    let mfaId: String
    let otpId: String?
    let email: String?
    var onComplete: (String) -> Void
    var onCancel: () -> Void

    @State private var otpCode = ""
    @State private var emailInput = ""
    @State private var currentOtpId: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var otpRequested = false

    private let apiService = OnboardingAPIService()

    private var isVerifyDisabled: Bool {
        otpCode.isEmpty || currentOtpId == nil
    }

    private var displayEmail: String {
        email ?? emailInput
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("onboarding.mfa.title")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("onboarding.mfa.subtitle")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                if email == nil {
                    TextField("onboarding.input.email", text: $emailInput)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(10)
                        .disabled(otpRequested)
                }

                if !otpRequested {
                    Button(action: requestOTP) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("onboarding.mfa.sendCode")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRequestDisabled ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isRequestDisabled || isLoading)
                } else {
                    Text(String(format: String(localized: "onboarding.mfa.codeSentTo"), displayEmail))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("onboarding.input.mfaCode", text: $otpCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(10)

                    Button(action: verifyOTP) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("onboarding.verifyMFA")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isVerifyDisabled ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isVerifyDisabled || isLoading)

                    Button(action: resendCode) {
                        Text("onboarding.mfa.resendCode")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .disabled(isLoading)
                }
            }
            .padding(.horizontal)

            if let errorMessage = errorMessage {
                Text(LocalizedStringKey(errorMessage))
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            Spacer()

            Button(action: onCancel) {
                Text("common.cancel")
                    .foregroundColor(.secondary)
            }
            .padding(.bottom)
        }
        .onAppear {
            if let existingOtpId = otpId {
                currentOtpId = existingOtpId
                otpRequested = true
            }
        }
    }

    private var isRequestDisabled: Bool {
        email == nil && emailInput.isEmpty
    }

    private func requestOTP() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let newOtpId = try await apiService.requestOTP(url: url, email: displayEmail)
                await MainActor.run {
                    isLoading = false
                    currentOtpId = newOtpId
                    otpRequested = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func resendCode() {
        otpCode = ""
        requestOTP()
    }

    private func verifyOTP() {
        guard let otpId = currentOtpId else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let token = try await apiService.verifyCredentialsWithMFA(
                    url: url,
                    mfaId: mfaId,
                    otpId: otpId,
                    otpCode: otpCode
                )
                await MainActor.run {
                    isLoading = false
                    onComplete(token)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = String(localized: "onboarding.mfa.invalidCode")
                }
            }
        }
    }
}
