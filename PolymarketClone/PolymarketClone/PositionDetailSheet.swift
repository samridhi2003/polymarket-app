import SwiftUI

struct PositionDetailSheet: View {
    let position: Position
    @ObservedObject var viewModel: MarketViewModel
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var isSelling = false
    @State private var sellComplete = false
    @State private var errorMsg: String?

    private var shares: Double {
        position.numShares
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if sellComplete {
                            sellSuccessView
                        } else {
                            positionInfoView
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Position Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Position Info

    private var positionInfoView: some View {
        VStack(spacing: 16) {
            // Header
            headerSection

            // Stats grid
            statsSection

            // PnL card
            pnlCard

            // Error
            if let error = errorMsg {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }

            // Sell button
            sellButton
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 14) {
            if let imageURL = position.marketImage, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(position.eventTitle)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(position.outcome)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(position.outcome == "Yes" ? Color.green : Color.red)
                        .clipShape(Capsule())

                    Text(position.marketQuestion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(spacing: 0) {
            statRow(label: "Shares", value: String(format: "%.2f", shares))
            Divider().padding(.horizontal, 14)
            statRow(label: "Avg Price", value: String(format: "%.1f", position.avgPrice * 100) + "\u{00A2}")
            Divider().padding(.horizontal, 14)
            statRow(label: "Current Price", value: String(format: "%.1f", position.currentPrice * 100) + "\u{00A2}")
            Divider().padding(.horizontal, 14)
            statRow(label: "Cost Basis", value: "$" + String(format: "%.2f", position.amount))
            Divider().padding(.horizontal, 14)
            statRow(label: "Current Value", value: "$" + String(format: "%.2f", position.currentValue))
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - PnL Card

    private var pnlCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Profit / Loss")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text("\(position.pnl >= 0 ? "+" : "")$\(String(format: "%.2f", position.pnl))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(position.pnl >= 0 ? .green : .red)

                    Text("(\(position.pnlPercent >= 0 ? "+" : "")\(String(format: "%.1f", position.pnlPercent))%)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(position.pnlPercent >= 0 ? .green : .red)
                }
            }

            Spacer()

            Image(systemName: position.pnl >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(position.pnl >= 0 ? .green : .red)
                .opacity(0.8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(position.pnl >= 0 ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(position.pnl >= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Sell Button

    private let minimumShares: Double = 5

    private var isBelowMinimum: Bool {
        shares < minimumShares
    }

    private var sellButton: some View {
        VStack(spacing: 8) {
            Button {
                Task { await sellPosition() }
            } label: {
                HStack(spacing: 8) {
                    if isSelling {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.down.right")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Sell Position")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isSelling || isBelowMinimum ? Color.gray.opacity(0.3) : Color.red)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isSelling || isBelowMinimum)

            if isBelowMinimum {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                    Text("Below minimum sell size (\(Int(minimumShares)) shares). This position will settle at market resolution.")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Sell Success

    private var sellSuccessView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 6) {
                Text("Position Sold!")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("\(String(format: "%.2f", shares)) shares of \(position.outcome)")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                summaryRow(label: "Sold For", value: "$\(String(format: "%.2f", position.currentValue))", color: .primary)
                summaryRow(label: "Cost Basis", value: "$\(String(format: "%.2f", position.amount))")
                summaryRow(label: "Profit/Loss", value: "\(position.pnl >= 0 ? "+" : "")$\(String(format: "%.2f", position.pnl))", color: position.pnl >= 0 ? .green : .red)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.body)
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

    private func summaryRow(label: String, value: String, color: Color = .secondary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }

    // MARK: - Sell Logic

    private func sellPosition() async {
        guard let wallet = auth.embeddedWallet else {
            errorMsg = "No wallet connected."
            return
        }

        guard let conditionId = position.conditionId,
              let tokenId = position.tokenId else {
            errorMsg = "Position missing market data. Cannot sell."
            return
        }

        isSelling = true
        errorMsg = nil

        do {
            try await viewModel.sellPosition(
                wallet: wallet,
                position: position,
                conditionId: conditionId,
                tokenId: tokenId
            )
            sellComplete = true
        } catch {
            print("[PositionDetail] Sell failed: \(error)")
            errorMsg = error.localizedDescription
        }

        isSelling = false
    }
}
