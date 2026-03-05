import SwiftUI
import Combine
import PrivySDK

@MainActor
class AuthManager: ObservableObject {
    @Published var isReady = false
    @Published var isAuthenticated = false
    @Published var userId: String?
    @Published var walletAddress: String?
    @Published var isCreatingWallet = false

    private(set) var privy: Privy!
    private(set) var embeddedWallet: EmbeddedEthereumWallet?

    init() {
        let appId = Bundle.main.infoDictionary?["PRIVY_APP_ID"] as? String ?? ""
        let clientId = Bundle.main.infoDictionary?["PRIVY_CLIENT_ID"] as? String ?? ""

        let config = PrivyConfig(appId: appId, appClientId: clientId)
        privy = PrivySdk.initialize(config: config)

        Task { await checkAuthState() }
    }

    func checkAuthState() async {
        let state = await privy.getAuthState()
        switch state {
        case .authenticated(let user):
            isAuthenticated = true
            userId = user.id
            await loadEmbeddedWallet(from: user)
        case .unauthenticated:
            isAuthenticated = false
            userId = nil
            walletAddress = nil
            embeddedWallet = nil
        default:
            break
        }
        isReady = true
    }

    // MARK: - Embedded Wallet

    private func loadEmbeddedWallet(from user: PrivyUser) async {
        // Check if user already has an embedded Ethereum wallet
        let ethWallets = user.embeddedEthereumWallets
        if let existing = ethWallets.first {
            embeddedWallet = existing
            walletAddress = existing.address
            return
        }

        // No wallet yet — create one
        await createEmbeddedWallet(for: user)
    }

    private func createEmbeddedWallet(for user: PrivyUser) async {
        isCreatingWallet = true
        do {
            let wallet = try await user.createEthereumWallet(allowAdditional: false)
            embeddedWallet = wallet
            walletAddress = wallet.address
        } catch {
            print("[Auth] Failed to create wallet: \(error)")
        }
        isCreatingWallet = false
    }

    // MARK: - Email OTP

    func sendEmailCode(to email: String) async throws {
        try await privy.email.sendCode(to: email)
    }

    func loginWithEmailCode(_ code: String, sentTo email: String) async throws {
        let user = try await privy.email.loginWithCode(code, sentTo: email)
        isAuthenticated = true
        userId = user.id
        await loadEmbeddedWallet(from: user)
    }

    // MARK: - Apple Sign-In

    func loginWithApple() async throws {
        let _ = try await privy.oAuth.login(with: OAuthProvider.apple)
        await checkAuthState()
    }

    // MARK: - Logout

    func logout() {
        privy.user?.logout()
        isAuthenticated = false
        userId = nil
        walletAddress = nil
        embeddedWallet = nil
    }
}
