import SwiftUI
import SwiftData
import Combine

struct PlaylistPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Playlist.dateCreated, order: .reverse) private var playlists: [Playlist]
    
    @State private var newName: String = ""
    let currentSong: Song?
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Section for creating a new playlist
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Create New Playlist")
                        HStack {
                            TextField("Playlist name", text: $newName)
                                .focused($isNameFieldFocused)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.secondaryBackground.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Button("Create", action: createPlaylist)
                                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                                .font(HBFont.body(14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.accentGreen)
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                        }
                    }

                    // Section for listing existing playlists
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Add to Existing")
                        if playlists.isEmpty {
                            Text("No playlists yet. Create one above!")
                                .font(HBFont.body(14))
                                .foregroundColor(.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(playlists) { playlist in
                                playlistRow(for: playlist)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.primaryBackground.ignoresSafeArea())
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                // Focus the text field automatically if there are no playlists
                if playlists.isEmpty {
                    isNameFieldFocused = true
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(.ultraThinMaterial)
    }

    /// A styled row for each existing playlist.
    private func playlistRow(for playlist: Playlist) -> some View {
        Button {
            add(song: currentSong, to: playlist)
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondaryBackground)
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "music.note.list").foregroundColor(.secondaryText))

                Text(playlist.name)
                    .font(HBFont.body(15, weight: .medium))

                Spacer()

                // FIXED: Removed '?.' and '?? 0' as 'songs' is not optional.
                Text("\(playlist.songs.count)")
                    .font(HBFont.body(14))
                    .foregroundColor(.secondaryText)
            }
            .foregroundColor(.primaryText)
        }
    }
    
    /// A helper view for section titles.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(HBFont.body(13, weight: .medium))
            .foregroundColor(.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Logic

    private func add(song: Song?, to playlist: Playlist) {
        guard let song = song else { return }
        
        // FIXED: Removed '?.' and '?? false' as 'songs' is not optional.
        if !playlist.songs.contains(where: { $0.persistentModelID == song.persistentModelID }) {
            // FIXED: Removed '?.' as 'songs' is not optional.
            playlist.songs.append(song)
            try? context.save()
            ToastCenter.shared.success("Added to \(playlist.name)")
        } else {
            ToastCenter.shared.info("Already in \(playlist.name)")
        }
        dismiss()
    }

    private func createPlaylist() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let playlist = Playlist(name: trimmed)
        context.insert(playlist)
        
        // Optionally add the current song to the new playlist right away
        if let currentSong = currentSong {
            // FIXED: Removed '?.' as 'songs' is not optional.
            playlist.songs.append(currentSong)
            ToastCenter.shared.success("Created and added to \(trimmed)")
        } else {
            ToastCenter.shared.success("Created playlist \(trimmed)")
        }
        
        try? context.save()
        newName = ""
        isNameFieldFocused = false // Dismiss keyboard
    }
}
