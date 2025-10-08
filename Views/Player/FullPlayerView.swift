import SwiftUI
import SwiftData

/// Full-screen player with Spotify-style slide-up animation
@MainActor
struct FullPlayerView: View {
    @EnvironmentObject private var player: PlayerViewModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    let namespace: Namespace.ID
    
    @State private var showingPlaylistSheet = false
    @State private var showingQueueSheet = false
    @State private var currentTab: PlayerTab = .player
    @GestureState private var dragTranslation: CGFloat = 0
    @State private var backgroundOpacity: Double = 0
    
    enum PlayerTab {
        case player, lyrics, queue
    }
    
    var body: some View {
        ZStack {
            // Background dimming
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.3), value: backgroundOpacity)
            
            VStack(spacing: 0) {
                dragHandle
                
                TabView(selection: $currentTab) {
                    playerContent
                        .tag(PlayerTab.player)
                    
                    LyricsView(song: player.currentSong)
                        .tag(PlayerTab.lyrics)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(backgroundGradient)
            .offset(y: dragTranslation)
            .gesture(dismissGesture)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
                backgroundOpacity = 0.6
            }
            Haptics.light()
        }
        .sheet(isPresented: $showingPlaylistSheet) {
            PlaylistPickerSheet(currentSong: player.currentSong)
        }
        .sheet(isPresented: $showingQueueSheet) {
            QueueView().environmentObject(player)
        }
    }
    
    // MARK: - Drag Handle
    
    private var dragHandle: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(Color.secondaryText.opacity(0.4))
                .frame(width: 48, height: 5)
                .padding(.top, 12)
                .onTapGesture { dismissPlayer() }
            
            // Tab indicator
            HStack(spacing: 32) {
                TabIndicator(title: "Player", isSelected: currentTab == .player) {
                    withAnimation(.spring(response: 0.3)) {
                        currentTab = .player
                    }
                }
                
                TabIndicator(title: "Lyrics", isSelected: currentTab == .lyrics) {
                    withAnimation(.spring(response: 0.3)) {
                        currentTab = .lyrics
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Player Content
    
    private var playerContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                artwork
                songInfo
                progressSection
                controlsSection
                volumeSection
                actionsSection
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }
    
    private var artwork: some View {
        GeometryReader { geo in
            ArtworkView(data: player.currentSong?.artworkData)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 20, y: 12)
                .matchedGeometryEffect(id: "art", in: namespace)
                .frame(width: geo.size.width, height: geo.size.width)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.top, 20)
    }
    
    private var songInfo: some View {
        VStack(spacing: 8) {
            Text(player.currentSong?.title ?? "Not Playing")
                .font(HBFont.heading(26))
                .foregroundColor(.primaryText)
                .multilineTextAlignment(.center)
                .matchedGeometryEffect(id: "title", in: namespace)
            
            Text(player.currentSong?.artistName.hbPrimaryArtist ?? "HummingBird")
                .font(HBFont.body(17))
                .foregroundColor(.secondaryText)
                .matchedGeometryEffect(id: "subtitle", in: namespace)
        }
        .padding(.horizontal)
    }
    
    private var progressSection: some View {
        VStack(spacing: 8) {
            // Custom slider with accent color
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.secondaryBackground)
                        .frame(height: 4)
                    
                    // Progress track
                    Capsule()
                        .fill(Color.accentGreen)
                        .frame(width: geometry.size.width * player.progress, height: 4)
                    
                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .offset(x: geometry.size.width * player.progress - 6)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let progress = max(0, min(1, value.location.x / geometry.size.width))
                            player.seek(to: progress)
                        }
                )
            }
            .frame(height: 12)
            
            HStack {
                Text(timeString(player.progress * (player.currentSong?.duration ?? 0)))
                    .font(HBFont.body(12))
                    .foregroundColor(.secondaryText)
                
                Spacer()
                
                let remaining = max(0, (1 - player.progress) * (player.currentSong?.duration ?? 0))
                Text("-" + timeString(remaining))
                    .font(HBFont.body(12))
                    .foregroundColor(.secondaryText)
            }
        }
        .padding(.top, 8)
    }
    
    private var controlsSection: some View {
        HStack(spacing: 24) {
            Button { 
                Haptics.light()
                player.toggleShuffle() 
            } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundColor(player.isShuffled ? .accentGreen : .primaryText)
                    .frame(width: 44, height: 44)
            }
            
            Button { 
                Haptics.medium()
                player.prevTrack() 
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.primaryText)
            }
            
            Button { 
                Haptics.medium()
                player.togglePlayPause() 
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 72, height: 72)
                    
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.primaryBackground)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            
            Button { 
                Haptics.medium()
                player.nextTrack() 
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.primaryText)
            }
            
            Button { 
                Haptics.light()
                player.toggleRepeat() 
            } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.title3)
                    .foregroundColor(player.repeatMode != .off ? .accentGreen : .primaryText)
                    .frame(width: 44, height: 44)
            }
        }
        .disabled(player.currentSong == nil)
        .padding(.vertical, 8)
    }
    
    private var volumeSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.body)
                .foregroundColor(.secondaryText)
            
            Slider(value: Binding(
                get: { player.volume },
                set: { player.volume = $0 }
            ), in: 0...1)
            .tint(.accentGreen)
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.body)
                .foregroundColor(.secondaryText)
        }
        .disabled(player.currentSong == nil)
    }
    
    private var actionsSection: some View {
        HStack(spacing: 40) {
            Button { 
                toggleFavorite() 
            } label: {
                Image(systemName: (player.currentSong?.favorite ?? false) ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundColor(player.currentSong?.favorite ?? false ? .accentGreen : .primaryText)
                    .scaleEffect((player.currentSong?.favorite ?? false) ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: player.currentSong?.favorite)
            }
            
            Spacer()
            
            Button { 
                Haptics.light()
                showingPlaylistSheet = true 
            } label: {
                Image(systemName: "text.badge.plus")
                    .font(.title2)
                    .foregroundColor(.primaryText)
            }
            
            Spacer()
            
            Button { 
                Haptics.light()
                showingQueueSheet = true 
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title2)
                    .foregroundColor(.primaryText)
            }
        }
        .disabled(player.currentSong == nil)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helpers
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.secondaryBackground.opacity(0.95),
                Color.primaryBackground
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .updating($dragTranslation) { value, state, _ in
                state = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 100 || value.predictedEndTranslation.height > 200 {
                    Haptics.light()
                    dismissPlayer()
                }
            }
    }
    
    private func dismissPlayer() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            backgroundOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            player.showFullPlayer = false
            dismiss()
        }
    }
    
    private func toggleFavorite() {
        guard let song = player.currentSong else { return }
        Haptics.light()
        song.favorite.toggle()
        try? context.save()
        
        if song.favorite {
            ToastCenter.shared.success("Added to Favorites")
        } else {
            ToastCenter.shared.info("Removed from Favorites")
        }
    }
    
    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let s = Int(seconds.rounded())
        let minutes = s / 60
        let secs = s % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Tab Indicator

