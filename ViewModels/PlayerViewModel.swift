import Foundation
import AVFoundation
import MediaPlayer
import SwiftData
import ActivityKit
import UIKit
import Combine
import SwiftUI

@MainActor
final class PlayerViewModel: ObservableObject {
    static let shared = PlayerViewModel()

    // State
    @Published var currentSong: Song?
    @Published var isPlaying: Bool = false
    @Published var progress: Double = 0
    @Published var showFullPlayer: Bool = false

    // Queue model (history ← current → upNext)
    @Published private(set) var history: [Song] = []
    @Published private(set) var queue: [Song] = []

    // Modes
    enum RepeatMode: String { case off, one, all }
    @Published var isShuffled: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published var volume: Double {
        didSet { applyVolumeChange(oldValue: oldValue) }
    }

    // Crossfade (placeholder; disabled for stability)
    @Published var enableCrossfade: Bool = false
    @Published var crossfadeSeconds: Double = 3.0

    // AVQueuePlayer (simpler, stable)
    private var player: AVQueuePlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var baselineSequence: [Song] = []

    // ---------- Persistence ----------
    private struct NowPlayingState: Codable {
        enum RepeatModeValue: String, Codable { case off, one, all }

        var current: String?          // filePath
        var queue: [String]           // filePaths
        var history: [String]         // filePaths
        var progress: Double          // 0...1
        var isPlaying: Bool
        var shuffle: Bool
        var repeatMode: RepeatModeValue
        var volume: Double
    }
    private let nowPlayingKey = "HBNowPlaying.v1"
    private let volumeDefaultsKey = "HBPlayerVolume"
    // ---------------------------------

    private init() {
        let storedVolume = UserDefaults.standard.object(forKey: volumeDefaultsKey) as? Double
        self.volume = storedVolume.map { max(0, min(1, $0)) } ?? 0.85
        setupPlayer()
        setupRemoteCommands()
        observeInterruptions()
    }

