import SwiftUI
import SwiftData
import MediaPlayer

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = ImportViewModel()
    @State private var showingAppleMusicImporter = false
    @State private var showingDrivePicker = false
    @State private var showingOneDrivePicker = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    cloudStorageSection
                    localImportSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.green)
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
                GoogleDrivePickerView(driveManager: viewModel.driveManager) { selected in
                    Task {
                        for file in selected {
                            _ = try? await viewModel.driveManager.download(file: file, to: LibraryImportService.libraryFolderURL)
                        }
                        // Optionally trigger a library scan/import here if needed
                    }
                }
            }
            .sheet(isPresented: $showingOneDrivePicker) {
                OneDrivePickerView(oneDriveManager: viewModel.oneDriveManager) { selected in
                    Task {
                        for item in selected {
                            _ = try? await viewModel.oneDriveManager.download(item: item, to: LibraryImportService.libraryFolderURL)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import Your Music")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Add music from your cloud storage, local files, or Apple Music library")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Cloud Storage Section
    
    private var cloudStorageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Cloud Storage")
            
            VStack(spacing: 12) {
                ImportCard(
                    icon: "cloud.fill", iconColor: .blue, title: "Google Drive",
                    subtitle: viewModel.driveManager.isAuthorized ? (viewModel.driveManager.accountName ?? "Connected") : "Connect to import",
                    actionTitle: viewModel.driveManager.isAuthorized ? "Browse" : (viewModel.driveManager.isLoading ? "..." : "Connect"),
                    isConnected: viewModel.driveManager.isAuthorized, isLoading: viewModel.driveManager.isLoading
                ) {
                    if viewModel.driveManager.isAuthorized { showingDrivePicker = true } else { handleDriveTap() }
                }
                
                if viewModel.driveManager.isAuthorized {
                    cloudFileSelectionList
                }
                
                ImportCard(
                    icon: "cloud.fill", iconColor: .cyan, title: "OneDrive",
                    subtitle: viewModel.oneDriveManager.isAuthorized ? (viewModel.oneDriveManager.accountName ?? "Connected") : "Connect to import",
                    actionTitle: viewModel.oneDriveManager.isAuthorized ? "Browse" : (viewModel.oneDriveManager.isLoading ? "..." : "Connect"),
                    isConnected: viewModel.oneDriveManager.isAuthorized, isLoading: viewModel.oneDriveManager.isLoading
                ) {
                    if viewModel.oneDriveManager.isAuthorized { showingOneDrivePicker = true } else { handleOneDriveTap() }
                }
                
                if viewModel.oneDriveManager.isAuthorized {
                    oneDriveSelectionList
                }
            }
        }
    }
    
    // MARK: - Local Import Section
    
    private var localImportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Import")
            
            VStack(spacing: 12) {
                ImportCard(icon: "folder.fill", iconColor: .blue, title: "Files", subtitle: "Import from Files app", actionTitle: "Browse") {
                    Haptics.light()
                    viewModel.showFileImporter = true
                }
                
                ImportCard(icon: "wifi", iconColor: .purple, title: "Wi-Fi Transfer", subtitle: "Transfer from Mac/PC over network", actionTitle: "Setup", isDisabled: true) {
                    ToastCenter.shared.info("Wi-Fi Transfer coming soon")
                }
                
                ImportCard(icon: "externaldrive.fill.badge.wifi", iconColor: .orange, title: "SMB", subtitle: "Import from network drive", actionTitle: "Connect", isDisabled: true) {
                    ToastCenter.shared.info("SMB import coming soon")
                }
                
                ImportCard(icon: "music.note", iconColor: .pink, title: "Apple Music", subtitle: "Import from your library", actionTitle: "Select") { handleAppleMusicSelection() }
                
                ImportCard(icon: "iphone.and.arrow.forward", iconColor: .green, title: "File Sharing", subtitle: "Connect via USB in Finder/iTunes", actionTitle: "Info", showChevron: true) {
                    showFileSharingInfo()
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.primary)
    }
    
    // MARK: - Actions
    
    private func handleDriveTap() {
        Haptics.light()
        Task {
            if !viewModel.driveManager.isAuthorized {
                let ok = await viewModel.driveManager.authorize()
                if ok { ToastCenter.shared.success("Google Drive connected"); await viewModel.refreshDrive() }
                else { ToastCenter.shared.error("Drive auth failed") }
            } else {
                await viewModel.refreshDrive()
            }
        }
    }
    
    private func handleOneDriveTap() {
        Haptics.light()
        Task {
            if !viewModel.oneDriveManager.isAuthorized {
                let ok = await viewModel.oneDriveManager.authorize()
                if ok { ToastCenter.shared.success("OneDrive connected"); await viewModel.refreshOneDrive() }
                else { ToastCenter.shared.error("OneDrive auth failed") }
            } else {
                await viewModel.refreshOneDrive()
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
                } else {
                    ToastCenter.shared.info("These songs are already in your library")
                }
            }
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
                    if granted { showingAppleMusicImporter = true }
                    else { ToastCenter.shared.error("Enable Media Library access in Settings to import Apple Music.") }
                }
            }
        default:
            ToastCenter.shared.error("Enable Media Library access in Settings to import Apple Music.")
        }
    }
    
    private func importAppleMusicItems(_ items: [MPMediaItem]) async {
        guard !items.isEmpty else { return }
        
        let result = await AppleMusicImporter.importMediaItems(items, context: modelContext)
        
        await MainActor.run {
            if result.imported > 0 {
                Haptics.success()
                ToastCenter.shared.success("Imported \(result.imported) song(s)")
            }
            
            if result.skipped > 0 {
                ToastCenter.shared.info("\(result.skipped) song(s) already in library")
            }
            
            if !result.errors.isEmpty {
                ToastCenter.shared.error("Failed to import \(result.errors.count) song(s)")
            }
        }
    }
    
    private func showFileSharingInfo() {
        Haptics.light()
        ToastCenter.shared.info("Connect your device to Mac/PC and use Finder or iTunes to transfer files")
    }
}

