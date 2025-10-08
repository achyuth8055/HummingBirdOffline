import Foundation
import SwiftData
import SwiftUI
import MediaPlayer
import Combine

// MARK: - ImportViewModel
// Central coordinator for import sources (Files, Apple Music, Google Drive, OneDrive)
// Bridges UI with service managers & LibraryImportService. Real cloud implementations
// should replace stub managers with actual network/auth logic.

@MainActor
final class ImportViewModel: ObservableObject {
    // MARK: - Published UI State
    @Published var showFileImporter = false
    @Published var showAppleMusicPicker = false
    @Published var isScanningLocal = false
    @Published var localScanProgress: Double = 0
    
    // Cloud states
    @Published private(set) var driveManager = DriveServiceManager.shared
    @Published private(set) var oneDriveManager = OneDriveServiceManager.shared
    
    // Apple Music
    @Published var appleMusicAuthStatus: MPMediaLibraryAuthorizationStatus = AppleMusicImporter.authorizationStatus()
    
    // Import results / feedback
    @Published var lastImportedCount: Int = 0
    @Published var lastImportMessage: String? = nil
    @Published var lastErrorMessage: String? = nil
    
    // Selection caches (IDs of remote items user has picked to import)
    @Published var selectedDriveFileIDs: Set<String> = []
    @Published var selectedOneDriveItemIDs: Set<String> = []
    
    // MARK: - Public Actions
    func requestAppleMusicPermission() async {
        let granted = await AppleMusicImporter.requestPermission()
        appleMusicAuthStatus = granted ? .authorized : AppleMusicImporter.authorizationStatus()
        if !granted { lastErrorMessage = "Apple Music permission was not granted" }
    }
    
    func toggleDriveSelection(fileID: String) {
        if selectedDriveFileIDs.contains(fileID) { selectedDriveFileIDs.remove(fileID) } else { selectedDriveFileIDs.insert(fileID) }
    }
    
    func toggleOneDriveSelection(itemID: String) {
        if selectedOneDriveItemIDs.contains(itemID) { selectedOneDriveItemIDs.remove(itemID) } else { selectedOneDriveItemIDs.insert(itemID) }
    }
    
    func connectGoogleDrive() async {
        let ok = await driveManager.authorize()
        if ok { await refreshDrive() } else { lastErrorMessage = "Failed to connect Google Drive" }
    }
    
    func refreshDrive() async { try? await driveManager.refreshFileList() }
    
    func connectOneDrive() async {
        let ok = await oneDriveManager.authorize()
        if ok { await refreshOneDrive() } else { lastErrorMessage = "Failed to connect OneDrive" }
    }
    
    func refreshOneDrive() async { try? await oneDriveManager.refreshItems() }
    
    // MARK: - Import Execution
    func importDriveSelections(context: ModelContext) async {
        guard driveManager.isAuthorized else { lastErrorMessage = "Connect Google Drive first"; return }
        let targets = driveManager.files.filter { selectedDriveFileIDs.contains($0.id) && $0.type == .audio }
        guard !targets.isEmpty else { return }
        var imported = 0
        for f in targets {
            do {
                let dest = try await driveManager.download(file: f, to: LibraryImportService.libraryFolderURL)
                let _ = await ImportCoordinator.importSongs(from: [dest], context: context, assumedSource: .googleDrive)
                imported += 1
            } catch { lastErrorMessage = error.localizedDescription }
        }
        lastImportedCount = imported
        lastImportMessage = "Imported \(imported) file(s) from Drive"
        selectedDriveFileIDs.removeAll()
    }
    
    func importOneDriveSelections(context: ModelContext) async {
        guard oneDriveManager.isAuthorized else { lastErrorMessage = "Connect OneDrive first"; return }
        let targets = oneDriveManager.items.filter { selectedOneDriveItemIDs.contains($0.id) && $0.type == .audio }
        guard !targets.isEmpty else { return }
        var imported = 0
        for item in targets {
            do {
                let dest = try await oneDriveManager.download(item: item, to: LibraryImportService.libraryFolderURL)
                let _ = await ImportCoordinator.importSongs(from: [dest], context: context, assumedSource: .oneDrive)
                imported += 1
            } catch { lastErrorMessage = error.localizedDescription }
        }
        lastImportedCount = imported
        lastImportMessage = "Imported \(imported) file(s) from OneDrive"
        selectedOneDriveItemIDs.removeAll()
    }
    
    func scanExistingLibrary(context: ModelContext) async {
        isScanningLocal = true
        localScanProgress = 0
        await LibraryImportService.scanLibraryFolder(context: context) { [weak self] p in
            self?.localScanProgress = p
        }
        isScanningLocal = false
    }
}
