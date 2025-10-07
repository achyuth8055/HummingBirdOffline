import Foundation
import os
import Combine

enum PodcastFeedService {
    private static let logger = Logger(subsystem: "HummingBirdOffline", category: "PodcastFeedService")
    private static var cache: [String: CachedFeed] = [:]

    struct FeedResult {
        let podcast: Podcast
        let episodes: [Episode]
    }

    static func fetchFeed(for podcast: Podcast, forceRefresh: Bool = false) async throws -> FeedResult {
        if !forceRefresh, let cached = cache[podcast.feedURL], Date().timeIntervalSince(cached.timestamp) < 60 * 15 {
            return cached.result
        }

        guard let feedURL = podcast.feedURLValue else { throw FeedError.invalidURL }

        var request = URLRequest(url: feedURL)
        request.setValue("HummingBirdOffline/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            logger.error("Network error fetching podcast feed: \(error.localizedDescription)")
            throw FeedError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedError.badStatus
        }
        
        guard httpResponse.statusCode < 400 else {
            logger.error("Bad status code: \(httpResponse.statusCode)")
            throw FeedError.badStatus
        }

        let parser = RSSParser(podcast: podcast)
        let parsed = try parser.parse(data: data)
        cache[podcast.feedURL] = CachedFeed(result: parsed, timestamp: Date())
        return parsed
    }
}

private extension PodcastFeedService {
    struct CachedFeed {
        let result: PodcastFeedService.FeedResult
        let timestamp: Date
    }

    enum FeedError: LocalizedError {
        case badStatus
        case invalidXML
        case networkError(Error)
        case invalidURL
        
        var errorDescription: String? {
            switch self {
            case .badStatus:
                return "Failed to load podcast feed. The server returned an error."
            case .invalidXML:
                return "Failed to parse podcast feed. The feed format is invalid."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidURL:
                return "Invalid podcast feed URL."
            }
        }
    }

    final class RSSParser: NSObject, XMLParserDelegate {
        private var podcast: Podcast
        private var channelTitle: String = ""
        private var channelDescription: String = ""
        private var channelArtwork: URL?
        private var channelCategories: Set<String> = []

        private var episodes: [Episode] = []
        private var currentEpisode: EpisodeBuilder?
        private var currentElement: String = ""
        private var currentValue: String = ""

        init(podcast: Podcast) {
            self.podcast = podcast
        }

        func parse(data: Data) throws -> PodcastFeedService.FeedResult {
            let parser = XMLParser(data: data)
            parser.delegate = self
            guard parser.parse() else { throw FeedError.invalidXML }

            if !channelTitle.isEmpty { podcast.title = channelTitle }
            if let art = channelArtwork?.absoluteString { podcast.artworkURL = art }
            if !channelCategories.isEmpty { podcast.categories = Array(channelCategories) }
            if !channelDescription.isEmpty { podcast.podcastDescription = channelDescription }
            podcast.lastRefreshed = Date()
            let finalEpisodes = episodes.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
            return FeedResult(podcast: podcast, episodes: finalEpisodes)
        }

        // MARK: - XMLParserDelegate
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            currentElement = elementName.lowercased()
            currentValue = ""

            if currentElement == "item" { currentEpisode = EpisodeBuilder(podcastID: podcast.id) }

            if let enclosure = currentEpisode, currentElement == "enclosure", let urlString = attributeDict["url"], let url = URL(string: urlString) {
                currentEpisode = enclosure.settingAudioURL(url)
            }

            if currentElement == "itunes:image", let href = attributeDict["href"], let url = URL(string: href) {
                if currentEpisode != nil {
                    currentEpisode = currentEpisode?.settingArtwork(url)
                } else {
                    channelArtwork = url
                }
            }

            if currentElement == "podcast:transcript", let urlString = attributeDict["url"], let url = URL(string: urlString) {
                let type = attributeDict["type"]?.lowercased() ?? ""
                var format: Transcript.Format = .plain
                if type.contains("json") { format = .json }
                else if type.contains("vtt") { format = .webvtt }
                else if type.contains("srt") { format = .srt }
                currentEpisode = currentEpisode?.settingTranscript(Transcript(url: url, format: format, language: attributeDict["language"]))
            }

