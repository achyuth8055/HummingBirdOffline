import SwiftUI

struct PodcastMiniPlayerView: View {
    @ObservedObject private var vm = PodcastPlayerViewModel.shared
    let onExpand: () -> Void
    
    var body: some View {
        if let episode = vm.currentEpisode {
            HStack(spacing: 12) {
                artworkThumb
                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(episode.podcast?.title ?? episode.podcastID)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    ProgressView(value: vm.progress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                        .frame(maxWidth: .infinity)
                }
                Spacer(minLength: 0)
                Button { vm.togglePlayPause() } label: {
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(8)
                }
                .buttonStyle(.plain)
                Button { vm.showFullPlayer = true } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.trailing, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onTapGesture { onExpand() }
        }
    }
    
    private var artworkThumb: some View {
        ZStack {
            if let url = vm.currentEpisode?.artworkURLValue ?? vm.currentEpisode?.podcast?.artworkURLValue {
                AsyncImage(url: url) { phase in
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
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    let sample = Episode(
        id: UUID().uuidString,
        podcastID: "demo",
        title: "Preview Episode",
        publishedAt: Date(),
        duration: 1200,
        description: "",
        audioURL: "https://example.com/audio.mp3"
    )
    PodcastPlayerViewModel.shared.preloadForPreview(sample)
    PodcastPlayerViewModel.shared.showFullPlayer = false
    PodcastPlayerViewModel.shared.playbackRate = 1.0
    return PodcastMiniPlayerView(onExpand: { PodcastPlayerViewModel.shared.showFullPlayer = true })
        .padding()
        .preferredColorScheme(.dark)
}
