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

    static func importFiles(urls: [URL], context: ModelContext) async -> Int {
        guard !urls.isEmpty else { return 0 }
        var inserted = 0
        for url in urls {
            if await importFile(at: url, context: context) { inserted += 1 }
        }
        return inserted
    }

    static func scanLibraryFolder(context: ModelContext, progress: @escaping (Double) -> Void = { _ in }) async {
        try? FileManager.default.createDirectory(at: libraryFolderURL, withIntermediateDirectories: true)

        let urls = await Task.detached(priority: .utility) { () -> [URL] in
            let fm = FileManager.default
            let base = libraryFolderURL
            guard let items = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil) else { return [] }
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

    private static func importFile(at url: URL, context: ModelContext) async -> Bool {
        do {
            let (localURL, metadata) = try await Task.detached(priority: .utility) { () -> (URL, Metadata) in
                let local = try copyToLibrary(url: url)
                let meta = try await readMetadata(url: local)
                return (local, meta)
            }.value

            return try await MainActor.run { () -> Bool in
                return try persistSong(metadata: metadata, localURL: localURL, context: context)
            }
        } catch {
            print("Import error: \(error)")
            return false
        }
    }

    @MainActor
    private static func persistSong(metadata: Metadata, localURL: URL, context: ModelContext) throws -> Bool {
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

    static func copyToLibrary(url: URL) throws -> URL {
        let dest = libraryFolderURL.appendingPathComponent(url.lastPathComponent)
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
        _ = try await asset.load(.duration)

        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var artwork: Data? = nil

        for item in asset.metadata {
            guard let key = item.commonKey?.rawValue else { continue }
            switch key {
            case "title": if let v = item.stringValue { title = v }
            case "artist": if let v = item.stringValue { artist = v }
            case "albumName": if let v = item.stringValue { album = v }
            case "artwork": if let v = item.dataValue { artwork = v }
            default: break
            }
        }

        let duration = CMTimeGetSeconds(asset.duration)
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