    deinit {
        if let obs = timeObserver { player?.removeTimeObserver(obs) }
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs) }
    }

    // MARK: - Session
    static func configureAudioSession() {
        let s = AVAudioSession.sharedInstance()
        do {
            try s.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            try s.setActive(true)
        } catch { print("AudioSession error:", error) }
    }

    private func setupPlayer() {
        player = AVQueuePlayer()
        player?.volume = Float(volume)

        // Progress observer (every 0.25s)
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            self?.updateProgress()
        }
    }

    private func applyVolumeChange(oldValue: Double) {
        let clamped = max(0, min(1, volume))
        if abs(clamped - volume) > .ulpOfOne {
            volume = clamped
            return
        }
        guard abs(oldValue - clamped) > .ulpOfOne else { return }
        player?.volume = Float(clamped)
        UserDefaults.standard.set(clamped, forKey: volumeDefaultsKey)
    }

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let userInfo = notification.userInfo,
                let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }

            if type == .began {
                self?.pause()
            } else if type == .ended {
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) { self?.resume() }
                }
            }
        }
    }

    private func updateProgress() {
        guard let item = player?.currentItem,
              let song = currentSong,
              item.status == .readyToPlay
        else {
            progress = 0
            return
        }

        let currentTime = CMTimeGetSeconds(item.currentTime())
        if song.duration > 0 {
            progress = max(0, min(1, currentTime / song.duration))
        }

        // keep lock screen elapsed time fresh
        if var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    // MARK: - Public queue API
    func startQueue(_ songs: [Song], startAt index: Int) {
        guard !songs.isEmpty, songs.indices.contains(index) else { return }
        baselineSequence = songs
        history = Array(songs.prefix(index))
        queue   = Array(songs.dropFirst(index + 1))
        let selected = songs[index]
        updateQueueForShuffle(using: selected)
        Task { await start(song: selected) }
    }

    func play(songs: [Song], startAt index: Int = 0) { startQueue(songs, startAt: index) }

    func togglePlayPause() {
        guard currentSong != nil else { return }
        isPlaying ? pause() : resume()
    }

    func resume() {
        guard currentSong != nil else { return }
        PlaybackCoordinator.activateMusic()
        player?.volume = Float(volume)
        player?.play()
        isPlaying = true
        updateNowPlaying(isPlaying: true)
        LiveActivityManager.shared.startOrUpdate(song: currentSong, progress: progress, isPlaying: true)
    }

    func pause() {
        guard currentSong != nil else { return }
        player?.pause()
        isPlaying = false
        updateNowPlaying(isPlaying: false)
        LiveActivityManager.shared.startOrUpdate(song: currentSong, progress: progress, isPlaying: false)
    }

    func nextTrack() {
        guard currentSong != nil else { return }
        if let next = queue.first {
            if let cur = currentSong { history.append(cur) }
            queue.removeFirst()
            Task { await start(song: next) }
        } else if repeatMode == .all, !baselineSequence.isEmpty {
            startQueue(baselineSequence, startAt: 0)
        } else {
            stop()
        }
    }

    func prevTrack() {
        guard currentSong != nil else { return }

        if let item = player?.currentItem, CMTimeGetSeconds(item.currentTime()) > 3 {
            seek(to: 0); return
        }
        guard let prev = history.popLast() else { seek(to: 0); return }
        if let cur = currentSong { queue.insert(cur, at: 0) }
        Task { await start(song: prev) }
    }

    func toggleShuffle() {
        isShuffled.toggle()
        guard let current = currentSong ?? (baselineSequence.isEmpty ? nil : baselineSequence.first) else { return }
        updateQueueForShuffle(using: current)
    }

    func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    func moveInQueue(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        refreshBaselineIfNeeded()
    }

    func clearQueueAndUI() {
        player?.pause()
        player?.removeAllItems()
        isPlaying = false
        progress = 0
        history.removeAll()
        queue.removeAll()
        currentSong = nil
        showFullPlayer = false
        baselineSequence = []
        isShuffled = false
        repeatMode = .off
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        LiveActivityManager.shared.end()
    }

    func seek(to normalized: Double) {
        guard let song = currentSong, let item = player?.currentItem else { return }
        let target = max(0, min(1, normalized)) * song.duration
        let t = CMTime(seconds: target, preferredTimescale: 600)
        item.seek(to: t) { [weak self] _ in
            guard let self else { return }
            self.updateProgress()
            self.updateNowPlaying(isPlaying: self.isPlaying)
        }
    }

    // MARK: - Core start
    private func start(song: Song, autoPlay: Bool = true) async {
        if autoPlay {
            PlaybackCoordinator.activateMusic()
        }
        let url = fileURL(for: song)
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Missing file for \(song.title) → skipping")
            if !queue.isEmpty { nextTrack() } else { stop() }
            return
        }

        currentSong = song
        song.lastPlayed = Date()
        song.playCount += 1

        player?.pause()
        player?.removeAllItems()

        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }

        let item = AVPlayerItem(url: url)
        player?.insert(item, after: nil)
        player?.volume = Float(volume)

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.playbackEnded()
        }

        if autoPlay {
            player?.play()
        } else {
            player?.pause()
        }
        isPlaying = autoPlay
        progress = 0

        updateNowPlaying(isPlaying: autoPlay)
        LiveActivityManager.shared.startOrUpdate(song: song, progress: 0, isPlaying: autoPlay)
        refreshBaselineIfNeeded()
    }

    private func stop() {
        player?.pause()
        player?.removeAllItems()
        isPlaying = false
        progress = 0
        updateNowPlaying(isPlaying: false)
        LiveActivityManager.shared.startOrUpdate(song: currentSong, progress: 0, isPlaying: false)
    }

    private func playbackEnded() {
        switch repeatMode {
        case .one:
            if let s = currentSong { Task { await start(song: s) } }
        case .all:
            if !queue.isEmpty {
                nextTrack()
            } else if !baselineSequence.isEmpty {
                startQueue(baselineSequence, startAt: 0)
            } else {
                stop()
            }
        case .off:
            if !queue.isEmpty { nextTrack() } else { stop() }
        }
    }

    func fileURL(for song: Song) -> URL {
        LibraryImportService.libraryFolderURL.appendingPathComponent(song.filePath)
    }

    // MARK: - Remote Commands & Now Playing
    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()

        c.playCommand.isEnabled = true
        c.playCommand.addTarget { [weak self] _ in self?.resume(); return .success }

        c.pauseCommand.isEnabled = true
        c.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }

        c.togglePlayPauseCommand.isEnabled = true
        c.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }

        c.nextTrackCommand.isEnabled = true
        c.nextTrackCommand.addTarget { [weak self] _ in self?.nextTrack(); return .success }

        c.previousTrackCommand.isEnabled = true
        c.previousTrackCommand.addTarget { [weak self] _ in self?.prevTrack(); return .success }

        c.changePlaybackPositionCommand.isEnabled = true
        c.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent,
                  let duration = self?.currentSong?.duration, duration > 0 else { return .commandFailed }
            self?.seek(to: event.positionTime / duration)
            return .success
        }
    }

    private func updateNowPlaying(isPlaying: Bool) {
        guard let s = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: s.title,
            MPMediaItemPropertyArtist: s.artistName,
            MPMediaItemPropertyAlbumTitle: s.albumName,
            MPMediaItemPropertyPlaybackDuration: s.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress * s.duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if let data = s.artworkData, let img = UIImage(data: data) {
            info[MPMediaItemPropertyArtwork] =
                MPMediaItemArtwork(boundsSize: img.size) { _ in img }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func refreshBaselineIfNeeded() {
        guard !isShuffled else { return }
        baselineSequence = history + [currentSong].compactMap { $0 } + queue
    }

    private func updateQueueForShuffle(using anchor: Song? = nil) {
        guard let current = anchor ?? currentSong else { return }

        if baselineSequence.isEmpty {
            baselineSequence = history + [current] + queue
        }

        let played = playedIDs(including: current)

        if isShuffled {
            var upcoming = baselineSequence.filter { !played.contains($0.persistentID) }
            if upcoming.isEmpty {
                upcoming = queue.filter { !played.contains($0.persistentID) }
            }
            upcoming.shuffle()
            queue = upcoming
        } else {
            guard let idx = indexInBaseline(for: current) else {
                queue = baselineSequence.filter { !played.contains($0.persistentID) }
                return
            }
            let nextIndex = baselineSequence.index(after: idx)
            if nextIndex < baselineSequence.endIndex {
                let suffix = baselineSequence[nextIndex...]
                queue = suffix.filter { !played.contains($0.persistentID) }
            } else {
                queue = []
            }
        }
    }

    private func playedIDs(including current: Song) -> Set<UUID> {
        var ids = Set(history.map { $0.persistentID })
        ids.insert(current.persistentID)
        return ids
    }

    private func indexInBaseline(for song: Song) -> Int? {
        baselineSequence.firstIndex { $0.persistentID == song.persistentID }
    }

    // MARK: - Persistence API (call from ContentView lifecycle)
    func saveState(context: ModelContext) {
        let state = NowPlayingState(
            current: currentSong?.filePath,
            queue: queue.map { $0.filePath },
            history: history.map { $0.filePath },
            progress: progress,
            isPlaying: isPlaying,
            shuffle: isShuffled,
            repeatMode: NowPlayingState.RepeatModeValue(rawValue: repeatMode.rawValue) ?? .off,
            volume: volume
        )
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: nowPlayingKey)
        } catch {
            print("saveState error:", error)
        }
    }

    func restoreState(context: ModelContext) async {
        guard let data = UserDefaults.standard.data(forKey: nowPlayingKey) else { return }
        do {
            let state = try JSONDecoder().decode(NowPlayingState.self, from: data)
            let all: [Song] = (try? context.fetch(FetchDescriptor<Song>())) ?? []

            func find(_ path: String?) -> Song? {
                guard let p = path else { return nil }
                return all.first { $0.filePath == p }
            }

            guard let cur = find(state.current) else { return }
            history = state.history.compactMap { p in all.first { $0.filePath == p } }
            queue   = state.queue.compactMap { p in all.first { $0.filePath == p } }

            baselineSequence = history + [cur] + queue
            volume = state.volume
            repeatMode = RepeatMode(rawValue: state.repeatMode.rawValue) ?? .off
            isShuffled = state.shuffle

            await start(song: cur, autoPlay: false)
            if state.progress > 0 {
                seek(to: state.progress)
                progress = state.progress
            }
            updateNowPlaying(isPlaying: false)
            LiveActivityManager.shared.startOrUpdate(song: currentSong, progress: progress, isPlaying: false)
        } catch {
            print("restoreState error:", error)
        }
    }
}
