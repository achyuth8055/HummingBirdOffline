// Utilities/ImportCoordinator.swift
import Foundation
import SwiftData

enum ImportCoordinator {
    /// Imports songs from file URLs copying them into the managed Library folder.
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
}
