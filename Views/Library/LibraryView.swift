import SwiftUI
import SwiftData

struct LibraryView: View {
    private enum Tab: Int { case songs, playlists, favorites, albums }

    @Environment(\.modelContext) private var context
    @EnvironmentObject private var player: PlayerViewModel
    @Query(sort: \Song.title, order: .forward) private var songs: [Song]
    @Query(sort: \Playlist.dateCreated, order: .reverse) private var playlists: [Playlist]
    @Query(filter: #Predicate<Song> { $0.favorite == true }, sort: \Song.title, order: .forward) private var favorites: [Song]
    @Query(sort: \Album.title, order: .forward) private var albums: [Album]

    @State private var selection: Tab = .songs
    @State private var showingImporter = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Library")
                    .font(HBFont.heading(34))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Picker("", selection: $selection) {
                    Text("Songs").tag(Tab.songs)
                    Text("Playlists").tag(Tab.playlists)
                    Text("Favorites").tag(Tab.favorites)
                    Text("Albums").tag(Tab.albums)
                }
                .pickerStyle(.segmented)

                Group {
                    switch selection {
                    case .songs: songsList
                    case .playlists: playlistsList
                    case .favorites: favoritesList
                    case .albums: albumsList
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .background(Color.primaryBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.light()
                        showingImporter = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingImporter) {
            ImportSongsPicker { urls in
                guard !urls.isEmpty else { return }
                Task {
                    let added = await ImportCoordinator.importSongs(from: urls, context: context)
                    await MainActor.run {
                        if added > 0 {
                            Haptics.light()
                            ToastCenter.shared.success("Imported \(added) \(added == 1 ? "song" : "songs")")
                        } else {
                            ToastCenter.shared.info("These songs are already in your library")
                        }
                    }
                }
            }
        }
    }

    private var songsList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if songs.isEmpty {
                    EmptyStateView(icon: "music.note.list", title: "No songs yet", message: "Import audio files to start listening.")
                } else {
                    ForEach(songs) { song in
                        LibrarySongRow(song: song, allSongs: songs)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var playlistsList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if playlists.isEmpty {
                    EmptyStateView(icon: "music.note.list", title: "No playlists", message: "Create a playlist from any song.")
                } else {
                    ForEach(playlists) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlist: playlist)
                        } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.secondaryBackground)
                                    .frame(width: 56, height: 56)
                                    .overlay(Image(systemName: "music.note.list").foregroundColor(.secondaryText))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(playlist.name).font(HBFont.body(14, weight: .medium))
                                    Text("\(playlist.songs.count) songs").font(HBFont.body(12)).foregroundColor(.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.secondaryText)
                            }
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.secondaryBackground))
                            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var favoritesList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if favorites.isEmpty {
                    EmptyStateView(icon: "heart", title: "No favorites yet", message: "Tap the heart on any song to add it here.")
                } else {
                    ForEach(favorites) { song in
                        LibrarySongRow(song: song, allSongs: favorites)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var albumsList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if albums.isEmpty {
                    EmptyStateView(icon: "rectangle.stack", title: "No albums", message: "Albums appear after importing music.")
                } else {
                    ForEach(albums) { album in
                        NavigationLink {
                            AlbumDetailView(albumName: album.title, albumArtist: album.artistName, tracks: album.songs)
                        } label: {
                            HStack(spacing: 12) {
                                ArtworkView(data: album.artworkData)
                                    .frame(width: 54, height: 54)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(album.title).font(HBFont.body(14, weight: .medium)).lineLimit(1)
                                    Text(album.artistName).font(HBFont.body(12)).foregroundColor(.secondaryText).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.secondaryText)
                            }
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.secondaryBackground))
                            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

private struct LibrarySongRow: View {
    @EnvironmentObject private var player: PlayerViewModel
    @Environment(\.modelContext) private var context
    let song: Song
    let allSongs: [Song]
    @State private var isFavorite = false

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(data: song.artworkData)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(HBFont.body(14, weight: .medium))
                    .lineLimit(1)
                Text(ArtistsListView.primaryArtist(from: song.artistName))
                    .font(HBFont.body(12))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                if let index = allSongs.firstIndex(of: song) {
                    Haptics.light()
                    player.play(songs: allSongs, startAt: index)
                }
            } label: {
                Image(systemName: "play.fill")
            }
            Button {
                Haptics.light()
                song.favorite.toggle()
                isFavorite = song.favorite
                try? context.save()
                if song.favorite {
                    ToastCenter.shared.success("Added to Favorites")
                } else {
                    ToastCenter.shared.info("Removed from Favorites")
                }
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(isFavorite ? .accentGreen : .secondaryText)
                    .scaleEffect(isFavorite ? 1.08 : 1)
                    .animation(.snappy(duration: 0.26, extraBounce: 0.14), value: isFavorite)
            }
        }
        .onAppear { isFavorite = song.favorite }
        .onChange(of: song.favorite) { isFavorite = $0 }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.secondaryBackground))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }
}

private struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 54))
                .foregroundColor(.secondaryText)
            Text(title)
                .font(HBFont.heading(20))
            Text(message)
                .font(HBFont.body(13))
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
