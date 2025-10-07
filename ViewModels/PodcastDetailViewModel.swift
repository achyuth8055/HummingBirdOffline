import Foundation
import SwiftUI
import Combine

@MainActor
final class PodcastDetailViewModel: ObservableObject {
    struct EpisodeItem: Identifiable, Hashable {
        let id: String
        var episode: Episode
        var downloadState: EpisodeDownloadState = .notStarted

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: EpisodeItem, rhs: EpisodeItem) -> Bool {
            lhs.id == rhs.id
        }
    }

    @Published private(set) var podcast: Podcast
    @Published private(set) var episodes: [EpisodeItem] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSubscribed: Bool = false

    private let feedService = PodcastFeedService.self
    private var downloadObservation: AnyCancellable?
    private var followObservation: AnyCancellable?

    init(podcast: Podcast) {
        self.podcast = podcast
        self.isSubscribed = FollowStore.shared.isFollowed(podcast)
        self.podcast.isFollowing = self.isSubscribed
        observeDownloads()
        observeFollowChanges()
        loadFeed(force: false)
    }

    func loadFeed(force: Bool) {
        isLoading = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await feedService.fetchFeed(for: podcast, forceRefresh: force)
                await MainActor.run {
                    self.podcast = result.podcast
                    self.isSubscribed = FollowStore.shared.isFollowed(result.podcast)
                    self.podcast.isFollowing = self.isSubscribed
                    self.episodes = result.episodes.map { episode in
                        let state = EpisodeDownloadManager.shared.states[episode.audioURL] ?? {
                            if let localURL = episode.localFileURLValue {
                                return .completed(url: localURL)
                            }
                            return .notStarted
                        }()
                        return EpisodeItem(id: episode.id, episode: episode, downloadState: state)
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func toggleSubscribe() {
        isSubscribed.toggle()
        if isSubscribed {
            podcast.isFollowing = true
            podcast.dateFollowed = Date()
            FollowStore.shared.follow(podcast)
            ToastCenter.shared.success("Following \(podcast.title)")
        } else {
            podcast.isFollowing = false
            podcast.dateFollowed = nil
            FollowStore.shared.unfollow(podcast)
            ToastCenter.shared.info("Unfollowed \(podcast.title)")
        }
    }

    func play(_ episodeItem: EpisodeItem) {
        let hasLocalFile = episodeItem.episode.localFileURLValue != nil
        let hasRemoteURL = URL(string: episodeItem.episode.audioURL) != nil

        guard hasLocalFile || hasRemoteURL else {
            ToastCenter.shared.error("Episode unavailable")
            return
        }
        let ordered = episodes.map { $0.episode }
        PodcastPlayerViewModel.shared.play(episode: episodeItem.episode, in: ordered)
    }

    func download(_ episodeItem: EpisodeItem) {
        EpisodeDownloadManager.shared.startDownload(for: episodeItem.episode)
    }

    func cancelDownload(_ episodeItem: EpisodeItem) {
        EpisodeDownloadManager.shared.cancelDownload(for: episodeItem.episode)
    }

    private func observeDownloads() {
        downloadObservation = EpisodeDownloadManager.shared.$states
            .receive(on: DispatchQueue.main)
            .sink { [weak self] states in
                guard let self else { return }
                self.episodes = self.episodes.map { item in
                    var copy = item
                    copy.downloadState = states[item.episode.audioURL] ?? copy.downloadState
                    switch copy.downloadState {
                    case .completed(let url):
                        copy.episode.localFileURL = url.path
                        copy.episode.isDownloaded = true
                        copy.episode.downloadProgress = 1.0
                    case .inProgress(let progress):
                        copy.episode.downloadProgress = progress
                        copy.episode.isDownloaded = false
                    case .failed:
                        copy.episode.isDownloaded = false
                    case .notStarted:
                        copy.episode.isDownloaded = false
                        copy.episode.downloadProgress = 0
                    }
                    return copy
                }
            }
    }

    private func observeFollowChanges() {
        followObservation = NotificationCenter.default.publisher(for: .podcastFollowDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.isSubscribed = FollowStore.shared.isFollowed(self.podcast)
                self.podcast.isFollowing = self.isSubscribed
            }
    }
}
