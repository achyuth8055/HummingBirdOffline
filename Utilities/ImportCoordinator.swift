// Utilities/ImportCoordinator.swift
import Foundation
import SwiftData

enum ImportCoordinator {
    @MainActor
    static func importSongs(from urls: [URL], context: ModelContext) async -> Int {
        guard !urls.isEmpty else { return 0 }
        return await LibraryImportService.importFiles(urls: urls, context: context)
    }
}
