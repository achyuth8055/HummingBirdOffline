//
//  Podcast.swift
//  HummingBirdOffline
//

import Foundation
import SwiftData

@Model
final class Podcast {
    @Attribute(.unique) var id: String  // Feed URL as unique identifier
    var title: String
    var author: String
    var artworkURL: String?  // Store as String for SwiftData compatibility
    var feedURL: String
    var categories: [String]
    var podcastDescription: String  // Renamed to avoid conflicts
    var lastRefreshed: Date
    var isFollowing: Bool  // Track if user follows this podcast
    var dateFollowed: Date?
    
    @Relationship(deleteRule: .cascade, inverse: \Episode.podcast)
    var episodes: [Episode] = []
    
    init(
        id: String,
        title: String,
        author: String,
        artworkURL: String? = nil,
        feedURL: String,
        categories: [String] = [],
        description: String = "",
        lastRefreshed: Date = Date(),
        isFollowing: Bool = false,
        dateFollowed: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.artworkURL = artworkURL
        self.feedURL = feedURL
        self.categories = categories
        self.podcastDescription = description
        self.lastRefreshed = lastRefreshed
        self.isFollowing = isFollowing
        self.dateFollowed = dateFollowed
    }
    
    // Helper computed property for URL conversion
    var artworkURLValue: URL? {
        guard let urlString = artworkURL else { return nil }
        return URL(string: urlString)
    }
    
    var feedURLValue: URL? {
        return URL(string: feedURL)
    }
}

@Model
final class Episode {
    @Attribute(.unique) var id: String
    var podcastID: String
    var title: String
    var publishedAt: Date?
    var duration: TimeInterval?
    var episodeDescription: String
    var audioURL: String
    var artworkURL: String?
    var localFileURL: String?  // Path to downloaded file
    var playbackPositionSec: TimeInterval
    var isDownloaded: Bool
    var downloadProgress: Double  // 0.0 to 1.0
    var dateAdded: Date
    var lastPlayed: Date?
    var isCompleted: Bool  // Marked as completed if played past 95%
    var playbackProgress: Double
    var lastPlayedDate: Date?
    
    // Transcript and chapter data stored as JSON strings
    var transcriptJSON: String?  // JSON encoded Transcript
    var chaptersJSON: String?  // JSON encoded [Chapter]
    
    @Relationship var podcast: Podcast?
    
    init(
        id: String,
        podcastID: String,
        title: String,
        publishedAt: Date? = nil,
        duration: TimeInterval? = nil,
        description: String = "",
        audioURL: String,
        artworkURL: String? = nil,
        localFileURL: String? = nil,
        playbackPositionSec: TimeInterval = 0,
        isDownloaded: Bool = false,
        downloadProgress: Double = 0,
        dateAdded: Date = Date(),
        lastPlayed: Date? = nil,
        isCompleted: Bool = false,
        transcriptJSON: String? = nil,
        chaptersJSON: String? = nil,
        playbackProgress: Double = 0,
        lastPlayedDate: Date? = nil
    ) {
        self.id = id
        self.podcastID = podcastID
        self.title = title
        self.publishedAt = publishedAt
        self.duration = duration
        self.episodeDescription = description
        self.audioURL = audioURL
        self.artworkURL = artworkURL
        self.localFileURL = localFileURL
        self.playbackPositionSec = playbackPositionSec
        self.isDownloaded = isDownloaded
        self.downloadProgress = downloadProgress
        self.dateAdded = dateAdded
        self.lastPlayed = lastPlayed
        self.isCompleted = isCompleted
        self.transcriptJSON = transcriptJSON
        self.chaptersJSON = chaptersJSON
        self.playbackProgress = playbackProgress
        self.lastPlayedDate = lastPlayedDate
    }
    
    // Helper computed properties
    var audioURLValue: URL? {
        return URL(string: audioURL)
    }
    
    var artworkURLValue: URL? {
        guard let urlString = artworkURL else { return nil }
        return URL(string: urlString)
    }
    
    var localFileURLValue: URL? {
        guard let path = localFileURL else { return nil }
        return URL(fileURLWithPath: path)
    }
    
    // Progress percentage (0-100)
    var progressPercentage: Double {
        guard let duration = duration, duration > 0 else { return 0 }
        return (playbackPositionSec / duration) * 100
    }
    
    // Remaining time in seconds
    var remainingTime: TimeInterval {
        guard let duration = duration else { return 0 }
        return max(0, duration - playbackPositionSec)
    }
}

// MARK: - Supporting Types for Transcript and Chapters

struct Transcript: Codable, Hashable {
    enum Format: String, Codable {
        case json, webvtt, srt, plain
    }
    
    let url: URL
    let format: Format
    let language: String?
}

struct Chapter: Codable, Hashable {
    let startTime: TimeInterval
    let title: String
    let imageURL: URL?
    
    init(startTime: TimeInterval, title: String, imageURL: URL? = nil) {
        self.startTime = startTime
        self.title = title
        self.imageURL = imageURL
    }
}

// MARK: - Episode Extensions for Transcript/Chapter Handling

extension Episode {
    var transcript: Transcript? {
        get {
            guard let json = transcriptJSON,
                  let data = json.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(Transcript.self, from: data)
        }
        set {
            if let transcript = newValue,
               let data = try? JSONEncoder().encode(transcript),
               let json = String(data: data, encoding: .utf8) {
                transcriptJSON = json
            } else {
                transcriptJSON = nil
            }
        }
    }
    
    var chapters: [Chapter] {
        get {
            guard let json = chaptersJSON,
                  let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([Chapter].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                chaptersJSON = json
            } else {
                chaptersJSON = nil
            }
        }
    }
}
