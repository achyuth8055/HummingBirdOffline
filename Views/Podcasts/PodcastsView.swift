import SwiftUI
import SwiftData

struct PodcastsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = PodcastBrowseViewModel()
    @State private var isFetchingFeed = false
    @State private var activeDetail: PodcastDetailPayload?
    @State private var recommendedPodcasts: [Podcast] = []
    @State private var isLoading = true
    @State private var searchText: String = ""
    @AppStorage("selectedTopics") private var selectedTopicsString: String = ""
    
    @Query private var allStoredPodcasts: [Podcast]
    @Query private var allEpisodes: [Episode]

    private var selectedTopics: [String] {
        selectedTopicsString.split(separator: ",").map { String($0).lowercased() }
    }
    
    private var continueListening: [Episode] {
        allEpisodes
            .filter { $0.playbackProgress > 0 && $0.playbackProgress < 0.95 }
            .sorted { ($0.lastPlayedDate ?? Date.distantPast) > ($1.lastPlayedDate ?? Date.distantPast) }
            .prefix(5)
            .compactMap { $0 }
    }
    
    private var localPodcastLibrary: [Podcast] {
        allStoredPodcasts.filter { !$0.title.isEmpty }
    }
    
    private var activeSearchTerm: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isShowingSearchResults: Bool {
        !activeSearchTerm.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.primaryBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar
                    Group {
                        if isShowingSearchResults { searchResultsView.transition(.opacity) }
                        else if isLoading { shimmerLoading.frame(maxWidth: .infinity, maxHeight: .infinity) }
                        else { mainContent }
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: isShowingSearchResults)
                // iOS 17 deprecates the older onChange signature; use 2-parameter closure
                .onChange(of: searchText) { oldValue, newValue in
                    guard newValue != oldValue else { return }
                    viewModel.updateSearchTerm(newValue)
                }
                if isFetchingFeed { fetchingOverlay }
            }
            .toolbar { refreshToolbar }
            .navigationTitle("Browse")
            .navigationBarTitleDisplayMode(.large)
            .task { await initialLoadIfNeeded() }
            .refreshable { await manualRefresh() }
            .navigationDestination(item: $activeDetail) { payload in
                PodcastDetailView(
                    podcast: payload.podcast,
                    episodes: payload.episodes,
                    suggestions: payload.suggestions
                )
            }
        }
    }
    
    // MARK: - Search
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search podcasts, shows, hosts", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.search)
            if !searchText.isEmpty {
                Button {
                    Haptics.light()
                    searchText = ""
                    viewModel.updateSearchTerm("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondaryBackground.opacity(0.9))
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isSearching {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                
                if let message = viewModel.errorMessage,
                   !viewModel.isSearching,
                   viewModel.results.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "waveform.and.magnifyingglass")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(message)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Try another keyword or adjust your spelling.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                }
                
                ForEach(viewModel.results) { podcast in
                    PodcastSearchResultRow(podcast: podcast) {
                        fetchFeed(for: podcast)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 32) {
                featuredSection
                categoriesSection
                if !continueListening.isEmpty {
                    continueListeningSection
                }
                topEpisodesSection
            }
            .padding(.top, 16)
            .padding(.bottom, 80)
        }
        .transition(.opacity)
    }
    
    // MARK: - Featured Section
    
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Featured")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(viewModel.trending.prefix(5)) { podcast in
                        FeaturedPodcastCard(podcast: podcast) {
                            fetchFeed(for: podcast)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Categories Section
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Categories")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    // See all action
                } label: {
                    Text("See all")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(getCategoryList(), id: \.self) { category in
                        CategoryCapsule(
                            title: category.capitalized,
                            color: getCategoryColor(for: category)
                        ) {
                            // Filter by category
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Continue Listening Section
    
    private var continueListeningSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Continue Listening")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(continueListening) { episode in
                        ContinueListeningCard(episode: episode) {
                            if let podcast = episode.podcast {
                                let id = podcast.id
                                let fetched = (try? modelContext.fetch(FetchDescriptor<Episode>())) ?? []
                                let ordered = fetched.filter { $0.podcastID == id }
                                    .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
                                let vm = PodcastPlayerViewModel.shared
                                vm.play(episode: episode, in: ordered)
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { vm.showFullPlayer = true }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Top Episodes Section
    
    private var topEpisodesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Episodes")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                ForEach(Array(recommendedPodcasts.prefix(8).enumerated()), id: \.element.id) { index, podcast in
                    TopEpisodeRow(podcast: podcast, index: index + 1) {
                        // Default to fetching feed, then auto-play most recent episode
                        fetchFeed(for: podcast)
                        if let episodes = try? modelContext.fetch(FetchDescriptor<Episode>()), let first = episodes.filter({ $0.podcastID == podcast.id }).sorted(by: { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }).first {
                            let ordered = episodes.filter { $0.podcastID == podcast.id }.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
                            let vm = PodcastPlayerViewModel.shared
                            vm.play(episode: first, in: ordered)
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { vm.showFullPlayer = true }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)
            Text("Loading personalized content...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .transition(.opacity)
    }

    // Shimmer placeholders for improved perceived performance
    private var shimmerLoading: some View {
        ScrollView {
            VStack(spacing: 32) {
                ForEach(0..<3, id: \.self) { _ in shimmerBlock }
            }
            .padding(.top, 32)
            .padding(.bottom, 80)
        }
        .redacted(reason: .placeholder)
        .shimmer()
    }

    private var shimmerBlock: some View {
        VStack(alignment: .leading, spacing: 18) {
            RoundedRectangle(cornerRadius: 8).fill(Color.secondaryBackground).frame(width: 160, height: 22)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 20).fill(Color.secondaryBackground).frame(width: 180, height: 180)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Fetching Overlay
    
    private var fetchingOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .zIndex(1)
            
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Loading episodes…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground).opacity(0.96))
            )
            .shadow(color: .black.opacity(0.25), radius: 18, y: 12)
            .zIndex(2)
        }
    }
    
    // MARK: - Helper Functions
    
    private func initialLoadIfNeeded() async {
        guard isLoading else { return }
        if viewModel.trending.isEmpty { viewModel.loadTrending() }
        await MainActor.run {
            buildRecommendations()
            withAnimation(.easeInOut(duration: 0.35)) { isLoading = false }
        }
    }

    private func buildRecommendations() {
        // Build list: followed podcasts first then most recently refreshed
        let followed = localPodcastLibrary.filter { $0.isFollowing }
            .sorted { ($0.dateFollowed ?? .distantPast) > ($1.dateFollowed ?? .distantPast) }
        let recency = localPodcastLibrary.sorted { $0.lastRefreshed > $1.lastRefreshed }
        var combined: [Podcast] = []
        combined.append(contentsOf: followed)
        for p in recency where !combined.contains(where: { $0.id == p.id }) { combined.append(p) }
        if !selectedTopics.isEmpty {
            let filtered = combined.filter { pod in
                pod.categories.contains { selectedTopics.contains($0.lowercased()) }
            }
            recommendedPodcasts = filtered.isEmpty ? combined : filtered
        } else {
            recommendedPodcasts = combined
        }
    }
    
    private func getCategoryList() -> [String] {
        if !selectedTopics.isEmpty { return selectedTopics }
        let allCats = localPodcastLibrary.flatMap { $0.categories.map { $0.lowercased() } }
        let freq = Dictionary(grouping: allCats) { $0 }.mapValues { $0.count }
        let sorted = freq.sorted { $0.value > $1.value }.map { $0.key }
        return Array(sorted.prefix(8))
    }
    
    private func getCategoryColor(for category: String) -> Color {
        let colors: [Color] = [
            .green, .blue, .orange, .purple, .pink, .cyan, .indigo
        ]
        let hash = category.hashValue
        return colors[abs(hash) % colors.count]
    }

    private func fetchFeed(for podcast: Podcast) {
        guard !isFetchingFeed else { return }
        isFetchingFeed = true
        Task {
            let finish: @MainActor () -> Void = { withAnimation { isFetchingFeed = false } }
            do {
                let result = try await PodcastFeedService.fetchFeed(for: podcast)
                await MainActor.run {
                    let stored = upsertPodcast(result.podcast)
                    let eps = upsertEpisodes(result.episodes, for: stored)
                    let suggestions = PodcastAPIService.suggested(excluding: [stored.id])
                    activeDetail = PodcastDetailPayload(podcast: stored, episodes: eps, suggestions: suggestions)
                    finish()
                }
            } catch {
                print("Podcast feed error: \(error.localizedDescription)")
                await MainActor.run { finish() }
            }
        }
    }

    private func upsertPodcast(_ incoming: Podcast) -> Podcast {
        let incomingID = incoming.id
        let descriptor = FetchDescriptor<Podcast>(
            predicate: #Predicate<Podcast> { podcast in
                podcast.id == incomingID
            }
        )
        
        if let matches = try? modelContext.fetch(descriptor),
           let existing = matches.first {
            existing.title = incoming.title
            existing.author = incoming.author
            existing.artworkURL = incoming.artworkURL
            existing.categories = incoming.categories
            existing.podcastDescription = incoming.podcastDescription
            existing.lastRefreshed = incoming.lastRefreshed
            existing.isFollowing = incoming.isFollowing
            existing.dateFollowed = incoming.dateFollowed
            return existing
        }
        
        let stored = Podcast(
            id: incoming.id,
            title: incoming.title,
            author: incoming.author,
            artworkURL: incoming.artworkURL,
            feedURL: incoming.feedURL,
            categories: incoming.categories,
            description: incoming.podcastDescription,
            lastRefreshed: incoming.lastRefreshed,
            isFollowing: incoming.isFollowing,
            dateFollowed: incoming.dateFollowed
        )
        modelContext.insert(stored)
        return stored
    }

    private func upsertEpisodes(_ episodes: [Episode], for podcast: Podcast) -> [Episode] {
        var stored: [Episode] = []
        for ep in episodes {
            let episodeID = ep.id
            let descriptor = FetchDescriptor<Episode>(
                predicate: #Predicate<Episode> { episode in
                    episode.id == episodeID
                }
            )
            
            if let matches = try? modelContext.fetch(descriptor),
               let existing = matches.first {
                existing.title = ep.title
                existing.publishedAt = ep.publishedAt
                existing.duration = ep.duration
                existing.episodeDescription = ep.episodeDescription
                existing.audioURL = ep.audioURL
                existing.artworkURL = ep.artworkURL
                existing.podcast = podcast
                existing.localFileURL = ep.localFileURL
                existing.playbackPositionSec = ep.playbackPositionSec
                existing.isDownloaded = ep.isDownloaded
                existing.downloadProgress = ep.downloadProgress
                existing.dateAdded = ep.dateAdded
                existing.lastPlayed = ep.lastPlayed
                existing.isCompleted = ep.isCompleted
                existing.playbackProgress = ep.playbackProgress
                existing.lastPlayedDate = ep.lastPlayedDate
                existing.transcriptJSON = ep.transcriptJSON
                existing.chaptersJSON = ep.chaptersJSON
                stored.append(existing)
            } else {
                let newEpisode = Episode(
                    id: ep.id,
                    podcastID: podcast.id,
                    title: ep.title,
                    publishedAt: ep.publishedAt,
                    duration: ep.duration,
                    description: ep.episodeDescription,
                    audioURL: ep.audioURL,
                    artworkURL: ep.artworkURL,
                    localFileURL: ep.localFileURL,
                    playbackPositionSec: ep.playbackPositionSec,
                    isDownloaded: ep.isDownloaded,
                    downloadProgress: ep.downloadProgress,
                    dateAdded: ep.dateAdded,
                    lastPlayed: ep.lastPlayed,
                    isCompleted: ep.isCompleted,
                    transcriptJSON: ep.transcriptJSON,
                    chaptersJSON: ep.chaptersJSON,
                    playbackProgress: ep.playbackProgress,
                    lastPlayedDate: ep.lastPlayedDate
                )
                newEpisode.podcast = podcast
                modelContext.insert(newEpisode)
                stored.append(newEpisode)
            }
        }
        try? modelContext.save()
        return stored.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
    }

    private func manualRefresh() async {
        await MainActor.run { withAnimation { isLoading = true } }
        viewModel.loadTrending()
        await initialLoadIfNeeded()
    }

    // Toolbar content builder replacement
    @ToolbarContentBuilder private var refreshToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if !isLoading && !isFetchingFeed {
                Button { Task { await manualRefresh() } } label: { Image(systemName: "arrow.clockwise") }
            } else {
                ProgressView().scaleEffect(0.8)
            }
        }
    }
}


