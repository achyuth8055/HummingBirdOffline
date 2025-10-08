import SwiftUI
import SwiftData
import MediaPlayer

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @StateObject private var viewModel = ImportViewModel()
    @State private var showingAppleMusicImporter = false
    @State private var showingDrivePicker = false
    @State private var showingOneDrivePicker = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    
                    // MARK: - Available Sources
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Available Sources")
                        
                        ImportCard(
                            icon: "folder.fill", 
                            iconColor: .blue, 
                            title: "Files",
                            subtitle: "Import tracks from files",
                            actionTitle: "Select"
                        ) {
                            viewModel.showFileImporter = true
                        }
                        
                        ImportCard(
                            icon: "music.note", 
                            iconColor: .red, 
                            title: "Apple Music",
                            subtitle: "Import tracks from apple music",
                            actionTitle: "Select"
                        ) {
                            handleAppleMusicSelection()
                        }
                        
                        // Google Drive with auth awareness
                        ImportCard(
                            icon: "cloud", 
                            iconColor: .yellow, 
                            title: "Google Drive",
                            subtitle: getDriveSubtitle(),
                            actionTitle: viewModel.driveManager.isAuthorized ? "Browse" : (viewModel.driveManager.isLoading ? "..." : "Connect"),
                            isConnected: viewModel.driveManager.isAuthorized, 
                            isLoading: viewModel.driveManager.isLoading
                        ) {
                            handleDriveTap()
                        }
                        
                        // OneDrive
                        ImportCard(
                            icon: "cloud", 
                            iconColor: .cyan, 
                            title: "OneDrive",
                            subtitle: getOneDriveSubtitle(),
                            actionTitle: viewModel.oneDriveManager.isAuthorized ? "Browse" : (viewModel.oneDriveManager.isLoading ? "..." : "Connect"),
                            isConnected: viewModel.oneDriveManager.isAuthorized, 
                            isLoading: viewModel.oneDriveManager.isLoading
                        ) {
                            handleOneDriveTap()
                        }
                    }
                    
                    // MARK: - Import Status
                    if let message = viewModel.lastImportMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("Import Status")
                            
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(message)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondaryText)
                            }
                            .padding(12)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    if let error = viewModel.lastErrorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("Error")
                            
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondaryText)
                            }
                            .padding(12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    // MARK: - Coming Soon Section
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Coming Soon")
                        
                        ImportCard(
                            icon: "desktopcomputer", 
                            iconColor: .gray, 
                            title: "Computer",
                            subtitle: "Using Wi-Fi",
                            actionTitle: "Coming Soon", 
                            isDisabled: true
                        ) {
                            ToastCenter.shared.info("Wi-Fi Transfer is coming soon!")
                        }
                        
                        ImportCard(
                            icon: "shippingbox.fill", 
                            iconColor: .blue, 
                            title: "Dropbox",
                            subtitle: "Tap to sign in",
                            actionTitle: "Coming Soon", 
                            isDisabled: true
                        ) {
                            ToastCenter.shared.info("Dropbox support is coming soon!")
                        }

                        ImportCard(
                            icon: "archivebox.fill", 
                            iconColor: .blue, 
                            title: "Box",
                            subtitle: "Tap to sign in",
                            actionTitle: "Coming Soon", 
                            isDisabled: true
                        ) {
                            ToastCenter.shared.info("Box support is coming soon!")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color.primaryBackground.ignoresSafeArea())
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.accentGreen)
                }
            }
            .sheet(isPresented: $viewModel.showFileImporter) {
                DocumentPicker(onPicked: { urls in
                    importFiles(from: urls)
                })
            }
            .sheet(isPresented: $showingAppleMusicImporter) {
                AppleMusicPicker(isPresented: $showingAppleMusicImporter) { items in
                    Task {
                        await importAppleMusicItems(items)
                    }
                }
            }
            .sheet(isPresented: $showingDrivePicker) {
                GoogleDrivePickerView(driveManager: viewModel.driveManager) { selectedFiles in
                    Task {
                        let ids: [String] = selectedFiles.map { $0.id }
                        await importFromGoogleDrive(fileIDs: ids)
                    }
                }
            }
            .sheet(isPresented: $showingOneDrivePicker) {
                OneDrivePickerView(oneDriveManager: viewModel.oneDriveManager) { selectedItems in
                    Task {
                        let ids: [String] = selectedItems.map { $0.id }
                        await importFromOneDrive(itemIDs: ids)
                    }
                }
            }
            .onAppear {
                // Check auth state and update Drive connection status
                updateDriveConnectionStatus()
            }
        }
    }
    
    // MARK: - Auth-aware subtitle methods
    
    private func getDriveSubtitle() -> String {
        if viewModel.driveManager.isAuthorized {
            return viewModel.driveManager.accountName ?? "Connected"
        } else if authViewModel.isGoogleUser {
            return "\(authViewModel.userEmail) (Google linked)"
        } else {
            return "Tap to sign in"
        }
    }
    
    private func getOneDriveSubtitle() -> String {
        if viewModel.oneDriveManager.isAuthorized {
            return viewModel.oneDriveManager.accountName ?? "Connected"
        } else {
            return "Tap to sign in"
        }
    }
    
    private func updateDriveConnectionStatus() {
        // Auto-connect Google Drive if user is signed in with Google
        if authViewModel.isGoogleUser && !viewModel.driveManager.isAuthorized {
            Task {
                await autoConnectGoogleDrive()
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.secondaryText)
            .padding(.horizontal, 4)
    }
    
    // MARK: - Actions
    
    private func handleDriveTap() {
        Haptics.light()
        
        if viewModel.driveManager.isAuthorized {
            // Already authorized, show picker
            Task {
                await viewModel.refreshDrive()
                showingDrivePicker = true
            }
        } else if authViewModel.isGoogleUser {
            // Auto-authorize with Google user's email
            Task {
                await autoConnectGoogleDrive()
            }
        } else {
            // Manual authorization
            Task {
                let success = await viewModel.driveManager.authorize()
                if success {
                    ToastCenter.shared.success("Google Drive connected")
                    await viewModel.refreshDrive()
                    showingDrivePicker = true
                } else {
                    ToastCenter.shared.error("Drive authorization failed.")
                }
            }
        }
    }
    
    private func autoConnectGoogleDrive() async {
        let success = await viewModel.driveManager.authorizeWithGoogleUser()
        if success {
            ToastCenter.shared.success("Google Drive auto-connected")
            await viewModel.refreshDrive()
        } else {
            ToastCenter.shared.error("Failed to auto-connect Google Drive")
        }
    }
    
    private func handleOneDriveTap() {
        Haptics.light()
        
        if viewModel.oneDriveManager.isAuthorized {
            // Already authorized, show picker
            Task {
                await viewModel.refreshOneDrive()
                showingOneDrivePicker = true
            }
        } else {
            // Manual authorization
            Task {
                let success = await viewModel.oneDriveManager.authorize()
                if success {
                    ToastCenter.shared.success("OneDrive connected")
                    await viewModel.refreshOneDrive()
                    showingOneDrivePicker = true
                } else {
                    ToastCenter.shared.error("OneDrive authorization failed.")
                }
            }
        }
    }
    
    private func importFiles(from urls: [URL]) {
        guard !urls.isEmpty else { return }
        
        Task {
            let added = await ImportCoordinator.importSongs(from: urls, context: modelContext, assumedSource: .local)
            await MainActor.run {
                if added > 0 {
                    Haptics.success()
                    ToastCenter.shared.success("Imported \(added) \(added == 1 ? "song" : "songs")")
                    viewModel.lastImportedCount = added
                    viewModel.lastImportMessage = "Successfully imported \(added) local files"
                } else {
                    ToastCenter.shared.info("These songs are already in your library")
                }
                viewModel.lastErrorMessage = nil
            }
        }
    }
    
    private func importFromGoogleDrive(fileIDs: [String]) async {
        let imported = await ImportCoordinator.importFromGoogleDrive(fileIDs: fileIDs, context: modelContext)
        
        await MainActor.run {
            if imported > 0 {
                Haptics.success()
                ToastCenter.shared.success("Imported \(imported) song(s) from Google Drive")
                viewModel.lastImportedCount = imported
                viewModel.lastImportMessage = "Successfully imported \(imported) songs from Google Drive (streaming)"
            } else {
                ToastCenter.shared.info("No new songs were imported")
            }
            viewModel.lastErrorMessage = nil
        }
    }
    
    private func importFromOneDrive(itemIDs: [String]) async {
        let imported = await ImportCoordinator.importFromOneDrive(itemIDs: itemIDs, context: modelContext)
        
        await MainActor.run {
            if imported > 0 {
                Haptics.success()
                ToastCenter.shared.success("Imported \(imported) song(s) from OneDrive")
                viewModel.lastImportedCount = imported
                viewModel.lastImportMessage = "Successfully imported \(imported) songs from OneDrive (streaming)"
            } else {
                ToastCenter.shared.info("No new songs were imported")
            }
            viewModel.lastErrorMessage = nil
        }
    }
    
    private func handleAppleMusicSelection() {
        Haptics.light()
        let status = AppleMusicImporter.authorizationStatus()
        
        switch status {
        case .authorized:
            showingAppleMusicImporter = true
        case .notDetermined:
            Task {
                let granted = await AppleMusicImporter.requestPermission()
                await MainActor.run {
                    if granted { 
                        showingAppleMusicImporter = true 
                    } else { 
                        ToastCenter.shared.error("Enable Media Library access in Settings to import Apple Music.")
                        viewModel.lastErrorMessage = "Apple Music permission denied"
                    }
                }
            }
        default:
            ToastCenter.shared.error("Enable Media Library access in Settings to import Apple Music.")
            viewModel.lastErrorMessage = "Apple Music permission denied"
        }
    }
    
    private func importAppleMusicItems(_ items: [MPMediaItem]) async {
        guard !items.isEmpty else { return }
        
        let result = await AppleMusicImporter.importMediaItems(items, context: modelContext)
        
        await MainActor.run {
            if result.imported > 0 {
                Haptics.success()
                ToastCenter.shared.success("Imported \(result.imported) song(s)")
                viewModel.lastImportedCount = result.imported
                viewModel.lastImportMessage = "Successfully imported \(result.imported) Apple Music songs"
            }
            
            if result.skipped > 0 {
                ToastCenter.shared.info("\(result.skipped) song(s) already in library")
            }
            
            if !result.errors.isEmpty {
                ToastCenter.shared.error("Failed to import \(result.errors.count) song(s)")
                viewModel.lastErrorMessage = "Failed to import \(result.errors.count) Apple Music songs"
            } else {
                viewModel.lastErrorMessage = nil
            }
        }
    }
}

// MARK: - Import Card
private struct ImportCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let actionTitle: String
    var isConnected: Bool = false
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var showChevron: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: isDisabled ? {} : action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 36, height: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDisabled ? .secondary.opacity(0.7) : .primary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView().progressViewStyle(.circular).scaleEffect(0.8)
                } else if !isDisabled {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.secondaryBackground))
        }
        .buttonStyle(.plain)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Song.self, configurations: config)
    
    return ImportView()
        .modelContainer(container)
        .preferredColorScheme(.dark)
}

