// Utilities/ImportCoordinator.swift
import Foundation
import SwiftData
import AVFoundation

enum ImportCoordinator {
    
    // MARK: - Streaming Import Methods
    
    /// Imports streaming songs from cloud services with metadata.
    /// - Parameters:
    ///   - streamingItems: Array of streaming metadata dictionaries
    ///   - context: SwiftData model context
    /// - Returns: Count of newly inserted songs
    @MainActor
    static func importStreamingSongs(
        from streamingItems: [(url: URL, metadata: [String: Any])],
        context: ModelContext
    ) async -> Int {
        guard !streamingItems.isEmpty else { return 0 }
        
        var importedCount = 0
        
        for (streamingURL, metadata) in streamingItems {
            // Extract metadata
            let title = metadata["title"] as? String ?? streamingURL.lastPathComponent
            let sourceType = SongSourceType(rawValue: metadata["sourceType"] as? String ?? "unknown") ?? .unknown
            let remoteURL = streamingURL.absoluteString
            let fileID = metadata["fileID"] as? String ?? metadata["itemID"] as? String
            let size = metadata["size"] as? Int64 ?? 0
            
            // Create a placeholder file path for the song
            let placeholderPath = "streaming/\(sourceType.rawValue)/\(fileID ?? UUID().uuidString)"
            
            // Try to extract additional metadata using AVAsset if possible
            let asset = AVAsset(url: streamingURL)
            let metadata = try? await extractMetadata(from: asset)
            
            let song = Song(
                title: metadata?.title ?? title,
                artistName: metadata?.artist ?? "Unknown Artist",
                albumName: metadata?.album ?? "Unknown Album",
                duration: metadata?.duration ?? 0,
                filePath: placeholderPath,
                artworkData: metadata?.artworkData,
                sourceType: sourceType,
                remoteURL: streamingURL,
                localPath: nil,
                isDownloaded: false
            )
            
            context.insert(song)
            importedCount += 1
        }
        
        // Save the context
        do {
            try context.save()
        } catch {
            print("Failed to save streaming songs: \(error)")
        }
        
        return importedCount
    }
    
    /// Legacy method: Imports songs from file URLs copying them into the managed Library folder.
    /// - Parameters:
    ///   - urls: Source URLs (security scoped if from FileImporter).
    ///   - context: SwiftData model context.
    ///   - assumedSource: Optional explicit source type override (.googleDrive, .oneDrive, etc.).
    /// - Returns: Count of newly inserted songs.
    @MainActor
    static func importSongs(from urls: [URL], context: ModelContext, assumedSource: SongSourceType? = nil) async -> Int {
        guard !urls.isEmpty else { return 0 }
        return await LibraryImportService.importFiles(urls: urls, context: context, assumedSource: assumedSource)
    }
    
    // MARK: - Cloud Service Import Helpers
    
    /// Import from Google Drive using DriveServiceManager
    @MainActor
    static func importFromGoogleDrive(fileIDs: [String], context: ModelContext) async -> Int {
        let driveManager = DriveServiceManager.shared
        guard driveManager.isAuthorized else { return 0 }
        
        let selectedFiles = driveManager.files.filter { fileIDs.contains($0.id) && $0.type == .audio }
        let streamingItems = selectedFiles.compactMap { driveManager.getStreamingInfo(for: $0) }
        
        return await importStreamingSongs(from: streamingItems, context: context)
    }
    
    /// Import from OneDrive using OneDriveServiceManager
    @MainActor
    static func importFromOneDrive(itemIDs: [String], context: ModelContext) async -> Int {
        let oneDriveManager = OneDriveServiceManager.shared
        guard oneDriveManager.isAuthorized else { return 0 }
        
        let selectedItems = oneDriveManager.items.filter { itemIDs.contains($0.id) && $0.type == .audio }
        let streamingItems = selectedItems.compactMap { oneDriveManager.getStreamingInfo(for: $0) }
        
        return await importStreamingSongs(from: streamingItems, context: context)
    }
    
    // MARK: - Metadata Extraction
    
    private static func extractMetadata(from asset: AVAsset) async throws -> (title: String?, artist: String?, album: String?, duration: Double, artworkData: Data?)? {
        // Load metadata asynchronously
        let commonMetadata = try await asset.load(.commonMetadata)
        let duration = try await asset.load(.duration)
        
        var title: String?
        var artist: String?
        var album: String?
        var artworkData: Data?
        
        for item in commonMetadata {
            guard let key = item.commonKey?.rawValue,
                  let value = try? await item.load(.value) else { continue }
            
            switch key {
            case "title":
                title = value as? String
            case "artist":
                artist = value as? String
            case "albumName":
                album = value as? String
            case "artwork":
                if let data = value as? Data {
                    artworkData = data
                }
            default:
                break
            }
        }
        
        return (
            title: title,
            artist: artist,
            album: album,
            duration: duration.seconds,
            artworkData: artworkData
        )
    }
}
