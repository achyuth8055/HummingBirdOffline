import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    @EnvironmentObject private var player: PlayerViewModel
    @Environment(\.modelContext) private var context
    let playlist: Playlist

    var body: some View {
        List {
            Section {
                ForEach(Array(playlist.songs.enumerated()), id: \.offset) { index, song in
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
                            Haptics.light()
                            player.play(songs: playlist.songs, startAt: index)
                        } label: {
                            Image(systemName: "play.fill")
                        }
                    }
                    .listRowBackground(Color.secondaryBackground)
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.primaryBackground)
        .navigationTitle(playlist.name)
        .toolbar {
            if !playlist.songs.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Play All") {
                        Haptics.light()
                        player.play(songs: playlist.songs, startAt: 0)
                    }
                }
            }
        }
    }
}
