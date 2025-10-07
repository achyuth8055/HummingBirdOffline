import SwiftUI
import SwiftData

struct PodcastsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = PodcastBrowseViewModel()
    @State private var isFetchingFeed = false
    @State private var activeDetail: PodcastDetailPayload?

    private var hasQuery: Bool {
        !viewModel.searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if hasQuery {
                        SectionHeader(title: "Search results")
                        if viewModel.isSearching {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .frame(maxWidth: .infinity)
                        } else if viewModel.results.isEmpty {
                            Text("No podcasts found")
                                .font(HBFont.body(13))
                                .foregroundColor(.secondaryText)
                        } else {
                            podcastList(viewModel.results)
                        }
                    } else {
                        if !viewModel.top.isEmpty {
                            SectionHeader(title: "Top Podcasts")
                            podcastList(viewModel.top)
                        }
                        if !viewModel.followed.isEmpty {
                            SectionHeader(title: "Following")
                            podcastList(viewModel.followed)
                        }
                        if !viewModel.recommended.isEmpty {
                            SectionHeader(title: "You Might Like")
                            podcastList(viewModel.recommended)
                        }
                        if !viewModel.trending.isEmpty {
                            SectionHeader(title: "Trending")
                            podcastList(viewModel.trending)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 64)
            }

            if isFetchingFeed {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .zIndex(1)
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Loading episodes…")
                        .font(HBFont.body(13, weight: .medium))
                        .foregroundColor(.primaryText)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.secondaryBackground.opacity(0.96))
                )
                .shadow(color: .black.opacity(0.25), radius: 18, y: 12)
                .zIndex(2)
            }
        }
        .allowsHitTesting(!isFetchingFeed)
        .background(Color.primaryBackground.ignoresSafeArea())
        .navigationTitle("Podcasts")
        .searchable(text: Binding(
            get: { viewModel.searchTerm },
            set: { viewModel.updateSearchTerm($0) }
        ), prompt: "Search podcasts")
        .onAppear { viewModel.loadTrending() }
        .navigationDestination(item: $activeDetail) { payload in
            PodcastDetailView(
                podcast: payload.podcast,
                episodes: payload.episodes,
                suggestions: payload.suggestions
            )
        }
    }

    @ViewBuilder
    private func podcastList(_ items: [Podcast]) -> some View {
        LazyVStack(spacing: 16) {
            if items.isEmpty {
                Text("No podcasts available.")
                    .font(HBFont.body(13))
                    .foregroundColor(.secondaryText)
            } else {
                ForEach(items) { podcast in
                    Button { fetchFeed(for: podcast) } label: {
                        PodcastCard(podcast: podcast)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func fetchFeed(for podcast: Podcast) {
        guard !isFetchingFeed else { return }
        isFetchingFeed = true

        Task {
            do {
                let result = try await PodcastFeedService.fetchFeed(for: podcast)
                await MainActor.run {
                    let storedPodcast = upsertPodcast(result.podcast)
                    let storedEpisodes = upsertEpisodes(result.episodes, for: storedPodcast)
                    let suggestions = PodcastAPIService.suggested(excluding: [storedPodcast.id])
                    activeDetail = PodcastDetailPayload(podcast: storedPodcast, episodes: storedEpisodes, suggestions: suggestions)
                    try? modelContext.save()
                }
            } catch {
                await MainActor.run {
                    if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
                        ToastCenter.shared.info("No Internet Connection. Please check your connection and try again.")
                    } else {
                        ToastCenter.shared.error("Failed to load podcast: \(error.localizedDescription)")
                    }
                }
            }
            await MainActor.run {
                self.isFetchingFeed = false
            }
        }
    }

    private func upsertPodcast(_ incoming: Podcast) -> Podcast {
        let incomingID = incoming.id
        let descriptor = FetchDescriptor<Podcast>(predicate: #Predicate { $0.id == incomingID })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.title = incoming.title
            existing.author = incoming.author
            existing.artworkURL = incoming.artworkURL
            existing.feedURL = incoming.feedURL
            existing.podcastDescription = incoming.podcastDescription
            existing.categories = incoming.categories
            existing.lastRefreshed = incoming.lastRefreshed
            existing.isFollowing = incoming.isFollowing
            existing.dateFollowed = incoming.dateFollowed
            return existing
        }

        let stored = Podcast(
            id: incomingID,
            title: incoming.title,
            author: incoming.author,
            artworkURL: incoming.artworkURL,
            feedURL: incoming.feedURL,
            categories: incoming.categories,
            description: incoming.podcastDescription,
            lastRefreshed: incoming.lastRefreshed,
            isFollowing: incoming.isFollowing,
            dateFollowed: incoming.dateFollowed
        )
        modelContext.insert(stored)
        return stored
    }

    private func upsertEpisodes(_ episodes: [Episode], for podcast: Podcast) -> [Episode] {
        episodes.compactMap { incoming in
            let incomingID = incoming.id
            let descriptor = FetchDescriptor<Episode>(predicate: #Predicate { $0.id == incomingID })
            if let existing = try? modelContext.fetch(descriptor).first {
                existing.title = incoming.title
                existing.publishedAt = incoming.publishedAt
                existing.duration = incoming.duration
                existing.episodeDescription = incoming.episodeDescription
                existing.audioURL = incoming.audioURL
                existing.artworkURL = incoming.artworkURL
                existing.transcriptJSON = incoming.transcriptJSON
                existing.chaptersJSON = incoming.chaptersJSON
                existing.podcast = podcast
                return existing
            }

            let episode = Episode(
                id: incomingID,
                podcastID: incoming.podcastID,
                title: incoming.title,
                publishedAt: incoming.publishedAt,
                duration: incoming.duration,
                description: incoming.episodeDescription,
                audioURL: incoming.audioURL,
                artworkURL: incoming.artworkURL,
                localFileURL: incoming.localFileURL,
                playbackPositionSec: incoming.playbackPositionSec,
                isDownloaded: incoming.isDownloaded,
                downloadProgress: incoming.downloadProgress,
                dateAdded: incoming.dateAdded,
                lastPlayed: incoming.lastPlayed,
                isCompleted: incoming.isCompleted,
                transcriptJSON: incoming.transcriptJSON,
                chaptersJSON: incoming.chaptersJSON,
                playbackProgress: incoming.playbackProgress,
                lastPlayedDate: incoming.lastPlayedDate
            )
            episode.podcast = podcast
            modelContext.insert(episode)
            return episode
        }
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(HBFont.heading(20))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PodcastCard: View {
    let podcast: Podcast

    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: podcast.artworkURLValue) { phase in
                switch phase {
                case .empty: ProgressView().frame(width: 86, height: 86)
                case .success(let image): image.resizable().scaledToFill().frame(width: 86, height: 86)
                case .failure: Color.secondaryBackground.frame(width: 86, height: 86).overlay(Image(systemName: "waveform").foregroundColor(.secondaryText))
                @unknown default: Color.secondaryBackground.frame(width: 86, height: 86)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(podcast.title)
                    .font(HBFont.body(15, weight: .semibold))
                    .foregroundColor(.primaryText)
                    .lineLimit(2)
                Text(podcast.author)
                    .font(HBFont.body(12))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
                Text(podcast.podcastDescription)
                    .font(HBFont.body(12))
                    .foregroundColor(.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.secondaryBackground)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 6)
        )
    }
}

private struct PodcastDetailPayload: Identifiable, Hashable {
    let podcast: Podcast
    let episodes: [Episode]
    let suggestions: [Podcast]

    var id: String { podcast.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static func == (lhs: PodcastDetailPayload, rhs: PodcastDetailPayload) -> Bool {
        lhs.id == rhs.id
    }
}
