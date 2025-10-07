import SwiftUI
import SwiftData

/// Shows a clean, unique list of artists (no giant comma-strings).
struct ArtistsListView: View {
    @Query(sort: \Song.artistName, order: .forward, animation: .default) private var songs: [Song]

    private var uniqueArtists: [String] {
        let names = songs.map { Self.primaryArtist(from: $0.artistName) }
        return Array(Set(names)).sorted()
    }

    var body: some View {
        List {
            ForEach(uniqueArtists, id: \.self) { artist in
                NavigationLink {
                    ArtistDetailView(artist: artist)
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle.fill").foregroundColor(.accentGreen)
                            .frame(width: 30, height: 30)
                        Text(artist).lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.secondaryText)
                    }
                }
                .listRowBackground(Color.secondaryBackground)
            }
        }
        .listStyle(.plain)
        .background(Color.primaryBackground)
    }

    /// Pull a single primary name from messy metadata like "A, B, feat. C & D".
    static func primaryArtist(from raw: String) -> String {
        let lower = raw.lowercased()
        let seps = [",", "&", " and ", " feat. ", " ft. ", " featuring "]
        for sep in seps {
            if let r = lower.range(of: sep) {
                return String(raw[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ArtistDetailView: View {
    @EnvironmentObject private var player: PlayerViewModel
    @Query(sort: \Song.title, order: .forward, animation: .default) private var allSongs: [Song]
    let artist: String

    private var songsForArtist: [Song] {
        allSongs.filter { ArtistsListView.primaryArtist(from: $0.artistName) == artist }
    }

    var body: some View {
        List {
            ForEach(songsForArtist) { s in
                HStack(spacing: 12) {
                    ArtworkView(data: s.artworkData).frame(width: 40, height: 40)
                    Text(s.title).lineLimit(1)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if let start = songsForArtist.firstIndex(of: s) {
                        player.play(songs: songsForArtist, startAt: start)
                    }
                }
                .listRowBackground(Color.secondaryBackground)
            }
        }
        .listStyle(.plain)
        .background(Color.primaryBackground)
        .navigationTitle(artist)
    }
}