private struct TabIndicator: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(HBFont.body(15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primaryText : .secondaryText)
                
                if isSelected {
                    Capsule()
                        .fill(Color.accentGreen)
                        .frame(height: 2)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Capsule()
                        .fill(Color.clear)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lyrics View
private struct LyricsView: View {
    let song: Song?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let lyrics = song?.lyrics, !lyrics.isEmpty {
                    Text(lyrics)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.primary)
                        .lineSpacing(8)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Text("No lyrics available")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                }
            }
            .padding(32)
        }
    }
}
// MARK: - Queue View

private struct QueueView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var player: PlayerViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if let current = player.currentSong {
                        Section(header: sectionHeader("Now Playing")) {
                            QueueRow(song: current, isPlaying: true)
                        }
                    }
                    
                    if !player.queue.isEmpty {
                        Section(header: sectionHeader("Up Next")) {
                            ForEach(player.queue) { song in
                                QueueRow(song: song, isPlaying: false)
                            }
                            .onMove { indices, newOffset in
                                player.moveInQueue(from: indices, to: newOffset)
                            }
                        }
                    }
                    
                    if !player.history.isEmpty {
                        Section(header: sectionHeader("History")) {
                            ForEach(player.history.reversed()) { song in
                                QueueRow(song: song, isPlaying: false)
                            }
                        }
                    }
                }
            }
            .background(Color.primaryBackground.ignoresSafeArea())
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        Haptics.light()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(HBFont.body(13, weight: .semibold))
            .foregroundColor(.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)
            .background(Color.primaryBackground)
    }
}

private struct QueueRow: View {
    let song: Song
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(data: song.artworkData)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(HBFont.body(15, weight: .medium))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                Text(song.artistName.hbPrimaryArtist)
                    .font(HBFont.body(13))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isPlaying {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.body)
                    .foregroundColor(.accentGreen)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(isPlaying ? Color.secondaryBackground.opacity(0.5) : Color.clear)
    }
}
