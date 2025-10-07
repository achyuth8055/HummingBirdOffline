import Foundation
import os
import Combine

enum PodcastService {
    private static let logger = Logger(subsystem: "HummingBirdOffline", category: "PodcastService")
    private static let itunesSearchURL = URL(string: "https://itunes.apple.com/search")!
    private static let itunesLookupURL = URL(string: "https://itunes.apple.com/lookup")!
    private static let topChartsURL = URL(string: "https://itunes.apple.com/us/rss/toppodcasts/limit=50/json")!

    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private static var cache = PodcastCache()
    private static var throttler = RequestThrottler(limitPerMinute: 20)

    static func topPodcasts() async -> [Podcast] {
        if let cached = cache.cachedTop, !cached.isEmpty, cache.topExpiry > Date() { return cached }
        do {
            try await throttler.waitIfNeeded(for: topChartsURL.absoluteString)
            let (data, _) = try await URLSession.shared.data(from: topChartsURL)
            let response = try jsonDecoder.decode(ITunesTopResponse.self, from: data)
            var podcasts: [Podcast] = []
            for result in response.feed.results {
                do {
                    if let podcast = try await lookupPodcast(collectionID: result.id) {
                        podcasts.append(podcast)
                    }
                } catch {
                    logger.error("Lookup failed for id \(result.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
            if podcasts.isEmpty { podcasts = cache.cachedTop ?? [] }
            cache.cachedTop = podcasts
            cache.topExpiry = Date().addingTimeInterval(600)
            return podcasts
        } catch {
            logger.error("Failed to load top podcasts: \(error.localizedDescription, privacy: .public)")
            return cache.cachedTop ?? []
        }
    }

    static func search(term: String) async -> [Podcast] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if let cached = cache.searchResults[trimmed], Date().timeIntervalSince(cached.timestamp) < 300 {
            return cached.podcasts
        }

        var components = URLComponents(url: itunesSearchURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "media", value: "podcast"),
            URLQueryItem(name: "term", value: trimmed),
            URLQueryItem(name: "entity", value: "podcast"),
            URLQueryItem(name: "limit", value: "50")
        ]

        guard let url = components?.url else { return [] }

        do {
            try await throttler.waitIfNeeded(for: url.absoluteString)
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try jsonDecoder.decode(ITunesSearchResponse.self, from: data)
            let podcasts = response.results.compactMap { $0.podcast }
            cache.searchResults[trimmed] = PodcastCache.SearchResult(podcasts: podcasts, timestamp: Date())
            return podcasts
        } catch {
            logger.error("Podcast search failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private static func lookupPodcast(collectionID: String) async throws -> Podcast? {
        var components = URLComponents(url: itunesLookupURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "id", value: collectionID)]
        guard let url = components?.url else { return nil }
        try await throttler.waitIfNeeded(for: url.absoluteString)
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try jsonDecoder.decode(ITunesSearchResponse.self, from: data)
        return response.results.compactMap { $0.podcast }.first
    }
}

// MARK: - Cache / Throttle
private struct PodcastCache {
    struct SearchResult {
        let podcasts: [Podcast]
        let timestamp: Date
    }
    var cachedTop: [Podcast]? = nil
    var topExpiry: Date = .distantPast
    var searchResults: [String: SearchResult] = [:]
}

private actor RequestThrottler {
    private let limitPerMinute: Int
    private var timestamps: [String: [Date]] = [:]

    init(limitPerMinute: Int) {
        self.limitPerMinute = limitPerMinute
    }

    func waitIfNeeded(for key: String) async throws {
        let now = Date()
        var list = timestamps[key, default: []].filter { now.timeIntervalSince($0) < 60 }
        if list.count >= limitPerMinute, let first = list.first {
            let delay = 60 - now.timeIntervalSince(first)
            try await Task.sleep(nanoseconds: UInt64(max(delay, 0) * 1_000_000_000))
            list = list.filter { Date().timeIntervalSince($0) < 60 }
        }
        list.append(now)
        timestamps[key] = list
    }
}

// MARK: - DTOs
private struct ITunesSearchResponse: Decodable {
    let results: [ITunesPodcastDTO]
}

private struct ITunesTopResponse: Decodable {
    let feed: Feed
    struct Feed: Decodable {
        let results: [ITunesTopPodcastDTO]
    }
}

private struct ITunesPodcastDTO: Decodable {
    let collectionName: String
    let artistName: String
    let artworkUrl600: String?
    let primaryGenreName: String?
    let genres: [String]?
    let feedUrl: String?
    let collectionId: Int
    let description: String?

    var podcast: Podcast? {
        guard let feed = feedUrl else { return nil }
        let podcast = Podcast(
            id: feed,
            title: collectionName,
            author: artistName,
            artworkURL: artworkUrl600,
            feedURL: feed,
            categories: genres ?? (primaryGenreName.map { [$0] } ?? []),
            description: description ?? ""
        )
        return podcast
    }
}

private struct ITunesTopPodcastDTO: Decodable {
    let id: String
    let name: String
    let artistName: String
    let artworkUrl100: String
    let url: String
}
