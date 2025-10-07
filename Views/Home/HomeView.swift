import SwiftUI
import SwiftData
import FirebaseAuth

// MARK: - Premium Home (Inspired by reference image)

struct HomeView: View {
    
    // MARK: - Navigation & Data Structures
    
    /// Defines all possible navigation destinations from the Home screen.
    private enum Destination: Hashable {
        case notifications
        case search
        case settings
        case favorites
        case playlist(Playlist)
        case recentlyAdded
        case mostPlayed
        case recommended
    }
    
    private let overviewGridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    // MARK: - Environment & SwiftData Queries
    
    @EnvironmentObject private var player: PlayerViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.modelContext) private var context

    @Query(sort: \Song.dateAdded, order: .reverse) private var recentlyAdded: [Song]
    @Query(sort: \Song.lastPlayed, order: .reverse) private var recentlyPlayed: [Song]
    @Query(sort: \Song.playCount, order: .reverse) private var mostPlayed: [Song]
    @Query(sort: \Playlist.dateCreated, order: .reverse) private var playlists: [Playlist]
    @Query(filter: #Predicate<Song> { $0.favorite == true }) private var favoriteSongs: [Song]

    // MARK: - UI State
    
    @State private var navigationPath: [Destination] = []
    @State private var showingImporter = false
    @State private var didAppear = false // Used to trigger entry animations

    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 28) {
                    header
                        .padding(.horizontal, 18)
                        .modifier(AnimatedEntry(didAppear: didAppear, delay: 0))

                    overviewTiles
                        .padding(.horizontal, 18)
                        .modifier(AnimatedEntry(didAppear: didAppear, delay: 0.05))

                    recommendedSection
                        .padding(.horizontal, 18)
                        .modifier(AnimatedEntry(didAppear: didAppear, delay: 0.1))

                    topPlaylistsSection
                        .padding(.horizontal, 18)
                        .modifier(AnimatedEntry(didAppear: didAppear, delay: 0.15))
                        
                    recentlyPlayedSection
                        .padding(.horizontal, 18)
                        .modifier(AnimatedEntry(didAppear: didAppear, delay: 0.2))

                    quickStack(title: "Recently Added", dest: .recentlyAdded, source: recentlyAdded)
                        .padding(.horizontal, 18)
                        .modifier(AnimatedEntry(didAppear: didAppear, delay: 0.25))

                    quickStack(title: "Most Played", dest: .mostPlayed, source: mostPlayed)
                        .padding(.horizontal, 18)
                        .modifier(AnimatedEntry(didAppear: didAppear, delay: 0.3))
                }
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
            .background(Color.primaryBackground.ignoresSafeArea())
            .navigationDestination(for: Destination.self, destination: destinationView)
            .sheet(isPresented: $showingImporter, content: { importSheet })
            .task {
                guard !didAppear else { return }
                withAnimation(.snappy(duration: 0.4)) {
                    didAppear = true
                }
            }
        }
    }

    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 16) {
            Button { navigationPath.append(.settings) } label: {
                ProfileBubble(email: authVM.userSession?.email, photoURL: authVM.userSession?.photoURL)
                    .frame(width: 44, height: 44)
            }
            
            Text("Hi, \(displayName)")
                .font(HBFont.heading(24))
                .lineLimit(1)
            
            Spacer()
            
            headerButton(systemName: "magnifyingglass") { navigationPath.append(.search) }
            headerButton(systemName: "heart") { navigationPath.append(.favorites) }
        }
    }

    private var displayName: String {
        // Try display name first
        if let name = authVM.userSession?.displayName, !name.isEmpty {
            return name
        }
        // Try email username
        if let email = authVM.userSession?.email {
            let username = email.components(separatedBy: "@").first ?? ""
            if !username.isEmpty {
                return username.capitalized
            }
        }
        // Fallback to device name
        return UIDevice.current.name.components(separatedBy: "'").first?.trimmingCharacters(in: .whitespaces) ?? "there"
    }

    private func headerButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.light(); action() }) {
            Image(systemName: systemName)
                .font(.title2)
                .fontWeight(.medium)
                .frame(width: 40, height: 40)
                .background(Color.secondaryBackground.opacity(0.5))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
    
    // MARK: - UI Sections

    private var overviewTiles: some View {
        LazyVGrid(columns: overviewGridColumns, spacing: 12) {
            OverviewTile(
                title: "Most Played",
                subtitle: mostPlayed.isEmpty ? "No plays yet" : "\(mostPlayed.count) in library",
                systemImage: "repeat",
                accent: .accentGreen
            ) {
                navigationPath.append(.mostPlayed)
            }

            OverviewTile(
                title: "Recently Added",
                subtitle: recentlyAdded.isEmpty ? "Import music" : "Last added: \(recentlyAdded.first?.title ?? "")",
                systemImage: "clock",
                accent: .accentPurple
            ) {
                navigationPath.append(.recentlyAdded)
            }

            OverviewTile(
                title: "Recommended",
                subtitle: recommendedSongs.isEmpty ? "Listen to build picks" : "Hand-picked for you",
                systemImage: "star.circle",
                accent: .accentOrange
            ) {
                navigationPath.append(.recommended)
            }
        }
    }

    private var recommendedSection: some View {
        let snapshot = recommendedSongs
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Recommended For You")
                Spacer()
                if !snapshot.isEmpty {
                    Button("View All") {
                        navigationPath.append(.recommended)
                    }
                    .font(HBFont.body(12, weight: .medium))
                    .foregroundColor(.accentGreen)
                    .buttonStyle(.plain)
                }
            }

            if snapshot.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.secondaryText.opacity(0.6))
                    Text("Play and favorite songs to build recommendations")
                        .font(HBFont.body(12))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(Array(snapshot.enumerated()), id: \.element.persistentID) { index, song in
                            SmallCard(song: song) {
                                playSong(song, in: snapshot, startAt: index)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private var topPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Playlists")
                    .font(HBFont.heading(20))
                Spacer()
                if !playlists.isEmpty {
                    Button("See all") {
                        // TODO: Navigate to full playlists view
                    }
                    .font(HBFont.body(14, weight: .medium))
                    .foregroundColor(.accentGreen)
                }
            }
            
            if playlists.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.secondaryText.opacity(0.6))
                    Text("No playlists yet")
                        .font(HBFont.body(14, weight: .medium))
                        .foregroundColor(.primaryText)
                    Text("Create your first playlist to organize your music")
                        .font(HBFont.body(12))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(playlists.prefix(4)) { playlist in
                        PlaylistRow(playlist: playlist)
                            .onTapGesture {
                                navigationPath.append(.playlist(playlist))
                            }
                    }
                }
            }
        }
    }
    
    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Recently Played")
            
            if recentlyPlayed.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.secondaryText.opacity(0.6))
                    Text("No recently played songs")
                        .font(HBFont.body(13))
                        .foregroundColor(.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(recentCarouselSongs.enumerated()), id: \.element.persistentID) { index, song in
                            SmallCard(song: song) {
                                playSong(song, in: recentCarouselSongs, startAt: index)
                            }
                        }
                    }
                }
            }
        }
        }
    }

    private var recommendedSongs: [Song] {
        var seen = Set<UUID>()
        var ordered: [Song] = []
        for song in favoriteSongs + mostPlayed + recentlyAdded {
            if seen.insert(song.persistentID).inserted {
                ordered.append(song)
                if ordered.count >= 12 { break }
            }
        }
        return ordered
    }

    private var recentCarouselSongs: [Song] {
        Array(recentlyPlayed.prefix(12))
    }

    private func quickStack(title: String, dest: Destination, source: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle(title)
                Spacer()
                if !source.isEmpty {
                    Button("View All") { navigationPath.append(dest) }
                        .font(HBFont.body(12, weight: .medium))
                        .foregroundColor(.accentGreen)
                        .buttonStyle(.plain)
                }
            }
            
            if source.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.secondaryText.opacity(0.6))
                    Text(emptyMessage(for: title))
                        .font(HBFont.body(12))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                let subset = Array(source.prefix(3))
                ForEach(Array(subset.enumerated()), id: \.element.persistentID) { index, song in
                    SongRow(song: song, playlist: source, index: index)
                }
            }
        }
    }
    
    private func emptyMessage(for title: String) -> String {
        switch title {
        case "Recently Added":
            return "Import songs to get started"
        case "Most Played":
            return "Play some music to see your top tracks"
        default:
            return "No songs available"
        }
    }

    // MARK: - Navigation Destinations & Helpers
    
    @ViewBuilder
    private func destinationView(for destination: Destination) -> some View {
        switch destination {
        case .notifications: NotificationsView()
        case .search: SearchView()
        case .settings: SettingsView()
        case .favorites: FavoritesView()
        case .playlist(let p): PlaylistDetailView(playlist: p)
        case .recentlyAdded: SongListScreen(title: "Recently Added", songs: recentlyAdded)
        case .mostPlayed: SongListScreen(title: "Most Played", songs: mostPlayed)
        case .recommended: SongListScreen(title: "Recommended", songs: recommendedSongs)
        }
    }

    private var importSheet: some View {
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
    
    private func sectionTitle(_ t: String) -> some View { Text(t).font(HBFont.heading(20)) }
    
    private func playSong(_ song: Song, in list: [Song], startAt index: Int? = nil) {
        if let index = index ?? list.firstIndex(of: song) {
            player.play(songs: list, startAt: index)
        }
    }
}

