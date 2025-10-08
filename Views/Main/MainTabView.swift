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
    @State private var showImportSheet = false
    @Namespace private var musicPlayerNamespace
    
    enum Tab: String, CaseIterable {
        case home = "Home"
        case library = "Library"
        case podcasts = "Podcasts"
        case importTab = "Import"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .library: return "music.note.list"
            case .podcasts: return "mic.fill"
            case .importTab: return "square.and.arrow.down.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
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

                // Import tab is a button that shows a sheet
                Text("Import")
                    .tag(Tab.importTab)
                    .tabItem {
                        Label(Tab.importTab.rawValue, systemImage: Tab.importTab.icon)
                    }

                SettingsView()
                    .tag(Tab.settings)
                    .tabItem {
                        Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                    }
            }
            .tint(.accentGreen)
            .onChange(of: selectedTab) { _, newValue in
                if newValue == .importTab {
                    // Show the import sheet and revert to the previous tab
                    showImportSheet = true
                    selectedTab = Tab.home // Or whichever tab you want to be default
                }
            }
            
            // Mini Players - Only show one at a time based on what's actively playing
            VStack(spacing: 0) {
                Spacer()
                
                // Show podcast mini player only if podcast is playing AND not in Settings/Import
                if podcastPlayer.currentEpisode != nil && 
                   !showFullPodcastPlayer && 
                   selectedTab != .settings &&
                   selectedTab != .importTab &&
                   podcastPlayer.isPlaying {
                    PodcastMiniPlayerView {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            showFullPodcastPlayer = true
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                // Show music mini player only if music is playing AND podcast is not actively playing
                else if player.currentSong != nil && 
                        !showFullMusicPlayer && 
                        !podcastPlayer.isPlaying &&
                        selectedTab != .settings &&
                        selectedTab != .importTab {
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
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: podcastPlayer.isPlaying)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: player.currentSong != nil)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedTab)
        }
        .fullScreenCover(isPresented: $showFullMusicPlayer) {
            FullPlayerView(namespace: musicPlayerNamespace)
        }
        .fullScreenCover(isPresented: $showFullPodcastPlayer) {
            PodcastPlayerView()
        }
        .sheet(isPresented: $showImportSheet) {
            ImportView()
        }
        .onChange(of: player.currentSong) { _, newValue in
            if newValue == nil && showFullMusicPlayer {
                showFullMusicPlayer = false
            }
        }
        .onChange(of: podcastPlayer.currentEpisode) { _, newValue in
            if newValue == nil && showFullPodcastPlayer {
                showFullPodcastPlayer = false
            }
        }
        .onChange(of: podcastPlayer.showFullPlayer) { _, newValue in
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
