import Foundation
import AVFoundation
import MediaPlayer
import Combine
import SwiftData

@MainActor
final class PodcastPlayerViewModel: ObservableObject {
    static let shared = PodcastPlayerViewModel()

    @Published private(set) var currentEpisode: Episode?
    @Published private(set) var queue: [Episode] = []
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var progress: Double = 0
    @Published var showFullPlayer: Bool = false
    @Published var playbackRate: Float = 1.0 {
        didSet { player.rate = isPlaying ? playbackRate : 0 }
    }

    private var player = AVPlayer()
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var lastPersistedProgressUpdate: Date = .distantPast

    private init() {
        configureAudioSession()
        observeInterruptions()
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateProgress()
            }
        }
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
    }

    func play(episode: Episode, in episodes: [Episode]) {
        guard let index = episodes.firstIndex(where: { $0.id == episode.id }) else { return }
        let tail = Array(episodes.dropFirst(index + 1))
        queue = tail
        currentEpisode = episode
        beginPlayback(episode: episode)
    }

    func togglePlayPause() {
        guard currentEpisode != nil else { return }
        isPlaying ? pause() : resume()
    }

    func resume() {
        guard currentEpisode != nil else { return }
        PlaybackCoordinator.activatePodcast()
        player.play()
        player.rate = playbackRate
        isPlaying = true
        updateNowPlaying(isPlaying: true)
        lastPersistedProgressUpdate = .distantPast
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlaying(isPlaying: false)
        persistProgressIfNeeded(force: true)
    }

    func skipForward() {
        guard let item = player.currentItem else { return }
        let newTime = CMTimeGetSeconds(item.currentTime()) + 30
        seek(to: newTime)
    }

    func skipBackward() {
        guard let item = player.currentItem else { return }
        let newTime = max(0, CMTimeGetSeconds(item.currentTime()) - 15)
        seek(to: newTime)
    }

    func seek(to seconds: TimeInterval) {
        guard let item = player.currentItem else { return }
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time)
        updateProgress()
        persistProgressIfNeeded(force: true)
    }

    private func beginPlayback(episode: Episode) {
        pause()
        PlaybackCoordinator.activatePodcast()
        guard let assetURL = episode.localFileURLValue ?? URL(string: episode.audioURL) else {
            print("PodcastPlayerViewModel: invalid episode URL")
            return
        }
        let playerItem = AVPlayerItem(url: assetURL)
        player.replaceCurrentItem(with: playerItem)
        if episode.playbackPositionSec > 1 {
            let position = CMTime(seconds: episode.playbackPositionSec, preferredTimescale: 600)
            player.seek(to: position)
            progress = episode.duration.map { episode.playbackPositionSec / $0 }.map { min(1, max(0, $0)) } ?? 0
        } else {
            progress = 0
        }
        episode.lastPlayedDate = Date()
        episode.lastPlayed = Date()
        try? episode.modelContext?.save()
        lastPersistedProgressUpdate = .distantPast
        resume()
        updateNowPlaying(isPlaying: true)
    }

    private func updateProgress() {
        guard let item = player.currentItem, let episode = currentEpisode else {
            progress = 0
            return
        }
        let duration = CMTimeGetSeconds(item.duration)
        let time = CMTimeGetSeconds(item.currentTime())
        if duration > 0 {
            progress = min(1, max(0, time / duration))
        }
        updateNowPlaying(isPlaying: isPlaying)
        NotificationCenter.default.post(name: .podcastProgressDidChange, object: nil, userInfo: ["episode": episode, "progress": time])
        persistProgressIfNeeded(currentTime: time, duration: duration)
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.allowAirPlay, .allowBluetoothA2DP, .allowBluetoothHFP]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Podcast audio session error", error)
        }
    }

    private func observeInterruptions() {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                guard let info = notification.userInfo,
                      let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
                switch type {
                case .began: self?.pause()
                case .ended:
                    if let value = info[AVAudioSessionInterruptionOptionKey] as? UInt,
                       AVAudioSession.InterruptionOptions(rawValue: value).contains(.shouldResume) {
                        self?.resume()
                    }
                @unknown default: break
                }
            }
            .store(in: &cancellables)
    }

    private func updateNowPlaying(isPlaying: Bool) {
        guard let episode = currentEpisode else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: episode.title,
            MPMediaItemPropertyArtist: episode.podcastID,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime().seconds,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackRate : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: playbackRate
        ]
        if let duration = player.currentItem?.duration.seconds, duration.isFinite {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func persistProgressIfNeeded(currentTime: TimeInterval? = nil, duration: TimeInterval? = nil, force: Bool = false) {
        guard let episode = currentEpisode else { return }
        let now = Date()
        if !force && now.timeIntervalSince(lastPersistedProgressUpdate) < 5 { return }

        let currentTime = currentTime ?? player.currentTime().seconds
        let duration = duration ?? player.currentItem?.duration.seconds ?? episode.duration ?? 0
        let normalized = duration > 0 ? max(0, min(1, currentTime / duration)) : 0

        episode.playbackPositionSec = currentTime
        episode.playbackProgress = normalized
        episode.lastPlayedDate = now
        episode.lastPlayed = now
        episode.isCompleted = normalized >= 0.95
        if let context = episode.modelContext {
            try? context.save()
        }
        lastPersistedProgressUpdate = now
    }

    #if DEBUG
    func preloadForPreview(_ episode: Episode, isPlaying: Bool = false, progress: Double = 0) {
        currentEpisode = episode
        queue = []
        self.isPlaying = isPlaying
        self.progress = progress
    }
    #endif
}

extension Notification.Name {
    static let podcastProgressDidChange = Notification.Name("PodcastProgressDidChange")
}
