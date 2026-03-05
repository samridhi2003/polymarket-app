import SwiftUI

struct MarketsTabView: View {
    @ObservedObject var viewModel: MarketViewModel
    @EnvironmentObject var auth: AuthManager
    @State private var selectedEvent: Event? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                Group {
                    if viewModel.isLoading {
                        ProgressView("Loading markets...")
                    } else if let error = viewModel.errorMessage {
                        ErrorView(message: error) {
                            Task { await viewModel.loadMarkets() }
                        }
                    } else {
                        mainContent
                    }
                }
            }
            .navigationTitle("Polymarket")
            .searchable(text: $viewModel.searchText, prompt: "Search markets...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { auth.logout() } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailSheet(event: event, viewModel: viewModel)
            }
        }
    }

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                categoryChips

                if viewModel.searchText.isEmpty {
                    trendingSection
                }

                eventsListSection
            }
            .padding(.bottom, 80)
        }
        .refreshable {
            await viewModel.loadMarkets()
        }
    }

    // MARK: - Category Chips
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton(label: "All", isSelected: viewModel.selectedTag == nil) {
                    viewModel.selectedTag = nil
                }
                ForEach(viewModel.allTags) { tag in
                    chipButton(label: tag.label, isSelected: viewModel.selectedTag == tag) {
                        viewModel.selectedTag = (viewModel.selectedTag == tag) ? nil : tag
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.footnote)
                .fontWeight(isSelected ? .semibold : .medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.tertiarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    // MARK: - Trending
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Trending")
                    .font(.headline)
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.trendingEvents) { event in
                        TrendingCardView(event: event)
                            .onTapGesture { selectedEvent = event }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Events List
    private var eventsListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("All Markets")
                .font(.headline)
                .padding(.horizontal, 16)

            LazyVStack(spacing: 8) {
                ForEach(viewModel.filteredEvents) { event in
                    EventRowView(event: event)
                        .onTapGesture { selectedEvent = event }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
