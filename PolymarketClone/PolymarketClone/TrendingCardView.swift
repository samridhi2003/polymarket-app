import SwiftUI

struct TrendingCardView: View {
    let event: Event

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image
            if let imageURL = event.image, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        fallbackGradient
                    default:
                        Color.gray.opacity(0.1).overlay(ProgressView().tint(.gray))
                    }
                }
            } else {
                fallbackGradient
            }

            // Dark gradient overlay
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Spacer()

                if let tag = event.primaryTag {
                    Text(tag.label.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                Text(event.title)
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let top = event.displayOutcomes.first {
                    HStack(spacing: 3) {
                        Circle().fill(.green).frame(width: 5, height: 5)
                        Text(top.displayName)
                            .lineLimit(1)
                        Text("\(Int(top.price * 100))%")
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
                }

                // Volume
                HStack(spacing: 2) {
                    Image(systemName: "chart.bar.fill")
                    Text(event.formattedVolume)
                }
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.6))
            }
            .padding(10)
        }
        .frame(width: 160, height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }

    private var fallbackGradient: some View {
        LinearGradient(
            colors: [.blue.opacity(0.4), .purple.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
