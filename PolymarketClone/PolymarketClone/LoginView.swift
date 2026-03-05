import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var email = ""
    @State private var otpCode = ""
    @State private var codeSent = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo / Header
            VStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("Polymarket")
                    .font(.largeTitle)
                    .fontWeight(.black)

                Text("Bet on the future")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 48)

            // Login form
            VStack(spacing: 16) {
                if !codeSent {
                    emailField
                } else {
                    otpField
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                primaryButton

                if codeSent {
                    Button("Use a different email") {
                        withAnimation { codeSent = false; otpCode = ""; errorMessage = nil }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)

            divider

            // Apple Sign-In
            appleSignInButton
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Subviews

    private var emailField: some View {
        TextField("Email address", text: $email)
            #if os(iOS)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            #endif
            .autocorrectionDisabled()
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }

    private var otpField: some View {
        VStack(spacing: 8) {
            Text("Enter the code sent to \(email)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("6-digit code", text: $otpCode)
                #if os(iOS)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                #endif
                .multilineTextAlignment(.center)
                .font(.title2.monospaced())
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }

    private var primaryButton: some View {
        Button {
            Task { await codeSent ? verifyCode() : sendCode() }
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(codeSent ? "Verify Code" : "Continue with Email")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(buttonDisabled ? Color.blue.opacity(0.4) : Color.blue)
            .foregroundStyle(.white)
            .cornerRadius(12)
        }
        .disabled(buttonDisabled)
    }

    private var buttonDisabled: Bool {
        isLoading || (codeSent ? otpCode.count < 6 : email.isEmpty)
    }

    private var divider: some View {
        HStack {
            Rectangle().frame(height: 1).foregroundStyle(Color(.systemGray4))
            Text("or").font(.subheadline).foregroundStyle(.secondary)
            Rectangle().frame(height: 1).foregroundStyle(Color(.systemGray4))
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }

    private var appleSignInButton: some View {
        Button {
            Task { await signInWithApple() }
        } label: {
            HStack {
                Image(systemName: "apple.logo")
                Text("Sign in with Apple")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.label))
            .foregroundStyle(Color(.systemBackground))
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }

    // MARK: - Actions

    private func sendCode() async {
        isLoading = true
        errorMessage = nil
        do {
            try await auth.sendEmailCode(to: email)
            withAnimation { codeSent = true }
        } catch {
            errorMessage = "Failed to send code. Check your email and try again."
        }
        isLoading = false
    }

    private func verifyCode() async {
        isLoading = true
        errorMessage = nil
        do {
            try await auth.loginWithEmailCode(otpCode, sentTo: email)
        } catch {
            errorMessage = "Invalid code. Please try again."
        }
        isLoading = false
    }

    private func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        do {
            try await auth.loginWithApple()
        } catch {
            errorMessage = "Apple Sign-In failed. Please try again."
        }
        isLoading = false
    }
}
