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

    // Initialize the ModelContainer asynchronously to avoid blocking the main thread during startup.
    @State private var container: ModelContainer? = nil

    init() {
        // Ensure Firebase is configured as early as possible (AppDelegate also configures it).
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootGateView()
                        .environmentObject(authVM)
                        .environmentObject(player)
                        .modelContainer(container)
                        .tint(ThemeManager.shared.accentColorSwiftUI)
                } else {
                    // Lightweight startup placeholder while ModelContainer initializes
                    ZStack {
                        Color.primaryBackground.ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Starting HummingBird…")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .onAppear {
                // Ensure audio session is configured when UI appears
                Task { PlayerViewModel.configureAudioSession() }
            }
            .task {
                // Create the ModelContainer off the main thread where possible, then assign on the main actor.
                guard container == nil else { return }
                do {
                    let configuration = ModelConfiguration()
                    let created = try ModelContainer(
                        for: Song.self,
                        Artist.self,
                        Album.self,
                        Playlist.self,
                        Podcast.self,
                        Episode.self,
                        configurations: configuration
                    )
                    await MainActor.run { container = created }
                } catch {
                    // If container creation fails, crash early so developer sees the error (mimics prior behavior).
                    fatalError("Failed to create ModelContainer: \(error)")
                }
            }
        }
    }
}
