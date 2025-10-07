//
//  AudioPlaybackManager.swift
//  HummingBirdOffline
//
//  Unified manager for both Music and Podcast playback
//

import Foundation
import AVFoundation
import MediaPlayer
import SwiftData
import Combine
import UIKit

@MainActor
final class AudioPlaybackManager: ObservableObject {
    static let shared = AudioPlaybackManager()
    
    // MARK: - Published State
    
    enum ContentType {
        case music(Song)
        case podcast(Episode)
        case none
    }
    
    @Published private(set) var currentContent: ContentType = .none
    @Published var isPlaying: Bool = false
    @Published var progress: Double = 0  // 0.0 to 1.0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Double {
        didSet { applyVolumeChange(oldValue: oldValue) }
    }
    
    // Music-specific state
    @Published private(set) var musicQueue: [Song] = []
    @Published private(set) var musicHistory: [Song] = []
    @Published var isShuffled: Bool = false
    @Published var repeatMode: RepeatMode = .off
    
    // Podcast-specific state
    @Published var playbackSpeed: Float = 1.0 {
        didSet { applyPlaybackSpeed() }
    }
    
    enum RepeatMode: String {
        case off, one, all
    }
    
    // MARK: - Private Properties
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var baselineSequence: [Song] = []
    
    private let volumeDefaultsKey = "HBAudioManagerVolume"
    private let playbackSpeedKey = "HBPodcastPlaybackSpeed"
    
    // MARK: - Initialization
    
    private init() {
        let storedVolume = UserDefaults.standard.object(forKey: volumeDefaultsKey) as? Double
        self.volume = storedVolume.map { max(0, min(1, $0)) } ?? 0.85
        
        let storedSpeed = UserDefaults.standard.object(forKey: playbackSpeedKey) as? Float
        self.playbackSpeed = storedSpeed ?? 1.0
        
        setupPlayer()
        setupRemoteCommands()
        observeInterruptions()
    }
    
    deinit {
        if let obs = timeObserver { player?.removeTimeObserver(obs) }
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs) }
    }
    
    // MARK: - Session Configuration
    
    static func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            try session.setActive(true)
        } catch {
            print("AudioSession error:", error)
        }
    }
    
    // MARK: - Player Setup
    
    private func setupPlayer() {
        player = AVPlayer()
        player?.volume = Float(volume)
        
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updateProgress(time: time)
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
    
    private func applyPlaybackSpeed() {
        let clamped = max(0.5, min(2.0, playbackSpeed))
        playbackSpeed = clamped
        
        guard case .podcast = currentContent else { return }
        player?.rate = isPlaying ? clamped : 0
        UserDefaults.standard.set(clamped, forKey: playbackSpeedKey)
    }
    
    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }
            
            if type == .began {
                self.pause()
            } else if type == .ended {
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) { self.resume() }
                }
            }
        }
    }
    
    // MARK: - Progress Updates
    
    private func updateProgress(time: CMTime) {
        guard let item = player?.currentItem,
              item.status == .readyToPlay else {
            progress = 0
            currentTime = 0
            return
        }
        
        let current = CMTimeGetSeconds(time)
        currentTime = current
        
        let totalDuration = CMTimeGetSeconds(item.duration)
        duration = totalDuration
        
        if totalDuration > 0 {
            progress = max(0, min(1, current / totalDuration))
        }
        
        // Update lock screen
        updateNowPlayingTime()
        
        // Save podcast progress periodically
        if case .podcast(let episode) = currentContent {
            episode.playbackPositionSec = current
            episode.lastPlayed = Date()
            
            // Mark as completed if 95% through
            if progress >= 0.95 {
                episode.isCompleted = true
            }
        }
        
        // Update music play count
        if case .music(let song) = currentContent, current > 0 {
            song.lastPlayed = Date()
        }
    }
    
    // MARK: - Music Playback
    
    func playMusic(_ songs: [Song], startAt index: Int) {
        guard !songs.isEmpty, songs.indices.contains(index) else { return }
        
        // Stop any current playback
        stopCurrentPlayback()
        
        baselineSequence = songs
        musicHistory = Array(songs.prefix(index))
        musicQueue = Array(songs.dropFirst(index + 1))
        
        let selected = songs[index]
        updateQueueForShuffle(using: selected)
        
        Task { await startMusic(song: selected) }
    }
    
    private func startMusic(song: Song) async {
        let url = musicFileURL(for: song)
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Missing file for \(song.title)")
            if !musicQueue.isEmpty { nextTrack() } else { stop() }
            return
        }
        
        currentContent = .music(song)
        song.lastPlayed = Date()
        song.playCount += 1
        
        await playAudioFile(at: url)
        updateNowPlaying()
        LiveActivityManager.shared.startOrUpdate(song: song, progress: 0, isPlaying: true)
    }
    
    private func musicFileURL(for song: Song) -> URL {
        LibraryImportService.libraryFolderURL.appendingPathComponent(song.filePath)
    }
    
    // MARK: - Podcast Playback
    
    func playPodcast(episode: Episode) {
        // Stop any current playback
        stopCurrentPlayback()
        
        Task { await startPodcast(episode: episode) }
    }
    
    private func startPodcast(episode: Episode) async {
        // Determine URL (local file or stream)
        let url: URL
        if let localPath = episode.localFileURL, FileManager.default.fileExists(atPath: localPath) {
            url = URL(fileURLWithPath: localPath)
        } else if let audioURL = episode.audioURLValue {
            url = audioURL
        } else {
            print("No valid audio URL for episode \(episode.title)")
            return
        }
        
        currentContent = .podcast(episode)
        episode.lastPlayed = Date()
        
        await playAudioFile(at: url)
        
        // Seek to saved position if exists
        if episode.playbackPositionSec > 0 {
            seek(to: episode.playbackPositionSec)
        }
        
        // Apply saved playback speed
        player?.rate = isPlaying ? playbackSpeed : 0
        
        updateNowPlaying()
    }
    
    // MARK: - Core Playback Control
    
    private func playAudioFile(at url: URL) async {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
        
        let item = AVPlayerItem(url: url)
        player?.replaceCurrentItem(with: item)
        player?.volume = Float(volume)
        
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.playbackEnded()
        }
        
        // Apply playback rate based on content type
        if case .podcast = currentContent {
            player?.rate = playbackSpeed
        } else {
            player?.play()
        }
        
        isPlaying = true
        progress = 0
    }
    
    func togglePlayPause() {
        guard case .music = currentContent else {
            guard case .podcast = currentContent else { return }
            isPlaying ? pause() : resume()
            return
        }
        isPlaying ? pause() : resume()
    }
    
    func resume() {
        if case .none = currentContent { return }
        
        if case .podcast = currentContent {
            player?.rate = playbackSpeed
        } else {
            player?.play()
        }
        
        isPlaying = true
        updateNowPlaying()
    }
    
    func pause() {
        if case .none = currentContent { return }
        player?.pause()
        isPlaying = false
        updateNowPlaying()
    }
    
    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        isPlaying = false
        updateNowPlaying()
    }
    
    private func stopCurrentPlayback() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        isPlaying = false
        
        // Clear music queue if switching from music
        if case .music = currentContent {
            musicQueue.removeAll()
            musicHistory.removeAll()
            baselineSequence.removeAll()
        }
    }
    
    func seek(to seconds: TimeInterval) {
        guard let item = player?.currentItem else { return }
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        item.seek(to: time) { [weak self] _ in
            self?.updateNowPlaying()
        }
    }
    
    func seek(normalized: Double) {
        let target = max(0, min(1, normalized)) * duration
        seek(to: target)
    }
    
    // MARK: - Music Queue Management
    
    func nextTrack() {
        guard case .music(let currentSong) = currentContent else { return }
        
        if let next = musicQueue.first {
            musicHistory.append(currentSong)
            musicQueue.removeFirst()
            Task { await startMusic(song: next) }
        } else if repeatMode == .all, !baselineSequence.isEmpty {
            playMusic(baselineSequence, startAt: 0)
        } else {
            stop()
        }
    }
    
    func prevTrack() {
        guard case .music(let currentSong) = currentContent else { return }
        
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        
        guard let prev = musicHistory.popLast() else {
            seek(to: 0)
            return
        }
        
        musicQueue.insert(currentSong, at: 0)
        Task { await startMusic(song: prev) }
    }
    
    func toggleShuffle() {
        isShuffled.toggle()
        guard case .music(let current) = currentContent else { return }
        updateQueueForShuffle(using: current)
    }
    
    func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }
    
    private func updateQueueForShuffle(using anchor: Song) {
        if baselineSequence.isEmpty {
            baselineSequence = musicHistory + [anchor] + musicQueue
        }
        
        let played = Set(musicHistory.map { $0.persistentID } + [anchor.persistentID])
        
        if isShuffled {
            var upcoming = baselineSequence.filter { !played.contains($0.persistentID) }
            upcoming.shuffle()
            musicQueue = upcoming
        } else {
            guard let idx = baselineSequence.firstIndex(where: { $0.persistentID == anchor.persistentID }) else {
                musicQueue = baselineSequence.filter { !played.contains($0.persistentID) }
                return
            }
            let nextIndex = baselineSequence.index(after: idx)
            if nextIndex < baselineSequence.endIndex {
                musicQueue = Array(baselineSequence[nextIndex...]).filter { !played.contains($0.persistentID) }
            } else {
                musicQueue = []
            }
        }
    }
    
    // MARK: - Podcast Controls
    
    func skipForward(_ seconds: TimeInterval = 30) {
        guard case .podcast = currentContent else { return }
        let newTime = min(duration, currentTime + seconds)
        seek(to: newTime)
        Haptics.light()
    }
    
    func skipBackward(_ seconds: TimeInterval = 15) {
        guard case .podcast = currentContent else { return }
        let newTime = max(0, currentTime - seconds)
        seek(to: newTime)
        Haptics.light()
    }
    
    // MARK: - Playback End Handling
    
    private func playbackEnded() {
        switch currentContent {
        case .music(let song):
            handleMusicEnded(song: song)
        case .podcast(let episode):
            handlePodcastEnded(episode: episode)
        case .none:
            break
        }
    }
    
    private func handleMusicEnded(song: Song) {
        switch repeatMode {
        case .one:
            Task { await startMusic(song: song) }
        case .all:
            if !musicQueue.isEmpty {
                nextTrack()
            } else if !baselineSequence.isEmpty {
                playMusic(baselineSequence, startAt: 0)
            } else {
                stop()
            }
        case .off:
            if !musicQueue.isEmpty {
                nextTrack()
            } else {
                stop()
            }
        }
    }
    
    private func handlePodcastEnded(episode: Episode) {
        episode.isCompleted = true
        episode.playbackPositionSec = 0
        stop()
    }
    
    // MARK: - Now Playing Info
    
    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        
        c.playCommand.isEnabled = true
        c.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        
        c.pauseCommand.isEnabled = true
        c.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        c.togglePlayPauseCommand.isEnabled = true
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        c.nextTrackCommand.isEnabled = true
        c.nextTrackCommand.addTarget { [weak self] _ in
            guard case .music = self?.currentContent else { return .commandFailed }
            self?.nextTrack()
            return .success
        }
        
        c.previousTrackCommand.isEnabled = true
        c.previousTrackCommand.addTarget { [weak self] _ in
            guard case .music = self?.currentContent else { return .commandFailed }
            self?.prevTrack()
            return .success
        }
        
        c.changePlaybackPositionCommand.isEnabled = true
        c.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
        
        c.skipForwardCommand.isEnabled = true
        c.skipForwardCommand.preferredIntervals = [30]
        c.skipForwardCommand.addTarget { [weak self] _ in
            guard case .podcast = self?.currentContent else { return .commandFailed }
            self?.skipForward(30)
            return .success
        }
        
        c.skipBackwardCommand.isEnabled = true
        c.skipBackwardCommand.preferredIntervals = [15]
        c.skipBackwardCommand.addTarget { [weak self] _ in
            guard case .podcast = self?.currentContent else { return .commandFailed }
            self?.skipBackward(15)
            return .success
        }
    }
    
    private func updateNowPlaying() {
        var info: [String: Any] = [:]
        
        switch currentContent {
        case .music(let song):
            info[MPMediaItemPropertyTitle] = song.title
            info[MPMediaItemPropertyArtist] = song.artistName
            info[MPMediaItemPropertyAlbumTitle] = song.albumName
            info[MPMediaItemPropertyPlaybackDuration] = song.duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            
            if let data = song.artworkData, let img = UIImage(data: data) {
                info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            }
            
        case .podcast(let episode):
            info[MPMediaItemPropertyTitle] = episode.title
            info[MPMediaItemPropertyArtist] = episode.podcast?.title ?? "Podcast"
            info[MPMediaItemPropertyAlbumTitle] = episode.podcast?.author ?? ""
            
            if let dur = episode.duration {
                info[MPMediaItemPropertyPlaybackDuration] = dur
            }
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(playbackSpeed) : 0.0
            
            // Try to load artwork
            if let urlString = episode.artworkURL ?? episode.podcast?.artworkURL,
               let url = URL(string: urlString) {
                Task {
                    if let (data, _) = try? await URLSession.shared.data(from: url),
                       let img = UIImage(data: data) {
                        await MainActor.run {
                            var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                            updatedInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
                            MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                        }
                    }
                }
            }
            
        case .none:
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func updateNowPlayingTime() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    // MARK: - Cleanup
    
    func clearAll() {
        stopCurrentPlayback()
        currentContent = .none
        musicQueue.removeAll()
        musicHistory.removeAll()
        baselineSequence.removeAll()
        isShuffled = false
        repeatMode = .off
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        LiveActivityManager.shared.end()
    }
}

