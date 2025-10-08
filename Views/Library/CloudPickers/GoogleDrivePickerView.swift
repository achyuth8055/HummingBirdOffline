import SwiftUI

struct GoogleDrivePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var driveManager: DriveServiceManager
    let onImport: ([DriveServiceManager.DriveFile]) -> Void
    @State private var selections: Set<String> = []

    var audioFiles: [DriveServiceManager.DriveFile] { driveManager.files.filter { $0.type == .audio } }

    var body: some View {
        NavigationStack {
            List(audioFiles, id: \.id, selection: $selections) { file in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.name).font(.system(size: 15, weight: .medium))
                        if let size = file.size { Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)).font(.caption2).foregroundColor(.secondary) }
                    }
                    Spacer()
                    if selections.contains(file.id) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { toggle(file) }
            }
            .overlay { if driveManager.isLoading { ProgressView().progressViewStyle(.circular) } }
            .navigationTitle("Google Drive")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { performImport() }.disabled(selections.isEmpty)
                }
            }
            .task { if driveManager.files.isEmpty { try? await driveManager.refreshFileList() } }
            .refreshable { try? await driveManager.refreshFileList() }
        }
    }

    private func toggle(_ file: DriveServiceManager.DriveFile) { if selections.contains(file.id) { selections.remove(file.id) } else { selections.insert(file.id) } }
    private func performImport() {
        let chosen = audioFiles.filter { selections.contains($0.id) }
        onImport(chosen)
        dismiss()
    }
}