            if currentElement == "podcast:chapters", let urlString = attributeDict["url"], let url = URL(string: urlString) {
                currentEpisode = currentEpisode?.settingChaptersURL(url)
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currentValue += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            let trimmed = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let element = elementName.lowercased()

            switch element {
            case "title":
                if let builder = currentEpisode {
                    currentEpisode = builder.settingTitle(trimmed)
                } else {
                    channelTitle = trimmed
                }
            case "description", "itunes:summary":
                if let builder = currentEpisode {
                    currentEpisode = builder.settingDescription(trimmed)
                } else {
                    channelDescription = trimmed
                }
            case "itunes:author", "author":
                if let builder = currentEpisode {
                    currentEpisode = builder.settingAuthor(trimmed)
                } else {
                    podcast.author = trimmed
                }
            case "guid":
                currentEpisode = currentEpisode?.settingID(trimmed)
            case "link":
                currentEpisode = currentEpisode?.settingLink(trimmed)
            case "pubdate":
                currentEpisode = currentEpisode?.settingPublished(trimmed)
            case "itunes:duration":
                currentEpisode = currentEpisode?.settingDuration(trimmed)
            case "category", "itunes:category":
                channelCategories.insert(trimmed)
            case "item":
                if let finished = currentEpisode?.build() {
                    episodes.append(finished)
                }
                currentEpisode = nil
            default: break
            }
        }
    }
}

private extension PodcastFeedService.RSSParser {
    struct EpisodeBuilder {
        let podcastID: String
        var id: String = UUID().uuidString
        var title: String = ""
        var description: String = ""
        var author: String = ""
        var published: Date?
        var duration: TimeInterval?
        var audioURL: String?
        var artworkURL: String?
        var transcript: Transcript?
        var chapters: [Chapter] = []
        var chaptersURL: URL?

        func settingTitle(_ value: String) -> EpisodeBuilder { var copy = self; copy.title = value; return copy }
        func settingDescription(_ value: String) -> EpisodeBuilder { var copy = self; copy.description = value; return copy }
        func settingAuthor(_ value: String) -> EpisodeBuilder { var copy = self; copy.author = value; return copy }
        func settingID(_ value: String) -> EpisodeBuilder { var copy = self; copy.id = value; return copy }
        func settingLink(_ value: String) -> EpisodeBuilder { var copy = self; if copy.audioURL == nil { copy.audioURL = value }; return copy }
        func settingPublished(_ value: String) -> EpisodeBuilder { var copy = self; copy.published = DateFormatter.rfc2822.date(from: value) ?? ISO8601DateFormatter().date(from: value); return copy }
        func settingDuration(_ value: String) -> EpisodeBuilder { var copy = self; copy.duration = TimeInterval.fromHMS(value); return copy }
        func settingAudioURL(_ url: URL) -> EpisodeBuilder { var copy = self; copy.audioURL = url.absoluteString; return copy }
        func settingArtwork(_ url: URL) -> EpisodeBuilder { var copy = self; copy.artworkURL = url.absoluteString; return copy }
        func settingTranscript(_ transcript: Transcript) -> EpisodeBuilder { var copy = self; copy.transcript = transcript; return copy }
        func settingChaptersURL(_ url: URL) -> EpisodeBuilder { var copy = self; copy.chaptersURL = url; return copy }

        func build() -> Episode? {
            guard let audioURL else { return nil }
            let episode = Episode(
                id: id,
                podcastID: podcastID,
                title: title.isEmpty ? "Untitled" : title,
                publishedAt: published,
                duration: duration,
                description: description,
                audioURL: audioURL,
                artworkURL: artworkURL
            )
            episode.transcript = transcript
            episode.chapters = chapters
            return episode
        }
    }
}

private extension DateFormatter {
    static let rfc2822: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter
    }()
}

private extension TimeInterval {
    static func fromHMS(_ string: String) -> TimeInterval? {
        let parts = string.split(separator: ":").reversed()
        var total: TimeInterval = 0
        for (index, part) in parts.enumerated() {
            guard let value = Double(part) else { continue }
            total += value * pow(60, Double(index))
        }
        return total > 0 ? total : nil
    }
}
