//
//  RecentlyPlayedView.swift
//  HummingBirdOffline
//
//  Created by Achyuth on 05/10/25.
//

import SwiftUI
import SwiftData

struct RecentlyPlayedView: View {
    @EnvironmentObject private var player: PlayerViewModel
    @Query(sort: \Song.lastPlayed, order: .reverse) private var recent: [Song]

    var body: some View {
        Group {
            if recent.isEmpty {
                // A cleaner, centered empty state view
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 50, weight: .light))
                        .foregroundColor(.secondaryText)
                    Text("No Recent Plays")
                        .font(HBFont.heading(20))
                    Text("Your recently played songs will appear here.")
                        .font(HBFont.body(14))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal)
            } else {
                // Use a ScrollView for a custom, modern list appearance
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(recent) { song in
                            // Re-use the stylish SongRow component
                            SongRow(song: song, collection: recent)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 100) // Extra space for mini player
                }
            }
        }
        .background(Color.primaryBackground)
        .navigationTitle("Recently Played")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            // Add a "Play All" button for convenience
            if !recent.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Play All") {
                        Haptics.light()
                        player.play(songs: recent, startAt: 0)
                    }
                }
            }
        }
    }
}


// MARK: - Reusable SongRow Component (Included for convenience)

private struct SongRow: View {
    @EnvironmentObject private var player: PlayerViewModel
    @Environment(\.modelContext) private var context
    let song: Song
    let collection: [Song]
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
                Text(song.artistName.hbPrimaryArtist)
                    .font(HBFont.body(12))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                if let index = collection.firstIndex(of: song) {
                    Haptics.light()
                    player.play(songs: collection, startAt: index)
                }
            } label: { Image(systemName: "play.fill") }
            .buttonStyle(.plain)

            Button {
                Haptics.light()
                song.favorite.toggle()
                isFavorite = song.favorite
                try? context.save()
                ToastCenter.shared.show(
                    song.favorite ? .success("Added to Favorites") : .info("Removed from Favorites")
                )
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(isFavorite ? .accentGreen : .secondaryText)
                    .scaleEffect(isFavorite ? 1.08 : 1)
                    .animation(.snappy(duration: 0.26, extraBounce: 0.14), value: isFavorite)
            }
            .buttonStyle(.plain)
        }
        .onAppear { isFavorite = song.favorite }
        .onChange(of: song.favorite) { _, new in isFavorite = new }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.secondaryBackground))
    }
}


// MARK: - Helper Extension