// MARK: - Reusable Components

private struct OverviewTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.light()
            action()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(accent)
                Text(title)
                    .font(HBFont.body(16, weight: .semibold))
                    .foregroundColor(.primaryText)
                Text(subtitle)
                    .font(HBFont.body(12))
                    .foregroundColor(.secondaryText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.secondaryBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PlaylistRow: View {
    let playlist: Playlist
    
    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(data: playlist.songs.first?.artworkData)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    if playlist.songs.first?.artworkData == nil {
                        Image(systemName: "music.note.list")
                            .font(.title3)
                            .foregroundColor(.secondaryText)
                    }
                }
                .background(Color.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(HBFont.body(15, weight: .medium))
                    .lineLimit(1)
                
                Text("\(playlist.songs.count) songs")
                    .font(HBFont.body(12))
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            Button {} label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.accentGreen, Color.secondaryBackground)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct SmallCard: View {
    let song: Song
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArtworkView(data: song.artworkData)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text(song.title)
                .font(HBFont.body(13, weight: .medium))
                .lineLimit(1)
            Text(song.artistName)
                .font(HBFont.body(11))
                .foregroundColor(.secondaryText)
                .lineLimit(1)
        }
        .frame(width: 120)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

private struct SongRow: View {
    @EnvironmentObject private var player: PlayerViewModel
    let song: Song
    let playlist: [Song]
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(data: song.artworkData)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(HBFont.body(14, weight: .medium))
                    .lineLimit(1)
                Text(song.artistName)
                    .font(HBFont.body(12))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                player.play(songs: playlist, startAt: index)
            } label: { Image(systemName: "play.fill") }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.secondaryBackground))
    }
}


