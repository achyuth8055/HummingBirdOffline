import SwiftUI
import SwiftData

struct PodcastDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let podcast: Podcast
    let episodes: [Episode]
    let suggestions: [Podcast]

    private let podcastPlayer = PodcastPlayerViewModel.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HBSpacingToken.sectionGap) {
                header

                if !episodes.isEmpty {
                    playLatestButton
                    episodeList
                } else {
                    Text("Episodes will appear once this podcast updates.")
                        .font(HBFont.body(13))
                        .foregroundColor(.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 24)
                }

                if !suggestions.isEmpty {
                    suggestionsSection
                }
            }
            .padding(.horizontal, HBSpacingToken.hInset)
            .padding(.top, 28)
            .padding(.bottom, 40)
        }
        .background(Color.primaryBackground.ignoresSafeArea())
        .navigationTitle(podcast.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                AsyncImage(url: podcast.artworkURLValue) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Color.secondaryBackground
                    case .empty:
                        ProgressView()
                    @unknown default:
                        Color.secondaryBackground
                    }
                }
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: HBCornerToken.card, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text(podcast.title)
                        .font(HBFont.heading(24))
                        .foregroundColor(.primaryText)
                        .lineLimit(2)
                    Text(podcast.author)
                        .font(HBFont.body(14, weight: .medium))
                        .foregroundColor(.secondaryText)
                        .lineLimit(1)

                    if !podcast.categories.isEmpty {
                        Text(podcast.categories.joined(separator: " • "))
                            .font(HBFont.body(12))
                            .foregroundColor(.secondaryText)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }

            if !podcast.podcastDescription.isEmpty {
                Text(podcast.podcastDescription)
                    .font(HBFont.body(13))
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    // MARK: - Actions
    private var playLatestButton: some View {
        Button(action: playLatest) {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                Text("Play Latest Episode")
                    .font(HBFont.body(15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.hbPrimary)
    }

    private func playLatest() {
        guard let first = episodes.first else { return }
        playEpisode(first)
    }

    // MARK: - Episode List
    private var episodeList: some View {
        VStack(alignment: .leading, spacing: HBSpacingToken.sectionGap) {
            Text("Episodes")
                .font(HBFont.heading(20))
                .foregroundColor(.primaryText)

            ForEach(episodes) { episode in
                Button { playEpisode(episode) } label: {
                    episodeRow(for: episode)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func episodeRow(for episode: Episode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(episode.title)
                .font(HBFont.body(15, weight: .semibold))
                .foregroundColor(.primaryText)
                .lineLimit(2)

            HStack(spacing: 12) {
                if let date = episode.publishedAt {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(HBFont.body(12))
                        .foregroundColor(.secondaryText)
                }
                if let duration = episode.duration, duration > 0 {
                    Text(durationFormatter.string(from: duration) ?? "")
                        .font(HBFont.body(12))
                        .foregroundColor(.secondaryText)
                }
            }
            if episode.playbackProgress > 0 {
                ProgressView(value: episode.playbackProgress)
                    .tint(Color.accentGreen)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: HBCornerToken.card, style: .continuous)
                .fill(Color.secondaryBackground)
        )
    }

    private func playEpisode(_ episode: Episode) {
        let ordered = episodes
        podcastPlayer.play(episode: episode, in: ordered)
    }

    private var durationFormatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .brief
        return formatter
    }

    private func storedEpisodes(for podcast: Podcast) -> [Episode] {
        let id = podcast.id
        let descriptor = FetchDescriptor<Episode>(predicate: #Predicate { $0.podcastID == id })
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("You Might Also Like")
                .font(HBFont.heading(20))
                .foregroundColor(.primaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HBSpacingToken.railGutter) {
                    ForEach(suggestions) { suggestion in
                        NavigationLink {
                            PodcastDetailView(
                                podcast: suggestion,
                                episodes: storedEpisodes(for: suggestion),
                                suggestions: PodcastAPIService.suggested(excluding: [suggestion.id])
                            )
                        } label: {
                            SimilarPodcastCard(podcast: suggestion)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(.top, 24)
    }
}

private struct SimilarPodcastCard: View {
    let podcast: Podcast

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsyncImage(url: podcast.artworkURLValue) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Color.secondaryBackground
                case .empty:
                    ProgressView()
                @unknown default:
                    Color.secondaryBackground
                }
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: HBCornerToken.card, style: .continuous))

            Text(podcast.title)
                .font(HBFont.body(14, weight: .semibold))
                .foregroundColor(.primaryText)
                .lineLimit(2)

            Text(podcast.author)
                .font(HBFont.body(12))
                .foregroundColor(.secondaryText)
                .lineLimit(1)
        }
        .frame(width: 150, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: HBCornerToken.card, style: .continuous)
                .fill(Color.secondaryBackground)
                .hbShadow(style: .small)
        )
    }
}

#Preview {
    let podcast = Podcast(
        id: "preview",
        title: "HummingBird Daily",
        author: "HummingBird Studios",
        artworkURL: nil,
        feedURL: "https://example.com/feed",
        categories: ["Music", "Interviews"],
        description: "Stay in the loop with the latest from HummingBird."
    )

    let episode = Episode(
        id: UUID().uuidString,
        podcastID: podcast.id,
        title: "Episode 1",
        publishedAt: Date(),
        duration: 1800,
        description: "",
        audioURL: "https://example.com/audio.mp3"
    )

    return NavigationStack {
        PodcastDetailView(podcast: podcast, episodes: [episode], suggestions: PodcastAPIService.suggested())
    }
    .environmentObject(PlayerViewModel.shared)
}
