import SwiftUI
import SwiftData

@MainActor
struct MiniPlayerView: View {
    @EnvironmentObject private var player: PlayerViewModel
    
    let namespace: Namespace.ID
    let onExpand: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    
    init(namespace: Namespace.ID, onExpand: @escaping () -> Void) {
        self.namespace = namespace
        self.onExpand = onExpand
    }
    
    var body: some View {
        // If no current song, collapse to zero size (this avoids overlapping UI)
        Group {
            if player.currentSong != nil {
                VStack(spacing: 0) {
                    content
                    progressBar
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .scaleEffect(isDragging ? 0.98 : 1.0)
                .offset(y: dragOffset)
                .onTapGesture { expandIfNeeded() }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    let translation = value.translation.height
                    
                    // Allow upward drag freely, add resistance to downward drag
                    if translation < 0 {
                        dragOffset = translation
                    } else {
                        dragOffset = translation * 0.3 // Add resistance
                    }
                    
                    // Visual feedback when dragging starts
                    if !isDragging && abs(translation) > 5 {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDragging = true
                        }
                    }
                }
                .onEnded { value in
                    let translation = value.translation.height
                    let velocity = value.velocity.height
                    
                    // Reset position with animation
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        dragOffset = 0
                        isDragging = false
                    }
                    
                    // Expand if dragged up significantly or with upward velocity
                    if translation < -60 || (translation < -20 && velocity < -200) {
                        expandIfNeeded()
                    }
                }
        )
    }
    
    private var content: some View {
        HStack(spacing: 12) {
            // Album artwork
            ArtworkView(data: player.currentSong?.artworkData)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                .matchedGeometryEffect(id: "art", in: namespace)
            
            // Song info
            VStack(alignment: .leading, spacing: 2) {
                Text(player.currentSong?.title ?? "Not Playing")
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .matchedGeometryEffect(id: "title", in: namespace)
                
                Text(player.currentSong?.artistName ?? "HummingBird")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .matchedGeometryEffect(id: "subtitle", in: namespace)
            }
            
            Spacer(minLength: 0)
            
            // Control buttons
            HStack(spacing: 16) {
                Button {
                    // Haptics.light() // Custom helper
                    player.togglePlayPause()
                } label: {
                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .buttonStyle(.plain)
                .disabled(player.isLoading)
                
                Button {
                    // Haptics.light() // Custom helper
                    player.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color(.systemGray4).opacity(0.5))
                    .frame(height: 2)
                
                // Progress track
                Rectangle()
                    .fill(Color.green)
                    .frame(width: geometry.size.width * player.progress, height: 2)
                    .animation(.linear(duration: 0.3), value: player.progress)
            }
        }
        .frame(height: 2)
        .padding(.horizontal, 1)
    }
    
    private func expandIfNeeded() {
        guard player.currentSong != nil else { return }
        // Haptics.light() // Custom helper
        onExpand()
    }
}


// MARK: - Preview

#Preview {
    // A wrapper is needed to provide the @Namespace property
    struct MiniPlayerPreviewWrapper: View {
        @Namespace var namespace
        
        var body: some View {
            MiniPlayerView(namespace: namespace, onExpand: {
                print("Expand action triggered!")
            })
        }
    }
    
    // --- Preview Setup ---
    // 1. Create a sample song to display
    let sampleSong = Song(title: "Chasing Sunsets", artistName: "Chillwave Beats", albumName: "Summer Vibes", duration: 210, filePath: "dummy_path.mp3")
    
    // 2. Get the player and set its state for the preview
    let playerVM = PlayerViewModel.shared
    playerVM.currentSong = sampleSong
    playerVM.progress = 0.4 // Show the progress bar partially filled
    
    // 3. Create the view and inject the dependencies
    return ZStack(alignment: .bottom) {
        Color(.systemBackground).ignoresSafeArea()
        Text("Main Content Area")
        
        MiniPlayerPreviewWrapper()
            .padding()
            .padding(.bottom, 40)
    }
    .environmentObject(playerVM)
    .modelContainer(for: [Song.self, Playlist.self], inMemory: true) // Provides SwiftData context
    .preferredColorScheme(.dark)
}
