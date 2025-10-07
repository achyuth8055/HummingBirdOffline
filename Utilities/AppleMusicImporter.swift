//
//  AppleMusicImporter.swift
//  HummingBirdOffline
//
//  Handles importing songs from the user's Apple Music library using MPMediaPickerController

import SwiftUI
import MediaPlayer
import SwiftData
import AVFoundation

// MARK: - Apple Music Picker Representable

struct AppleMusicPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onComplete: ([MPMediaItem]) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onComplete: onComplete)
    }
    
    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.delegate = context.coordinator
        picker.allowsPickingMultipleItems = true
        picker.showsCloudItems = false // Only show downloaded items
        picker.prompt = "Select songs to import"
        return picker
    }
    
    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {}
    
    class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        @Binding var isPresented: Bool
        let onComplete: ([MPMediaItem]) -> Void
        
        init(isPresented: Binding<Bool>, onComplete: @escaping ([MPMediaItem]) -> Void) {
            self._isPresented = isPresented
            self.onComplete = onComplete
        }
        
        func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            isPresented = false
            onComplete(mediaItemCollection.items)
        }
        
        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            isPresented = false
            onComplete([])
        }
    }
}

// MARK: - Apple Music Import Service

@MainActor
final class AppleMusicImporter {
    
    enum ImportError: LocalizedError {
        case noPermission
        case exportFailed(String)
        case unsupportedFormat
        
        var errorDescription: String? {
            switch self {
            case .noPermission:
                return "Permission denied. Please enable Media Library access in Settings."
            case .exportFailed(let detail):
                return "Failed to export: \(detail)"
            case .unsupportedFormat:
                return "This song format is not supported or is DRM-protected."
            }
        }
    }
    
    /// Requests permission to access the user's media library
    static func requestPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    /// Checks current authorization status
    static func authorizationStatus() -> MPMediaLibraryAuthorizationStatus {
        return MPMediaLibrary.authorizationStatus()
    }
    
    /// Imports selected media items from Apple Music library into SwiftData
    static func importMediaItems(_ items: [MPMediaItem], context: ModelContext) async -> (imported: Int, skipped: Int, errors: [String]) {
        guard !items.isEmpty else { return (0, 0, []) }
        
        var imported = 0
        var skipped = 0
        var errors: [String] = []
        
        for item in items {
            do {
                let result = try await importSingleItem(item, context: context)
                if result {
                    imported += 1
                } else {
                    skipped += 1
                }
            } catch {
                errors.append("\(item.title ?? "Unknown"): \(error.localizedDescription)")
            }
        }
        
        return (imported, skipped, errors)
    }
    
    /// Imports a single media item
    private static func importSingleItem(_ item: MPMediaItem, context: ModelContext) async throws -> Bool {
        // Extract metadata
        guard let title = item.title else { throw ImportError.unsupportedFormat }
        
        let artist = item.artist ?? "Unknown Artist"
        let album = item.albumTitle ?? "Unknown Album"
        let duration = item.playbackDuration
        
        // Get artwork
        var artworkData: Data?
        if let artwork = item.artwork {
            let image = artwork.image(at: CGSize(width: 600, height: 600))
            artworkData = image?.jpegData(compressionQuality: 0.85)
        }
        
        // Try to get the asset URL
        guard let assetURL = item.assetURL else {
            // If no asset URL, the song is likely streaming-only or DRM-protected
            throw ImportError.unsupportedFormat
        }
        
        // Check if already exists using persistentID
        let itemID = item.persistentID
        let idString = String(itemID)
        
        let descriptor = FetchDescriptor<Song>(
            predicate: #Predicate<Song> { song in
                song.filePath.contains(idString)
            }
        )
        
        let existing = try context.fetch(descriptor)
        if !existing.isEmpty {
            return false // Already exists
        }
        
        // Export the audio file to our library folder
        let exportedURL = try await exportAudioFile(from: assetURL, itemID: idString)
        let relativePath = LibraryImportService.relativePath(for: exportedURL)
        
        // Create Song entity
        let artistEntity = LibraryImportService.fetchOrCreateArtist(name: artist, context: context)
        let albumEntity = LibraryImportService.fetchOrCreateAlbum(
            title: album,
            artist: artist,
            artwork: artworkData,
            context: context
        )
        
        let song = Song(
            title: title,
            artistName: artist,
            albumName: album,
            duration: duration,
            filePath: relativePath,
            artworkData: artworkData,
            artist: artistEntity,
            album: albumEntity
        )
        
        context.insert(song)
        try context.save()
        
        return true
    }
    
    /// Exports audio file from Apple Music library to app's library folder
    private static func exportAudioFile(from assetURL: URL, itemID: String) async throws -> URL {
        let asset = AVURLAsset(url: assetURL)
        
        // Create export session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ImportError.exportFailed("Could not create export session")
        }
        
        // Set up output URL
        let fileName = "\(itemID)_\(UUID().uuidString).m4a"
        let outputURL = LibraryImportService.libraryFolderURL.appendingPathComponent(fileName)
        
        // Remove if exists
        try? FileManager.default.removeItem(at: outputURL)
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        // Perform export
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            let error = exportSession.error?.localizedDescription ?? "Unknown error"
            throw ImportError.exportFailed(error)
        }
        
        return outputURL
    }
}
