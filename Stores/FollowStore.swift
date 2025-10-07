//
//  FollowStore.swift
//  HummingBirdOffline
//
//  Created by Achyuth on 06/10/25.
//


import Foundation

final class FollowStore {
    static let shared = FollowStore()
    private init() { load() }

    private let storageKey = "FollowedPodcasts.v1"
    private var followedFeedURLs = Set<String>()
    private(set) var followedPodcasts: [Podcast] = []

    private struct StoredPodcast: Codable {
        let id: String
        let title: String
        let author: String
        let artworkURL: String?
        let feedURL: String
        let categories: [String]
        let description: String
        let dateFollowed: Date?
    }

    func isFollowed(_ podcast: Podcast) -> Bool {
        followedFeedURLs.contains(podcast.feedURL)
    }

    func follow(_ podcast: Podcast) {
        let feed = podcast.feedURL
        let inserted = followedFeedURLs.insert(feed).inserted

        podcast.isFollowing = true
        if podcast.dateFollowed == nil { podcast.dateFollowed = Date() }

        if let index = followedPodcasts.firstIndex(where: { $0.feedURL == podcast.feedURL }) {
            followedPodcasts[index] = podcast
        } else {
            followedPodcasts.append(podcast)
        }

        if inserted {
            saveAndNotify()
        } else {
            followSort()
            persist()
            NotificationCenter.default.post(name: .podcastFollowDidChange, object: nil)
        }
    }

    func unfollow(_ podcast: Podcast) {
        let feed = podcast.feedURL
        guard followedFeedURLs.remove(feed) != nil else { return }
        followedPodcasts.removeAll { $0.feedURL == podcast.feedURL }
        podcast.isFollowing = false
        podcast.dateFollowed = nil
        saveAndNotify()
    }

    private func load() {
        defer { followedPodcasts.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending } }

        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? JSONDecoder().decode([StoredPodcast].self, from: data) {
            followedPodcasts = decoded.map { stored in
                let podcast = Podcast(
                    id: stored.id,
                    title: stored.title,
                    author: stored.author,
                    artworkURL: stored.artworkURL,
                    feedURL: stored.feedURL,
                    categories: stored.categories,
                    description: stored.description,
                    isFollowing: true,
                    dateFollowed: stored.dateFollowed
                )
                return podcast
            }
            followedFeedURLs = Set(decoded.map { $0.feedURL })
        }
    }

    private func saveAndNotify() {
        followSort()
        persist()
        NotificationCenter.default.post(name: .podcastFollowDidChange, object: nil)
    }

    private func persist() {
        let stored = followedPodcasts.map { podcast in
            StoredPodcast(
                id: podcast.id,
                title: podcast.title,
                author: podcast.author,
                artworkURL: podcast.artworkURL,
                feedURL: podcast.feedURL,
                categories: podcast.categories,
                description: podcast.podcastDescription,
                dateFollowed: podcast.dateFollowed
            )
        }

        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func followSort() {
        followedPodcasts.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}
