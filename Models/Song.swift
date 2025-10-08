//
//  Song.swift
//  HummingBirdOffline
//
//
//  Song.swift
//

import Foundation
import SwiftData

// MARK: - SongSourceType
/// Represents the origin of an imported song. Stored as a raw String
/// in the model for SwiftData compatibility. Extend as needed when
/// adding additional cloud providers.
enum SongSourceType: String, Codable, CaseIterable {
    case local            // Imported from local Files / File Sharing
    case googleDrive      // Imported via Google Drive API
    case oneDrive         // Imported via Microsoft Graph / OneDrive
    case appleMusic       // Imported from the user's Apple Music library (downloaded DRM‐free copy)
    case unknown
}

@Model
final class Song {
    @Attribute(.unique) var persistentID: UUID
    var title: String
    var artistName: String
    var albumName: String
    var duration: Double
    var filePath: String
    var artworkData: Data?
    var dateAdded: Date
    var lastPlayed: Date?
    var playCount: Int
    var favorite: Bool
    var lyrics: String? // ADD THIS LINE

    // MARK: - Extended Source / Import Metadata
    /// Backing storage for `sourceType` (raw String for SwiftData)
    private var sourceTypeRaw: String
    /// Remote URL (cloud storage direct link or streaming URL) if the item originated remotely
    var remoteURL: String?
    /// Absolute on-disk path (if different from filePath relative location) for items placed outside the managed Library folder
    var localPath: String?
    /// Flag indicating file is fully available offline (copied into Library folder). For Apple Music / Cloud imports after download.
    var isDownloaded: Bool
    /// Saved playback position (seconds) for persistence between sessions (music audiobooks, long mixes, etc.)
    var playbackPositionSec: Double

    @Relationship(inverse: \Playlist.songs) var playlists: [Playlist] = []
    var artist: Artist?
    var album: Album?

    init(
        id: UUID = UUID(),
        title: String,
        artistName: String,
        albumName: String,
        duration: Double,
        filePath: String,
        artworkData: Data? = nil,
        dateAdded: Date = .now,
        lastPlayed: Date? = nil,
        playCount: Int = 0,
        favorite: Bool = false,
        sourceType: SongSourceType = .local,
        remoteURL: URL? = nil,
        localPath: URL? = nil,
        isDownloaded: Bool = true,
        playbackPositionSec: Double = 0,
        artist: Artist? = nil,
        album: Album? = nil
    ) {
        self.persistentID = id
        self.title = title
        self.artistName = artistName
        self.albumName = albumName
        self.duration = duration
        self.filePath = filePath
        self.artworkData = artworkData
        self.dateAdded = dateAdded
        self.lastPlayed = lastPlayed
        self.playCount = playCount
        self.favorite = favorite
        self.sourceTypeRaw = sourceType.rawValue
        self.remoteURL = remoteURL?.absoluteString
        self.localPath = localPath?.path
        self.isDownloaded = isDownloaded
        self.playbackPositionSec = playbackPositionSec
        self.artist = artist
        self.album = album
    }
}

// MARK: - Computed Accessors
extension Song {
    var sourceType: SongSourceType {
        get { SongSourceType(rawValue: sourceTypeRaw) ?? .unknown }
        set { sourceTypeRaw = newValue.rawValue }
    }
    
    var remoteURLValue: URL? { 
        remoteURL.flatMap { URL(string: $0) } 
    }
    
    var localPathURL: URL? { 
        localPath.flatMap { URL(fileURLWithPath: $0) } 
    }
    
    /// Returns true if this song is streamed from a cloud service
    var isStreamedFromCloud: Bool {
        return !isDownloaded && remoteURLValue != nil && (sourceType == .googleDrive || sourceType == .oneDrive)
    }
    
    /// Returns the playback URL - either local file or remote streaming URL
    var playbackURL: URL? {
        if isDownloaded, let localURL = localPathURL {
            return localURL
        }
        return remoteURLValue
    }
    
    /// Returns a user-friendly source description
    var sourceDescription: String {
        switch sourceType {
        case .local:
            return "Local File"
        case .googleDrive:
            return "Google Drive"
        case .oneDrive:
            return "OneDrive"
        case .appleMusic:
            return "Apple Music"
        case .unknown:
            return "Unknown"
        }
    }
    
    /// Returns true if the song requires network connectivity to play
    var requiresNetwork: Bool {
        return isStreamedFromCloud
    }
}
