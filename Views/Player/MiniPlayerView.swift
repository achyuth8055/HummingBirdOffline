// Views/Player/MiniPlayerView.swift

import SwiftUI

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
        VStack(spacing: 0) {
            content
            progressBar
        }
        .background(Color.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .scaleEffect(isDragging ? 0.98 : 1.0)
        .offset(y: dragOffset)
        .onTapGesture {
            expandIfNeeded()
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
                    .font(HBFont.body(14, weight: .medium))
                    .lineLimit(1)
                    .matchedGeometryEffect(id: "title", in: namespace)
                
                Text(player.currentSong?.artistName.hbPrimaryArtist ?? "HummingBird")
                    .font(HBFont.body(12))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
                    .matchedGeometryEffect(id: "subtitle", in: namespace)
            }
            
            Spacer(minLength: 0)
            
            // Control buttons
            HStack(spacing: 16) {
                Button {
                    Haptics.light()
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                
                Button {
                    Haptics.light()
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
                    .fill(Color.primaryBackground.opacity(0.3))
                    .frame(height: 2)
                
                // Progress track
                Rectangle()
                    .fill(Color.accentGreen)
                    .frame(width: geometry.size.width * player.progress, height: 2)
                    .animation(.linear(duration: 0.3), value: player.progress)
            }
        }
        .frame(height: 2)
        .padding(.horizontal, 1)
    }
    
    private func expandIfNeeded() {
        guard player.currentSong != nil else { return }
        Haptics.light()
        onExpand()
    }
}
