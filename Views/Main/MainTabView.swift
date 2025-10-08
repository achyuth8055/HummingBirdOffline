import SwiftUI
import SwiftData

struct MainTabView: View {
    @EnvironmentObject private var player: PlayerViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var podcastPlayer = PodcastPlayerViewModel.shared
    @State private var selectedTab: Tab = .home
    @State private var showFullMusicPlayer = false
    @State private var showFullPodcastPlayer = false
    @Namespace private var musicPlayerNamespace
    @Namespace private var podcastPlayerNamespace
    
    enum Tab: String, CaseIterable {
        case home = "Home"
        case library = "Library"
        case podcasts = "Podcasts"
        case search = "Search"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .library: return "music.note.list"
            case .podcasts: return "mic.fill"
            case .search: return "magnifyingglass"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Tab Content
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(Tab.home)
                    .tabItem {
                        Label(Tab.home.rawValue, systemImage: Tab.home.icon)
                    }
                
                LibraryView()
                    .tag(Tab.library)
                    .tabItem {
                        Label(Tab.library.rawValue, systemImage: Tab.library.icon)
                    }
                
                PodcastsView()
                    .tag(Tab.podcasts)
                    .tabItem {
                        Label(Tab.podcasts.rawValue, systemImage: Tab.podcasts.icon)
                    }
                
                SearchView()
                    .tag(Tab.search)
                    .tabItem {
                        Label(Tab.search.rawValue, systemImage: Tab.search.icon)
                    }
                
                SettingsView()
                    .tag(Tab.settings)
                    .tabItem {
                        Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                    }
            }
            .tint(.accentGreen)
            
            // Mini Players - Show podcast OR music player (whichever is active)
            // Podcast player takes precedence when both are available
            VStack(spacing: 0) {
                Spacer()
                
                if podcastPlayer.currentEpisode != nil && !showFullPodcastPlayer {
                    PodcastMiniPlayerView {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            showFullPodcastPlayer = true
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if player.currentSong != nil && !showFullMusicPlayer {
                    MiniPlayerView(namespace: musicPlayerNamespace) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            showFullMusicPlayer = true
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: podcastPlayer.currentEpisode != nil)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: player.currentSong != nil)
        }
        .fullScreenCover(isPresented: $showFullMusicPlayer) {
            FullPlayerView(namespace: musicPlayerNamespace)
        }
        .fullScreenCover(isPresented: $showFullPodcastPlayer) {
            PodcastPlayerView()
        }
        .onChange(of: player.currentSong) { oldValue, newValue in
            if newValue == nil && showFullMusicPlayer {
                showFullMusicPlayer = false
            }
        }
        .onChange(of: podcastPlayer.currentEpisode) { oldValue, newValue in
            if newValue == nil && showFullPodcastPlayer {
                showFullPodcastPlayer = false
            }
        }
        .onChange(of: podcastPlayer.showFullPlayer) { oldValue, newValue in
            if newValue {
                showFullPodcastPlayer = true
                podcastPlayer.showFullPlayer = false // Reset the flag
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(PlayerViewModel.shared)
        .environmentObject(AuthViewModel())
        .modelContainer(previewContainer)
        .preferredColorScheme(.dark)
}
