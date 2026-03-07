import SwiftUI

struct BrowserTabView: View {
    @ObservedObject var browserController: BrowserController
    @Binding var pendingURL: URL?

    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var progress: Double = 0
    @State private var currentURL = ""
    @State private var pageTitle = ""
    @State private var addressText = ""
    @State private var isEditingAddress = false
    @FocusState private var addressFieldFocused: Bool

    private let defaultURL = URL(string: "https://www.google.com")!

    var body: some View {
        VStack(spacing: 0) {
            // Address bar
            addressBar

            // Progress bar
            if isLoading {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: geo.size.width * progress, height: 2.5)
                        .animation(.linear(duration: 0.2), value: progress)
                }
                .frame(height: 2.5)
            } else {
                Color.clear.frame(height: 2.5)
            }

            // Web content
            ControllableWebView(
                initialURL: defaultURL,
                controller: browserController,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                isLoading: $isLoading,
                progress: $progress,
                currentURL: $currentURL,
                pageTitle: $pageTitle
            )

            // Bottom toolbar
            bottomToolbar
        }
        .padding(.bottom, 60)
        .background(Color(.systemBackground))
        .onChange(of: pendingURL) { newURL in
            if let url = newURL {
                browserController.load(url)
                pendingURL = nil
            }
        }
    }

    // MARK: - Address Bar

    private var addressBar: some View {
        HStack(spacing: 10) {
            if isEditingAddress {
                // Editable text field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    TextField("Search or enter URL", text: $addressText)
                        .font(.system(size: 14))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .focused($addressFieldFocused)
                        .submitLabel(.go)
                        .onSubmit { navigateToAddress() }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("Cancel") {
                    isEditingAddress = false
                    addressFieldFocused = false
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.purple)
            } else {
                // Display mode — show domain
                Button {
                    addressText = currentURL
                    isEditingAddress = true
                    addressFieldFocused = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isLoading ? "circle.dotted" : "lock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(isLoading ? .secondary : .green)

                        Text(displayDomain)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer()

                        if isLoading {
                            ProgressView()
                                .controlSize(.mini)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var displayDomain: String {
        guard let url = URL(string: currentURL),
              let host = url.host else {
            return "google.com"
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    private func navigateToAddress() {
        isEditingAddress = false
        addressFieldFocused = false

        var urlString = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty else { return }

        // If no scheme, add https
        if !urlString.contains("://") {
            if urlString.contains(".") {
                urlString = "https://\(urlString)"
            } else {
                // Treat as search query
                urlString = "https://www.google.com/search?q=\(urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString)"
            }
        }

        if let url = URL(string: urlString) {
            browserController.load(url)
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            toolbarButton(icon: "chevron.left", enabled: canGoBack) {
                browserController.goBack()
            }

            toolbarButton(icon: "chevron.right", enabled: canGoForward) {
                browserController.goForward()
            }

            Spacer()

            toolbarButton(icon: "square.and.arrow.up", enabled: true) {
                shareCurrentPage()
            }

            Spacer()

            toolbarButton(icon: "arrow.clockwise", enabled: !isLoading) {
                browserController.reload()
            }

            toolbarButton(icon: "house", enabled: true) {
                browserController.load(defaultURL)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func toolbarButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(enabled ? .primary : .quaternary)
                .frame(width: 44, height: 36)
        }
        .disabled(!enabled)
    }

    private func shareCurrentPage() {
        guard let url = URL(string: currentURL) else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
