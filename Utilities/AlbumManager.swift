import Foundation
import Combine
import SwiftUI
import SwiftData

/// Central manager for album-level editing operations (custom artwork, grouping duplicates).
@MainActor
final class AlbumManager: ObservableObject {
    static let shared = AlbumManager()
    @Published private(set) var albums: [Album] = []
    @Published var duplicateGroups: [[Album]] = [] // groups of albums considered duplicates

    private init() {}

    func refresh(context: ModelContext) {
        let descriptor = FetchDescriptor<Album>()
        if let fetched = try? context.fetch(descriptor) {
            albums = fetched
            recomputeDuplicateGroups()
            autoGroupAlbums(context: context)
        }
    }
    
    /// Automatically group songs from the same album/movie into collections
    func autoGroupAlbums(context: ModelContext) {
        let songDescriptor = FetchDescriptor<Song>()
        guard let allSongs = try? context.fetch(songDescriptor) else { return }
        
        // Group songs by album name and artist
        let grouped = Dictionary(grouping: allSongs) { song in
            AlbumKey(
                albumName: song.albumName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                artistName: song.artistName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            )
        }
        
        // Create or update albums for each group
        for (key, songs) in grouped where !key.albumName.isEmpty && songs.count > 0 {
            // Precompute normalized keys since #Predicate does not allow calling lowercased() on model properties
            let normalizedAlbum = key.albumName
            let normalizedArtist = key.artistName
            let albumDescriptor = FetchDescriptor<Album>(
                predicate: #Predicate<Album> { album in
                    album.title == normalizedAlbum &&
                    album.artistName == normalizedArtist
                }
            )
            
            let existingAlbum = try? context.fetch(albumDescriptor).first
            
            if let album = existingAlbum {
                // Update existing album
                for song in songs {
                    song.album = album
                }
                
                // Update artwork if not present
                if album.artworkData == nil {
                    if let firstSongWithArt = songs.first(where: { $0.artworkData != nil }) {
                        album.artworkData = firstSongWithArt.artworkData
                    }
                }
            } else {
                // Create new album
                let newAlbum = Album(
                    title: songs[0].albumName,
                    artistName: songs[0].artistName,
                    artworkData: songs.first(where: { $0.artworkData != nil })?.artworkData
                )
                context.insert(newAlbum)
                
                // Link songs to album
                for song in songs {
                    song.album = newAlbum
                }
            }
        }
        
        try? context.save()
        refresh(context: context)
    }

    func updateArtwork(for album: Album, image: UIImage, context: ModelContext) {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        album.artworkData = data
        try? context.save()
        refresh(context: context)
    }

    /// Merge songs from source albums into the first album in each group (simplistic grouping strategy).
    func mergeDuplicateGroup(_ group: [Album], context: ModelContext) {
        guard group.count > 1 else { return }
        guard let primary = group.first else { return }
        let rest = group.dropFirst()
        for other in rest {
            for song in other.songs { song.album = primary }
            context.delete(other)
        }
        try? context.save()
        refresh(context: context)
    }

    private func recomputeDuplicateGroups() {
        let keyGroups = Dictionary(grouping: albums) { (a: Album) in
            a.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() + "::" + a.artistName.lowercased()
        }
        duplicateGroups = keyGroups.values.filter { $0.count > 1 }.map { Array($0) }
    }
}

// MARK: - Album Key
private struct AlbumKey: Hashable {
    let albumName: String
    let artistName: String
}
