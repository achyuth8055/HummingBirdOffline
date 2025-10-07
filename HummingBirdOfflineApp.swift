//
//  HummingBirdOfflineApp.swift
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct HummingBirdOfflineApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate   // ← important

    @StateObject private var authVM = AuthViewModel()
    @StateObject private var player = PlayerViewModel.shared

    private let container: ModelContainer

    init() {
        // Ensure Firebase is configured as early as possible
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        let config = ModelConfiguration(cloudKitDatabase: .automatic)
        do {
            container = try ModelContainer(
                for: Song.self, Artist.self, Album.self, Playlist.self, Podcast.self, Episode.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        PlayerViewModel.configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            RootGateView()
                .environmentObject(authVM)
                .environmentObject(player)
                .modelContainer(container)
                .tint(ThemeManager.shared.accentColorSwiftUI)
                .onAppear {
                    Task { PlayerViewModel.configureAudioSession() }
                }
        }
    }
}
