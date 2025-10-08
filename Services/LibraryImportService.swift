//
//  LibraryImportService.swift
//

import Foundation
import AVFoundation
import SwiftData

enum LibraryImportError: Error, LocalizedError {
    case copyFailed, metadataFailed
    var errorDescription: String? {
        switch self {
        case .copyFailed: return "Couldn't copy the file into your library."
        case .metadataFailed: return "Couldn't read audio metadata."
        }
    }
}

struct LibraryImportService {
    static let libraryFolderName = "Library"

    static var libraryFolderURL: URL {
        let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = doc.appendingPathComponent(libraryFolderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    static func relativePath(for url: URL) -> String {
        url.path.replacingOccurrences(of: libraryFolderURL.path + "/", with: "")
    }

    static func importFiles(urls: [URL], context: ModelContext, assumedSource: SongSourceType? = nil) async -> Int {
        guard !urls.isEmpty else { return 0 }
        var inserted = 0
        for url in urls {
            if await importFile(at: url, context: context, assumedSource: assumedSource) { inserted += 1 }
        }
        return inserted
    }

    static func scanLibraryFolder(context: ModelContext, progress: @escaping (Double) -> Void = { _ in }) async {
        let baseFolder = libraryFolderURL
        try? FileManager.default.createDirectory(at: baseFolder, withIntermediateDirectories: true)

        let urls = await Task.detached(priority: .utility) { () -> [URL] in
            let fm = FileManager()
            guard let items = try? fm.contentsOfDirectory(at: baseFolder, includingPropertiesForKeys: nil) else { return [] }
            let audioExts = Set(["mp3", "m4a", "aac", "wav", "aiff", "flac"])
            return items.filter { audioExts.contains($0.pathExtension.lowercased()) }
        }.value

        guard !urls.isEmpty else {
            await MainActor.run { progress(1.0) }
            return
        }

        await MainActor.run { progress(0) }

        var processed = 0
        for url in urls {
            _ = await importFile(at: url, context: context)
            processed += 1
            let fraction = Double(processed) / Double(urls.count)
            await MainActor.run { progress(fraction) }
        }
    }

    private static func importFile(at url: URL, context: ModelContext, assumedSource: SongSourceType? = nil) async -> Bool {
        let baseFolder = libraryFolderURL
        do {
            let (localURL, metadata) = try await Task.detached(priority: .utility) { () async throws -> (URL, Metadata) in
                let local = try await MainActor.run { try copyToLibrary(url: url, libraryFolder: baseFolder) }
                let meta = try await readMetadata(url: local)
                return (local, meta)
            }.value

            return try await MainActor.run { () -> Bool in
                return try persistSong(metadata: metadata, localURL: localURL, context: context, assumedSource: assumedSource)
            }
        } catch {
            print("Import error: \(error)")
            return false
        }
    }

    @MainActor
    private static func persistSong(metadata: Metadata, localURL: URL, context: ModelContext, assumedSource: SongSourceType? = nil) throws -> Bool {
        let artist = fetchOrCreateArtist(name: metadata.artist, context: context)
        let album = fetchOrCreateAlbum(title: metadata.album, artist: metadata.artist, artwork: metadata.artwork, context: context)

        let rel = relativePath(for: localURL)
        let existing: [Song] = try context.fetch(FetchDescriptor<Song>(predicate: #Predicate { $0.filePath == rel }))

        if existing.isEmpty {
            let song = Song(
                title: metadata.title,
                artistName: metadata.artist,
                albumName: metadata.album,
                duration: metadata.duration,
                filePath: rel,
                artworkData: metadata.artwork,
                sourceType: assumedSource ?? .local,
                remoteURL: nil,
                localPath: localURL,
                isDownloaded: true,
                playbackPositionSec: 0,
                artist: artist,
                album: album
            )
            context.insert(song)
            try? context.save()
            return true
        } else {
            try? context.save()
            return false
        }
    }

    @MainActor
    static func copyToLibrary(url: URL, libraryFolder: URL) throws -> URL {
        let dest = libraryFolder.appendingPathComponent(url.lastPathComponent)
        if !FileManager.default.fileExists(atPath: dest.path) {
            let started = url.startAccessingSecurityScopedResource()
            defer { if started { url.stopAccessingSecurityScopedResource() } }
            do { try FileManager.default.copyItem(at: url, to: dest) }
            catch { throw LibraryImportError.copyFailed }
        }
        return dest
    }

    struct Metadata: Sendable {
        let title: String, artist: String, album: String
        let artwork: Data?, duration: Double
    }

    static func readMetadata(url: URL) async throws -> Metadata {
        let asset = AVURLAsset(url: url)
        let durationTime = try await asset.load(.duration)

        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var artwork: Data? = nil

        let metadataItems = try await asset.load(.metadata)
        for item in metadataItems {
            guard let key = item.commonKey?.rawValue else { continue }
            switch key {
            case "title":
                if let stringValue: String = try? await item.load(.stringValue) {
                    title = stringValue
                }
            case "artist":
                if let stringValue: String = try? await item.load(.stringValue) {
                    artist = stringValue
                }
            case "albumName":
                if let stringValue: String = try? await item.load(.stringValue) {
                    album = stringValue
                }
            case "artwork":
                if let dataValue: Data = try? await item.load(.dataValue) {
                    artwork = dataValue
                }
            default: break
            }
        }

        let duration = CMTimeGetSeconds(durationTime)
        return Metadata(title: title, artist: artist, album: album, artwork: artwork, duration: duration.isFinite ? duration : 0)
    }

    @MainActor
    static func fetchOrCreateArtist(name: String, context: ModelContext) -> Artist {
        if let a = try? context.fetch(FetchDescriptor<Artist>(predicate: #Predicate { $0.name == name })).first { return a }
        let artist = Artist(name: name)
        context.insert(artist)
        return artist
    }

    @MainActor
    static func fetchOrCreateAlbum(title: String, artist: String, artwork: Data?, context: ModelContext) -> Album {
        if let a = try? context.fetch(FetchDescriptor<Album>(predicate: #Predicate { $0.title == title && $0.artistName == artist })).first { return a }
        let album = Album(title: title, artistName: artist, artworkData: artwork)
        context.insert(album)
        return album
    }
}
