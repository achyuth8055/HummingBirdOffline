import Foundation
import SwiftUI
import Combine

@MainActor
final class PodcastBrowseViewModel: ObservableObject {
    @Published private(set) var top: [Podcast] = []
    @Published private(set) var trending: [Podcast] = []
    @Published private(set) var results: [Podcast] = []
    @Published var searchTerm: String = ""
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var followed: [Podcast] = []

    private var searchTask: Task<Void, Never>? = nil
    private var followObserver: NSObjectProtocol?

    init() {
        followed = FollowStore.shared.followedPodcasts
        followObserver = NotificationCenter.default.addObserver(forName: .podcastFollowDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.followed = FollowStore.shared.followedPodcasts
        }
    }

    deinit {
        if let followObserver { NotificationCenter.default.removeObserver(followObserver) }
    }

    var recommended: [Podcast] {
        let followedIDs = Set(followed.map { $0.id })
        let base = (top + trending).filter { !followedIDs.contains($0.id) }
        let suggested = PodcastAPIService.suggested(excluding: followedIDs)
        var seen = Set<String>()
        return (base + suggested).filter { podcast in
            guard !seen.contains(podcast.id) else { return false }
            seen.insert(podcast.id)
            return true
        }
    }

    func loadTrending() {
        top = PodcastAPIService.topPodcasts()
        trending = PodcastAPIService.trendingPodcasts()
    }

    func updateSearchTerm(_ term: String) {
        searchTask?.cancel()
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = trimmed
        searchTerm = term
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            errorMessage = nil
            searchTask = nil
            return
        }
        isSearching = true
        errorMessage = nil
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard let self, !Task.isCancelled else { return }
            let remote = await PodcastService.search(term: query)
            if Task.isCancelled { return }
            let fallback = PodcastAPIService.search(term: query)
            let podcasts = remote.isEmpty ? fallback : remote
            await MainActor.run {
                self.results = podcasts
                self.isSearching = false
                self.searchTask = nil
                if podcasts.isEmpty {
                    self.errorMessage = "No podcasts found for \"\(query)\"."
                } else {
                    self.errorMessage = nil
                }
            }
        }
    }
}
