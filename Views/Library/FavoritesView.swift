import SwiftUI
import SwiftData

struct FavoritesView: View {
    @EnvironmentObject private var player: PlayerViewModel
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate { $0.favorite == true }, sort: \Song.title, order: .forward) private var favorites: [Song]

    var body: some View {
        Group {
            if favorites.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "heart").font(.system(size: 56)).foregroundColor(.secondaryText)
                    Text("No favorites yet").font(HBFont.heading(20))
                    Text("Tap the heart on any song to add it here.")
                        .font(HBFont.body(13))
                        .foregroundColor(.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Favorites")
                                .font(HBFont.heading(26))
                            Spacer()
                            Button("Play all") {
                                Haptics.light()
                                player.play(songs: favorites, startAt: 0)
                            }
                            .font(HBFont.body(13, weight: .medium))
                        }
                        ForEach(favorites) { song in
                            FavoriteRow(song: song, allSongs: favorites)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 48)
                }
            }
        }
        .background(Color.primaryBackground.ignoresSafeArea())
    }
}

private struct FavoriteRow: View {
    @EnvironmentObject private var player: PlayerViewModel
    @Environment(\.modelContext) private var context
    let song: Song
    let allSongs: [Song]

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(data: song.artworkData)
                .frame(width: 54, height: 54)
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
                if let index = allSongs.firstIndex(of: song) {
                    player.play(songs: allSongs, startAt: index)
                }
            } label: {
                Image(systemName: "play.fill")
            }
            Button {
                Haptics.light()
                song.favorite = false
                try? context.save()
            } label: {
                Image(systemName: "heart.slash")
                    .foregroundColor(.accentGreen)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.secondaryBackground)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 6)
        )
    }
}