// MARK: - Featured Podcast Card
private struct FeaturedPodcastCard: View {
    let podcast: Podcast
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            AsyncImage(url: URL(string: podcast.artworkURL ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Color(.secondarySystemBackground)
                        .overlay(Image(systemName: "waveform").font(.system(size: 40)).foregroundColor(.secondary.opacity(0.5)))
                }
            }
            .frame(width: 280, height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(podcast.author)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(podcast.title)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(16)
            }
            .shadow(color: .black.opacity(0.2), radius: 12, y: 8)
            .frame(width: 280)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}


// MARK: - Category Capsule
private struct CategoryCapsule: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule().fill(color.gradient))
                .shadow(color: color.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}


// MARK: - Continue Listening Card
private struct ContinueListeningCard: View {
    let episode: Episode
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                AsyncImage(url: URL(string: episode.artworkURL ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color(.secondarySystemBackground)
                            .overlay(Image(systemName: "waveform").foregroundColor(.secondary))
                    }
                }
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if let podcast = episode.podcast {
                        Text(podcast.title)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.secondarySystemBackground)).frame(height: 3)
                            Capsule().fill(Color.green).frame(width: geometry.size.width * episode.playbackProgress, height: 3)
                        }
                    }
                    .frame(height: 3)
                }
            }
            .frame(width: 160)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}


