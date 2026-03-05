import SwiftUI

struct EventRowView: View {
    let event: Event

    var body: some View {
        HStack(spacing: 10) {
            // Thumbnail
            if let imageURL = event.image, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.15))
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                // Outcomes row
                HStack(spacing: 8) {
                    ForEach(Array(event.displayOutcomes.prefix(2).enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 2) {
                            Text(item.displayName)
                                .lineLimit(1)
                            Text("\(Int(item.price * 100))%")
                                .fontWeight(.bold)
                                .foregroundColor(outcomeColor(for: item.price))
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                }

                // Volume
                HStack(spacing: 3) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 8))
                    Text("Vol \(event.formattedVolume)")
                        .font(.caption2)
                }
                .foregroundColor(.secondary.opacity(0.7))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func outcomeColor(for price: Double) -> Color {
        if price > 0.5 { return .green }
        if price > 0.2 { return .orange }
        return .red
    }
}
