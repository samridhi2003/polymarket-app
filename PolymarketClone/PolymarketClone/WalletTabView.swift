import SwiftUI
import CoreImage.CIFilterBuiltins

struct WalletTabView: View {
    @ObservedObject var viewModel: MarketViewModel
    @EnvironmentObject var auth: AuthManager

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
                        walletAddressSection
                        balanceCard
                        positionsSection
                    }
                    .padding(.bottom, 20)
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

    // MARK: - Wallet Address
    private var walletAddressSection: some View {
        Group {
            if auth.isCreatingWallet {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Creating wallet...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 8)
            } else if let address = auth.walletAddress {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(truncateAddress(address))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = address
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Balance Card
    private var balanceCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("USDC Balance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if viewModel.isLoadingBalance {
                    ProgressView()
                        .frame(height: 48)
                } else {
                    Text("$\(String(format: "%.2f", viewModel.usdcBalance))")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                }

                if viewModel.nativeBalance > 0 {
                    Text("\(String(format: "%.4f", viewModel.nativeBalance)) POL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

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
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
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

    @State private var recipientAddress = ""
    @State private var amount = ""
    @State private var isSending = false
    @State private var txHash: String?
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let txHash = txHash {
                    // Success
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        Text("Transaction Sent!")
                            .font(.title2).fontWeight(.bold)
                        Text("Tx: \(txHash.prefix(10))...\(txHash.suffix(6))")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recipient Address")
                            .font(.subheadline).foregroundColor(.secondary)
                        TextField("0x...", text: $recipientAddress)
                            .font(.system(.body, design: .monospaced))
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

                    if let error = errorMsg {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button {
                        Task { await sendUSDC() }
                    } label: {
                        Group {
                            if isSending {
                                ProgressView().tint(.white)
                            } else {
                                Text("Send USDC")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canSend ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canSend || isSending)
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
        !recipientAddress.isEmpty &&
        recipientAddress.hasPrefix("0x") &&
        recipientAddress.count == 42 &&
        (Double(amount) ?? 0) > 0
    }

    private func sendUSDC() async {
        guard let wallet = auth.embeddedWallet,
              let sendAmount = Double(amount) else { return }

        isSending = true
        errorMsg = nil

        do {
            let hash = try await WalletService.shared.sendUSDC(
                from: wallet,
                to: recipientAddress,
                amount: sendAmount
            )
            txHash = hash
            // Refresh balance after send
            if let address = auth.walletAddress {
                await viewModel.refreshBalance(walletAddress: address)
            }
        } catch {
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
