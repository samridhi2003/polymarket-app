import SwiftUI
import CoreImage.CIFilterBuiltins

struct WalletTabView: View {
    @ObservedObject var viewModel: MarketViewModel
    @EnvironmentObject var auth: AuthManager
    @Environment(\.openInAppBrowser) var openInAppBrowser

    @State private var showSendSheet = false
    @State private var showReceiveSheet = false
    @State private var selectedPosition: Position?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color.blue.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        walletCard
                        actionButtonsRow
                        positionsSection
                    }
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("Wallet")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        auth.logout()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showSendSheet) {
                SendUSDCSheet(viewModel: viewModel)
                    .environmentObject(auth)
                    .environment(\.openInAppBrowser, openInAppBrowser)
            }
            .sheet(isPresented: $showReceiveSheet) {
                ReceiveSheet()
                    .environmentObject(auth)
            }
            .sheet(item: $selectedPosition) { position in
                PositionDetailSheet(position: position, viewModel: viewModel)
                    .environmentObject(auth)
            }
            .task {
                if let address = auth.walletAddress {
                    await viewModel.refreshBalance(walletAddress: address)
                }
            }
        }
    }

    // MARK: - Wallet Card

    private var walletCard: some View {
        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.33, green: 0.22, blue: 0.93),
                            Color(red: 0.42, green: 0.32, blue: 1.0),
                            Color(red: 0.36, green: 0.26, blue: 0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Subtle noise/shimmer overlay
                    RoundedRectangle(cornerRadius: 22)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.clear,
                                    Color.white.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: Color(red: 0.33, green: 0.22, blue: 0.93).opacity(0.45), radius: 24, y: 12)

            // Card content
            VStack(alignment: .leading, spacing: 0) {
                // Top row: avatar + address
                HStack(alignment: .top) {
                    // Profile avatar
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        )

                    Spacer()

                    // Wallet address + copy
                    if auth.isCreatingWallet {
                        HStack(spacing: 6) {
                            ProgressView()
                                .tint(.white.opacity(0.7))
                                .controlSize(.small)
                            Text("Creating...")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    } else if let address = auth.walletAddress {
                        HStack(spacing: 6) {
                            Text(truncateAddress(address))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.85))

                            Button {
                                UIPasteboard.general.string = address
                            } label: {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(6)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }

                Spacer()

                // Bottom section: name + balance
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wallet")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    if viewModel.isLoadingBalance {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white.opacity(0.7))
                                .controlSize(.small)
                            Text("Loading...")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(String(format: "%.2f", viewModel.usdcBalance))")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("USDC")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                        }

                        if viewModel.nativeBalance > 0 {
                            Text("\(String(format: "%.4f", viewModel.nativeBalance)) POL")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.45))
                        }
                    }
                }
            }
            .padding(22)
        }
        .frame(height: 200)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Action Buttons Row

    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            actionButton(title: "Send", icon: "arrow.up.circle.fill", color: .blue) {
                showSendSheet = true
            }
            actionButton(title: "Receive", icon: "arrow.down.circle.fill", color: .green) {
                showReceiveSheet = true
            }
            actionButton(title: "Refresh", icon: "arrow.clockwise.circle.fill", color: .orange) {
                Task {
                    if let address = auth.walletAddress {
                        await viewModel.refreshBalance(walletAddress: address)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Positions
    private var positionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Positions")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal, 16)

            if viewModel.positions.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.positions) { position in
                        positionRow(position)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPosition = position
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No positions yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Place your first bet to see it here")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private func positionRow(_ position: Position) -> some View {
        HStack(spacing: 12) {
            if let imageURL = position.marketImage, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(position.eventTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(position.outcome)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", position.amount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", position.currentValue))")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(position.pnlPercent >= 0 ? "+" : "")\(String(format: "%.1f", position.pnlPercent))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(position.pnlPercent >= 0 ? .green : .red)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func truncateAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
}

// MARK: - Send USDC Sheet

struct SendUSDCSheet: View {
    @ObservedObject var viewModel: MarketViewModel
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.openInAppBrowser) var openInAppBrowser

    @State private var recipientAddress = ""
    @State private var amount = ""
    @State private var isSending = false
    @State private var sendStatus = ""
    @State private var txHash: String?
    @State private var isConfirmed = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isSending || txHash != nil {
                    // Sending / confirming / confirmed
                    VStack(spacing: 16) {
                        Spacer().frame(height: 20)

                        if isConfirmed {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 56))
                                .foregroundColor(.green)
                        } else {
                            ProgressView()
                                .controlSize(.large)
                        }

                        Text(isConfirmed ? "Transaction Confirmed!" : sendStatus)
                            .font(.title3).fontWeight(.semibold)
                            .multilineTextAlignment(.center)

                        if let txHash = txHash {
                            VStack(spacing: 8) {
                                Text("Tx: \(txHash.prefix(10))...\(txHash.suffix(6))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Button {
                                    if let url = URL(string: "https://polygonscan.com/tx/\(txHash)") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.caption)
                                        Text("View on Polygonscan")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundStyle(.blue)
                                }
                            }
                        }

                        if isConfirmed {
                            Button {
                                dismiss()
                            } label: {
                                Text("Done")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color(.tertiarySystemGroupedBackground))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.top, 8)
                        }
                    }
                } else if errorMsg != nil {
                    // Error state with retry
                    VStack(spacing: 16) {
                        Spacer().frame(height: 20)
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.red)
                        Text("Transaction Failed")
                            .font(.title3).fontWeight(.semibold)
                        Text(errorMsg ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button {
                            errorMsg = nil
                        } label: {
                            Text("Try Again")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recipient Address")
                            .font(.subheadline).foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            TextField("0x...", text: $recipientAddress)
                                .font(.system(.body, design: .monospaced))
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.asciiCapable)
                                #endif
                                .autocorrectionDisabled()
                                .textContentType(.none)
                            Button {
                                #if os(iOS)
                                if let pasted = UIPasteboard.general.string {
                                    recipientAddress = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                                #endif
                            } label: {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.body)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount (USDC)")
                            .font(.subheadline).foregroundColor(.secondary)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text("Balance: $\(String(format: "%.2f", viewModel.usdcBalance)) USDC")
                            .font(.caption).foregroundColor(.secondary)
                    }

                    Button {
                        Task { await sendUSDC() }
                    } label: {
                        Text("Send USDC")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canSend ? Color.blue : Color.gray.opacity(0.3))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canSend)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Send USDC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var canSend: Bool {
        let trimmed = recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count == 42 &&
            trimmed.hasPrefix("0x") &&
            (Double(amount) ?? 0) > 0
    }

    private func sendUSDC() async {
        let trimmedAddress = recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let wallet = auth.embeddedWallet,
              let sendAmount = Double(amount) else {
            print("[Send] Missing wallet or invalid amount")
            return
        }

        isSending = true
        errorMsg = nil
        isConfirmed = false
        sendStatus = "Signing transaction..."

        print("[Send] Sending \(sendAmount) USDC to \(trimmedAddress)")

        do {
            sendStatus = "Sending transaction..."
            let hash = try await WalletService.shared.sendUSDC(
                from: wallet,
                to: trimmedAddress,
                amount: sendAmount
            )
            txHash = hash
            print("[Send] TX hash: \(hash)")

            sendStatus = "Waiting for confirmation..."
            try await WalletService.shared.waitForConfirmation(txHash: hash)

            isConfirmed = true
            print("[Send] Confirmed!")

            if let address = auth.walletAddress {
                await viewModel.refreshBalance(walletAddress: address)
            }
        } catch {
            print("[Send] Error: \(error)")
            errorMsg = error.localizedDescription
        }
        isSending = false
    }
}

// MARK: - Receive Sheet

struct ReceiveSheet: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let address = auth.walletAddress {
                    Text("Your Polygon Wallet")
                        .font(.headline)

                    // QR Code
                    if let qrImage = generateQRCode(from: address) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Address
                    VStack(spacing: 8) {
                        Text(address)
                            .font(.system(.caption, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .padding(16)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            UIPasteboard.general.string = address
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Address")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }

                    Text("Send USDC on Polygon network to this address")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    ProgressView("Loading wallet...")
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Receive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scale = 200.0 / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
