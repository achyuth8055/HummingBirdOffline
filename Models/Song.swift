//
//  Song.swift
//  HummingBirdOffline
//
//
//  Song.swift
//

import Foundation
import SwiftData

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
        self.artist = artist
        self.album = album
    }
}
