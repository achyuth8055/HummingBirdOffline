import SwiftUI
import SwiftData

@MainActor
struct NowPlayingView: View {
    @EnvironmentObject private var player: PlayerViewModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let namespace: Namespace.ID

    @State private var showingPlaylistSheet = false
    @State private var showingQueueSheet = false
    @GestureState private var dragTranslation: CGFloat = 0

    var body: some View {
        let dragGesture = DragGesture(minimumDistance: 12)
            .updating($dragTranslation) { value, state, _ in
                state = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 120 {
                    Haptics.light()
                    dismissWithAnimation()
                }
            }

        TabView {
            playerPage.tag(0)
            LyricsView(song: player.currentSong).tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(backgroundGradient)
        .offset(y: dragTranslation)
        .gesture(dragGesture)
        .sheet(isPresented: $showingPlaylistSheet) {
            PlaylistPickerSheet(currentSong: player.currentSong)
        }
        .sheet(isPresented: $showingQueueSheet) {
            QueueView().environmentObject(player)
        }
    }

    private var playerPage: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.secondaryText.opacity(0.4))
                .frame(width: 48, height: 5)
                .padding(.top, 12)
                .onTapGesture { dismissWithAnimation() }

            artwork

            VStack(spacing: 6) {
                Text(player.currentSong?.title ?? "Not Playing")
                    .font(HBFont.heading(24))
                    .matchedGeometryEffect(id: "title", in: namespace)

                Text(player.currentSong?.artistName.hbPrimaryArtist ?? "HummingBird")
                    .font(HBFont.body(16))
                    .foregroundColor(.secondaryText)
                    .matchedGeometryEffect(id: "subtitle", in: namespace)
            }

            progressSection
            controlsSection
            volumeSection
            actionsSection
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
    }

    private var artwork: some View {
        GeometryReader { geo in
            ArtworkView(data: player.currentSong?.artworkData)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 16, y: 10)
                .matchedGeometryEffect(id: "art", in: namespace)
                .frame(width: geo.size.width, height: geo.size.width)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var progressSection: some View {
        VStack(spacing: 6) {
            Slider(value: Binding(get: { player.progress }, set: { player.seek(to: $0) }), in: 0...1)
                .disabled(player.currentSong == nil)

            HStack {
                Text(timeString(player.progress * (player.currentSong?.duration ?? 0)))
                Spacer()
                let remaining = max(0, (1 - player.progress) * (player.currentSong?.duration ?? 0))
                Text("-" + timeString(remaining))
            }
            .font(.caption)
            .foregroundColor(.secondaryText)
        }
    }

    private var controlsSection: some View {
        HStack(spacing: 28) {
            Button { player.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.title2)
                    .foregroundColor(player.isShuffled ? .accentGreen : .primaryText)
            }

            Button { player.prevTrack() } label: {
                Image(systemName: "backward.fill").font(.largeTitle)
            }

            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
                    .contentTransition(.symbolEffect(.replace))
            }

            Button { player.nextTrack() } label: {
                Image(systemName: "forward.fill").font(.largeTitle)
            }

            Button { player.toggleRepeat() } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.title2)
                    .foregroundColor(player.repeatMode != .off ? .accentGreen : .primaryText)
            }
        }
        .disabled(player.currentSong == nil)
    }

    private var volumeSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
            Slider(value: Binding(get: { player.volume }, set: { player.volume = $0 }), in: 0...1)
            Image(systemName: "speaker.wave.3.fill")
        }
        .foregroundColor(.secondaryText)
        .disabled(player.currentSong == nil)
    }

    private var actionsSection: some View {
        HStack {
            Button { toggleFavorite() } label: {
                Image(systemName: (player.currentSong?.favorite ?? false) ? "heart.fill" : "heart")
                    .foregroundColor(player.currentSong?.favorite ?? false ? .accentGreen : .primaryText)
            }
            Spacer()
            Button { showingPlaylistSheet = true } label: {
                Image(systemName: "text.badge.plus")
            }
            Spacer()
            Button { showingQueueSheet = true } label: {
                Image(systemName: "list.bullet")
            }
        }
        .font(.title3)
        .disabled(player.currentSong == nil)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.secondaryBackground.opacity(0.85), Color.primaryBackground],
            startPoint: .top,
            endPoint: .bottom
        ).ignoresSafeArea()
    }

    private func toggleFavorite() {
        guard let song = player.currentSong else { return }
        song.favorite.toggle()
        try? context.save()
        Haptics.light()
        if song.favorite {
            ToastCenter.shared.success("Added to Favorites")
        } else {
            ToastCenter.shared.info("Removed from Favorites")
        }
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func dismissWithAnimation() {
        withAnimation(.hbSpringLarge) {
            player.showFullPlayer = false
            dismiss()
        }
    }
}

private struct LyricsView: View {
    let song: Song?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Lyrics")
                    .font(HBFont.heading(20))
                    .padding(.bottom, 8)

                Text("No lyrics available for this song.")
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
            }
            .padding(32)
        }
    }
}

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
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { EditButton() }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(HBFont.body(13, weight: .medium))
            .foregroundColor(.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }
}

private struct QueueRow: View {
    let song: Song
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(data: song.artworkData)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading) {
                Text(song.title)
                    .font(HBFont.body(14, weight: .medium))
                    .lineLimit(1)
                Text(song.artistName.hbPrimaryArtist)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            if isPlaying {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.accentGreen)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
