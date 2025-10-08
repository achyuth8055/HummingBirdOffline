//
//  LiveActivityManager.swift
//
import Foundation
import ActivityKit

@available(iOS 16.1, *)
struct PlayerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var artist: String
        var isPlaying: Bool
        var progress: Double
    }
}

final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    func startOrUpdate(song: Song?, progress: Double, isPlaying: Bool) {
        guard #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        LiveActivityCoordinator.shared.startOrUpdate(song: song, progress: progress, isPlaying: isPlaying)
    }

    func end() {
        guard #available(iOS 16.1, *) else { return }
        LiveActivityCoordinator.shared.end()
    }
}

@available(iOS 16.1, *)
private final class LiveActivityCoordinator {
    static let shared = LiveActivityCoordinator()
    private var activity: Activity<PlayerActivityAttributes>?
    private init() {}

    func startOrUpdate(song: Song?, progress: Double, isPlaying: Bool) {
        let state = PlayerActivityAttributes.ContentState(
            title: song?.title ?? "Not Playing",
            artist: song.map { ArtistsListView.primaryArtist(from: $0.artistName) } ?? "",
            isPlaying: isPlaying,
            progress: progress
        )
        if let activity {
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
        } else {
            do {
                let attributes = PlayerActivityAttributes()
                let content = ActivityContent(state: state, staleDate: nil)
                activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            } catch {
                activity = nil
            }
        }
    }

    func end() {
        guard let activity else { return }
        Task {
            await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
        }
        self.activity = nil
    }
}
