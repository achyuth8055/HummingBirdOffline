import Foundation
import MediaPlayer

// Coordinates exclusive playback between music (PlayerViewModel)
// and podcasts (PodcastPlayerViewModel). Only one plays at a time.
enum PlaybackCoordinator {
    enum MediaType { case music, podcast }
    static let mediaTypeDidChange = Notification.Name("HBMediaTypeDidChange")
    private static func post(_ type: MediaType) {
        NotificationCenter.default.post(name: mediaTypeDidChange, object: type)
    }

    static func activateMusic() {
        // Pause podcast playback when music starts or resumes
        let podcast = PodcastPlayerViewModel.shared
        podcast.pause()
        // Ensure Now Playing shows music item only; the respective view model
        // will set MPNowPlayingInfoCenter on its next update.
        post(.music)
    }

    static func activatePodcast() {
        // Pause music when a podcast starts or resumes
        let music = PlayerViewModel.shared
        music.pause()
        // Podcast view model manages Now Playing info.
        post(.podcast)
    }
}

