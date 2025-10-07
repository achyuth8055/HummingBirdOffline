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
            Task { await activity.update(using: state) }
        } else {
            let attributes = PlayerActivityAttributes()
            do {
                activity = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
            } catch {
                activity = nil
            }
        }
    }

    func end() {
        guard let activity else { return }
        Task { await activity.end(dismissalPolicy: .immediate) }
        self.activity = nil
    }
}
