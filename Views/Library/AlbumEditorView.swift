import SwiftUI
import PhotosUI
import SwiftData

struct AlbumEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var manager = AlbumManager.shared

    let album: Album
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isMergingDuplicates = false

    var body: some View {
        Form {
            Section(header: Text("Artwork")) {
                HStack(spacing: 16) {
                    ArtworkView(data: album.artworkData)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 4)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.title).font(.headline).lineLimit(2)
                        Text(album.artistName).font(.subheadline).foregroundColor(.secondary)
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: 1, matching: .images) {
                            Label("Change Cover", systemImage: "photo")
                        }
                        .onChange(of: pickerItems) { old, new in
                            guard let item = new.first else { return }
                            Task { await loadImage(from: item) }
                        }
                    }
                }
            }

            if !manager.duplicateGroups.isEmpty {
                Section(header: Text("Duplicate Groups"), footer: Text("Merging moves songs into the first album and deletes the others.")) {
                    ForEach(manager.duplicateGroups, id: \.[0].self) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.first?.title ?? "Album")
                                .font(.subheadline.weight(.semibold))
                            Text("Albums: \(group.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if group.contains(where: { $0 == album }) {
                                Button(role: .destructive) {
                                    Haptics.medium()
                                    manager.mergeDuplicateGroup(group, context: modelContext)
                                } label: { Text("Merge This Group") }
                            }
                        }
                        .padding(4)
                    }
                }
            }
        }
        .navigationTitle("Edit Album")
        .onAppear { manager.refresh(context: modelContext) }
    }

    private func loadImage(from item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
            manager.updateArtwork(for: album, image: image, context: modelContext)
        }
    }
}

#Preview {
    let container: ModelContainer = {
        do { return try ModelContainer(for: Album.self, Song.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)) }
        catch { fatalError("Preview container error: \(error)") }
    }()
    let sample = Album(title: "Sample", artistName: "Artist")
    return NavigationStack { AlbumEditorView(album: sample) }
        .modelContainer(container)
}
