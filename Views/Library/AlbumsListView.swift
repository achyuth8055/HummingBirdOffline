//
//  AlbumsListView.swift
//  HummingBirdOffline
//

import SwiftUI
import SwiftData

/// Groups tracks by album (album name + primary artist). One row per album.
struct AlbumsListView: View {
    @Query(sort: \Song.albumName, order: .forward, animation: .default) private var songs: [Song]

    private struct AlbumKey: Hashable {
        let name: String
        let artist: String
    }

    private var grouped: [(AlbumKey, [Song])] {
        // Group songs by album and primary artist
        let groups = Dictionary(grouping: songs) { (s: Song) in
            AlbumKey(
                name: s.albumName.isEmpty ? "Unknown Album" : s.albumName,
                artist: ArtistsListView.primaryArtist(from: s.artistName)
            )
        }

        // Sort tracks within an album (by title), then sort albums by name
        let mapped = groups.map { (key, value) -> (AlbumKey, [Song]) in
            let tracksSortedByTitle = value.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return (key, tracksSortedByTitle)
        }

        return mapped.sorted {
            $0.0.name.localizedCaseInsensitiveCompare($1.0.name) == .orderedAscending
        }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.0) { (key, tracks) in
                NavigationLink {
                    AlbumDetailView(albumName: key.name, albumArtist: key.artist, tracks: tracks)
                } label: {
                    HStack(spacing: 12) {
                        ArtworkView(data: tracks.first?.artworkData)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(key.name).font(.headline).lineLimit(1)
                            Text(key.artist).font(.subheadline)
                                .foregroundColor(.secondaryText)
                                .lineLimit(1)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondaryText)
                    }
                }
                .listRowBackground(Color.secondaryBackground)
            }
        }
        .listStyle(.plain)
        .background(Color.primaryBackground)
    }
}

struct AlbumDetailView: View {
    @EnvironmentObject private var player: PlayerViewModel
    let albumName: String
    let albumArtist: String
    let tracks: [Song]

    @State private var showEditor = false

    var body: some View {
        List {
            ForEach(tracks) { s in
                HStack(spacing: 12) {
                    ArtworkView(data: s.artworkData).frame(width: 40, height: 40)
                    Text(s.title).lineLimit(1)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if let start = tracks.firstIndex(of: s) {
                        player.play(songs: tracks, startAt: start)
                    }
                }
                .listRowBackground(Color.secondaryBackground)
            }
        }
        .listStyle(.plain)
        .background(Color.primaryBackground)
        .navigationTitle(albumName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showEditor = true } label: { Image(systemName: "pencil") }
            }
        }
        .sheet(isPresented: $showEditor) {
            // Provide a lightweight Album instance to editor (create or fetch existing Album entity if exists)
            if let existing = tracks.first?.album {
                NavigationStack { AlbumEditorView(album: existing) }
            } else {
                Text("Album object missing")
            }
        }
    }
}
