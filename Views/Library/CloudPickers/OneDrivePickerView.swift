import SwiftUI

struct OneDrivePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var oneDriveManager: OneDriveServiceManager
    let onImport: ([OneDriveServiceManager.DriveItem]) -> Void
    @State private var selections: Set<String> = []

    var audioItems: [OneDriveServiceManager.DriveItem] { oneDriveManager.items.filter { $0.type == .audio } }

    var body: some View {
        NavigationStack {
            List(audioItems, id: \.id, selection: $selections) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name).font(.system(size: 15, weight: .medium))
                        if let size = item.size { Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)).font(.caption2).foregroundColor(.secondary) }
                    }
                    Spacer()
                    if selections.contains(item.id) { Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                }
                .contentShape(Rectangle())
                .onTapGesture { toggle(item) }
            }
            .overlay { if oneDriveManager.isLoading { ProgressView().progressViewStyle(.circular) } }
            .navigationTitle("OneDrive")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Import") { performImport() }.disabled(selections.isEmpty) }
            }
            .task { if oneDriveManager.items.isEmpty { try? await oneDriveManager.refreshItems() } }
            .refreshable { try? await oneDriveManager.refreshItems() }
        }
    }

    private func toggle(_ item: OneDriveServiceManager.DriveItem) { if selections.contains(item.id) { selections.remove(item.id) } else { selections.insert(item.id) } }
    private func performImport() {
        let chosen = audioItems.filter { selections.contains($0.id) }
        onImport(chosen)
        dismiss()
    }
}
