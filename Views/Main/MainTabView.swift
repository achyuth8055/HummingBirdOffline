import SwiftUI
import UIKit

struct MainTabView: View {
    private enum Tab: String, CaseIterable {
        case home, library, podcasts, search, settings
    }
    
    @EnvironmentObject private var player: PlayerViewModel
    @State private var selectedTab: Tab = .home
    
    // Namespace for the matched geometry animation
    @Namespace private var playerAnimation

    private let tabBarHeight: CGFloat = 49
    private let miniSpacing: CGFloat = 12
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(Tab.home)
                    .tabItem { Label("Home", systemImage: "house.fill") }
                
                LibraryView()
                    .tag(Tab.library)
                    .tabItem { Label("Library", systemImage: "music.note.list") }
                
                PodcastsView()
                    .tag(Tab.podcasts)
                    .tabItem { Label("Podcasts", systemImage: "dot.radiowaves.left.and.right") }
                
                SearchView()
                    .tag(Tab.search)
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                
                SettingsView()
                    .tag(Tab.settings)
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
            .toolbarColorScheme(.dark, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(Color.secondaryBackground, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Reserve space for mini player when it's visible
                if player.currentSong != nil {
                    Color.clear
                        .frame(height: miniPlayerHeight)
                }
            }

            if player.currentSong != nil {
                VStack {
                    Spacer()
                    MiniPlayerView(namespace: playerAnimation) {
                        withAnimation(.hbSpringLarge) { player.showFullPlayer = true }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, miniSpacing)
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    )
                )
                .zIndex(1)
            }
        }
        .fullScreenCover(isPresented: $player.showFullPlayer) {
            // This presents the full-screen player when toggled
            NowPlayingView(namespace: playerAnimation)
                .presentationBackground(.clear)
        }
        // Smooth animation for mini player appearance/disappearance
        .animation(
            .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1),
            value: player.currentSong != nil
        )
    }

    private var miniPlayerHeight: CGFloat {
        // Mini player content height (64) + progress bar (2) + spacing (12)
        return 78
    }
}

private extension UIApplication {
    var firstKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
    }
}