// MARK: - Animation Helper

fileprivate struct AnimatedEntry: ViewModifier {
    var didAppear: Bool
    var delay: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(didAppear ? 1 : 0)
            .offset(y: didAppear ? 0 : 15)
            .animation(.snappy(duration: 0.35, extraBounce: 0.05).delay(delay), value: didAppear)
    }
}

// MARK: - Full List Screens

private struct SongListScreen: View {
    @EnvironmentObject private var player: PlayerViewModel
    let title: String
    let songs: [Song]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(songs.enumerated()), id: \.element.persistentID) { index, song in
                    SongRow(song: song, playlist: songs, index: index)
                }
            }
            .padding()
        }
        .background(Color.primaryBackground.ignoresSafeArea())
        .navigationTitle(title)
        .toolbar {
            if !songs.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Play All") {
                        player.play(songs: songs, startAt: 0)
                    }
                }
            }
        }
    }
}


// MARK: - Preview Helper Code
// NOTE: This assumes your REAL Song and Playlist models are in other files.
// This variable is used ONLY for the preview canvas.

@MainActor
let previewContainer: ModelContainer = {
    do {
        // Use your app's actual Song and Playlist models
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Song.self, Playlist.self, configurations: config)
        
        // Add sample data that matches your REAL Song initializer
        let song1 = Song(title: "Sunset Drive", artistName: "Acoustic Cafe", albumName: "Summer Nights", duration: 185, filePath: "path/to/song1.mp3")
        let song2 = Song(title: "Midnight Lo-fi", artistName: "Chill Beats", albumName: "Study Session", duration: 210, filePath: "path/to/song2.mp3")
        let song3 = Song(title: "Morning Dew", artistName: "Piano Peace", albumName: "Awakening", duration: 240, filePath: "path/to/song3.mp3", favorite: true)
        
        let playlist = Playlist(name: "Focus Flow")
        playlist.songs = [song1, song2, song3]
        
        container.mainContext.insert(playlist)
        
        return container
    } catch {
        fatalError("Failed to create model container for previewing: \(error.localizedDescription)")
    }
}()


// MARK: - Preview

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
        .environmentObject(PlayerViewModel.shared)
        .environmentObject(AuthViewModel())
        .modelContainer(previewContainer)
}
