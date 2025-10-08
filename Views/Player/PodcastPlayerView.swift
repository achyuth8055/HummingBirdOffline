import SwiftUI
import SwiftData

// MARK: - PodcastPlayerView
// Full screen podcast playback UI mirroring music FullPlayerView style.
// Uses PodcastPlayerViewModel as its source of truth.

struct PodcastPlayerView: View {
    @ObservedObject private var vm = PodcastPlayerViewModel.shared
    @Environment(\.dismiss) private var dismiss
    
    @GestureState private var dragOffset: CGFloat = 0
    
    private var artworkSize: CGFloat { 300 }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.primaryBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                handleBar
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 32) {
                        artworkSection
                        infoSection
                        progressSection
                        controlsSection
                        speedSection
                        queuePreview
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .gesture(dismissDragGesture)
        .onTapGesture {} // absorb
    }
    
    private var handleBar: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.secondary.opacity(0.4))
            .frame(width: 40, height: 4)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }
    
    private var artworkSection: some View {
        ZStack {
            if let artURL = vm.currentEpisode?.artworkURLValue ?? vm.currentEpisode?.podcast?.artworkURLValue {
                AsyncImage(url: artURL) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure: Color.secondaryBackground
                    case .empty: ProgressView()
                    @unknown default: Color.secondaryBackground
                    }
                }
            } else {
                Color.secondaryBackground
            }
        }
        .frame(width: artworkSize, height: artworkSize)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(radius: 10, y: 8)
        .padding(.top, 12)
    }
    
    private var infoSection: some View {
        VStack(spacing: 8) {
            Text(vm.currentEpisode?.title ?? "Episode")
                .font(.system(size: 20, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
            Text(vm.currentEpisode?.podcast?.title ?? vm.currentEpisode?.podcastID ?? "Podcast")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 8) {
            Slider(value: Binding(get: { vm.progress }, set: { vm.seek(to: ($0 * (vm.currentEpisode?.duration ?? 0))) }), in: 0...1)
                .tint(.accentColor)
            HStack {
                Text(timeString(seconds: currentSeconds))
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(timeRemainingString())
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }
    
    private var controlsSection: some View {
        HStack(spacing: 42) {
            Button { vm.skipBackward() } label: { controlIcon("gobackward.15") }
            Button { vm.togglePlayPause() } label: { Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill").resizable().frame(width: 68, height: 68).foregroundColor(.accentColor) }
            Button { vm.skipForward() } label: { controlIcon("goforward.30") }
        }
        .padding(.top, 4)
    }
    
    private var speedSection: some View {
        VStack(spacing: 6) {
            Text("Playback Speed")
                .font(.caption).foregroundColor(.secondary)
            HStack(spacing: 12) {
                ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                    Button {
                        vm.playbackRate = Float(rate)
                        if vm.isPlaying { vm.resume() }
                    } label: {
                        Text(String(format: "%.2gx", rate))
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.vertical, 6).padding(.horizontal, 10)
                            .background(Capsule().fill(isRateSelected(rate) ? Color.accentColor : Color.secondary.opacity(0.15)))
                            .foregroundColor(isRateSelected(rate) ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 8)
    }

    private func isRateSelected(_ rate: Double) -> Bool {
        abs(Double(vm.playbackRate) - rate) < 0.01
    }
    
    private var queuePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !vm.queue.isEmpty {
                Text("Up Next")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                ForEach(Array(vm.queue.prefix(3))) { ep in
                    HStack(spacing: 10) {
                        Circle().fill(Color.accentColor.opacity(0.15)).frame(width: 34, height: 34)
                            .overlay(Image(systemName: "mic.fill").foregroundColor(.accentColor))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ep.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                            Text(ep.publishedAt?.formatted(date: .abbreviated, time: .omitted) ?? "").font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { vm.play(episode: ep, in: [vm.currentEpisode].compactMap { $0 } + vm.queue) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func controlIcon(_ name: String) -> some View {
        Image(systemName: name)
            .resizable()
            .scaledToFit()
            .frame(width: 36, height: 36)
            .foregroundColor(.primary)
    }
    
    private var currentSeconds: Double { vm.progress * (vm.currentEpisode?.duration ?? 0) }
    
    private func timeString(seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
    
    private func timeRemainingString() -> String {
        guard let dur = vm.currentEpisode?.duration else { return "-0:00" }
        let remaining = max(0, dur - currentSeconds)
        return "-" + timeString(seconds: remaining)
    }
    
    // Drag to dismiss (like swipe down gesture)
    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .updating($dragOffset) { value, state, _ in
                if value.translation.height > 0 { state = value.translation.height }
            }
            .onEnded { value in
                if value.translation.height > 120 { vm.showFullPlayer = false }
            }
    }
}

#Preview {
    let sample = Episode(
        id: UUID().uuidString,
        podcastID: "demo",
        title: "Sample Episode",
        publishedAt: Date(),
        duration: 1800,
        description: "",
        audioURL: "https://example.com/audio.mp3"
    )
    PodcastPlayerViewModel.shared.preloadForPreview(sample, isPlaying: true, progress: 0.35)
    return PodcastPlayerView()
        .preferredColorScheme(.dark)
}