// MARK: - Top Episode Row
private struct TopEpisodeRow: View {
    let podcast: Podcast
    let index: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: podcast.artworkURL ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color(.secondarySystemBackground)
                            .overlay(Image(systemName: "waveform").foregroundColor(.secondary))
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(podcast.author)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(podcast.title)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}


// MARK: - Podcast Search Result Row
private struct PodcastSearchResultRow: View {
    let podcast: Podcast
    let onTap: () -> Void
    
    private var categoriesText: String? {
        let filtered = podcast.categories.filter { !$0.isEmpty }
        guard !filtered.isEmpty else { return nil }
        let display = filtered.prefix(2).joined(separator: " • ")
        return display
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: podcast.artworkURL ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color.secondaryBackground
                            .overlay(
                                Image(systemName: "waveform")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(podcast.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(podcast.author)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if let categoriesText {
                        Text(categoriesText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.secondaryBackground)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}


// MARK: - Scale Button Style
private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}


// MARK: - Podcast Detail Payload
private struct PodcastDetailPayload: Identifiable, Hashable {
    let podcast: Podcast
    let episodes: [Episode]
    let suggestions: [Podcast]

    var id: String { podcast.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static func == (lhs: PodcastDetailPayload, rhs: PodcastDetailPayload) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Shimmer Modifier
private struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -200
    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geo in
                LinearGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.0), Color.white.opacity(0.28), Color.white.opacity(0.0)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .rotationEffect(.degrees(25))
                .offset(x: phase)
                .frame(width: geo.size.width * 1.8, height: geo.size.height * 1.4)
                .clipped()
                .onAppear {
                    withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                        phase = geo.size.width * 1.8
                    }
                }
            }
            .blendMode(.plusLighter)
        )
    }
}
private extension View { func shimmer() -> some View { modifier(Shimmer()) } }