// MARK: - Cloud File Selection Lists
private extension ImportView {
    var cloudFileSelectionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.driveManager.isLoading { ProgressView().progressViewStyle(.circular) }
            ForEach(viewModel.driveManager.files) { file in
                if file.type == .audio {
                    HStack {
                        Button(action: { viewModel.toggleDriveSelection(fileID: file.id) }) {
                            Image(systemName: viewModel.selectedDriveFileIDs.contains(file.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(viewModel.selectedDriveFileIDs.contains(file.id) ? .green : .secondary)
                        }.buttonStyle(.plain)
                        Text(file.name).font(.system(size: 13)).lineLimit(1)
                        Spacer()
                        if let size = file.size { Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)).font(.caption2).foregroundColor(.secondary) }
                    }
                    .padding(.horizontal, 4)
                }
            }
            if !viewModel.selectedDriveFileIDs.isEmpty {
                Button {
                    Task { await viewModel.importDriveSelections(context: modelContext) }
                } label: {
                    Text("Import Selected (\(viewModel.selectedDriveFileIDs.count))")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .background(Capsule().fill(Color.green.opacity(0.2)))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemGroupedBackground)))
    }
    
    var oneDriveSelectionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.oneDriveManager.isLoading { ProgressView().progressViewStyle(.circular) }
            ForEach(viewModel.oneDriveManager.items) { item in
                if item.type == .audio {
                    HStack {
                        Button(action: { viewModel.toggleOneDriveSelection(itemID: item.id) }) {
                            Image(systemName: viewModel.selectedOneDriveItemIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(viewModel.selectedOneDriveItemIDs.contains(item.id) ? .green : .secondary)
                        }.buttonStyle(.plain)
                        Text(item.name).font(.system(size: 13)).lineLimit(1)
                        Spacer()
                        if let size = item.size { Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)).font(.caption2).foregroundColor(.secondary) }
                    }
                    .padding(.horizontal, 4)
                }
            }
            if !viewModel.selectedOneDriveItemIDs.isEmpty {
                Button {
                    Task { await viewModel.importOneDriveSelections(context: modelContext) }
                } label: {
                    Text("Import Selected (\(viewModel.selectedOneDriveItemIDs.count))")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .background(Capsule().fill(Color.green.opacity(0.2)))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemGroupedBackground)))
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
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isDisabled ? .secondary : .primary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView().progressViewStyle(.circular).scaleEffect(0.9)
                } else if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                } else {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isConnected ? .green : .blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill((isConnected ? Color.green : Color.blue).opacity(0.15)))
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}


// MARK: - Preview

#Preview {
    // Creates a temporary, in-memory database for the preview
    let previewContainer: ModelContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return try ModelContainer(for: Song.self, configurations: config)
        } catch {
            fatalError("Failed to create model container for preview: \(error)")
        }
    }()

    // FIX: Removed the 'return' keyword
    ImportView()
        .modelContainer(previewContainer)
        .preferredColorScheme(.dark)
}
