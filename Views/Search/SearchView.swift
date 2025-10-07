import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var player: PlayerViewModel
    @StateObject private var viewModel = SearchViewModel()
    @AppStorage("searchHistory") private var searchHistoryData: Data = Data()

    private let categories = [
        "Chill", "Workout", "Focus", "Rock",
        "Pop", "Classical", "Jazz", "Ambient"
    ]

    private var searchHistory: [String] {
        (try? JSONDecoder().decode([String].self, from: searchHistoryData)) ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField

            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            contentSection
                .animation(.snappy(duration: 0.22, extraBounce: 0.05), value: viewModel.results.count)
                .animation(.snappy(duration: 0.22, extraBounce: 0.05), value: viewModel.isSearching)
                .animation(.snappy(duration: 0.22, extraBounce: 0.05), value: viewModel.query)
        }
        .background(Color.primaryBackground.ignoresSafeArea())
        .navigationTitle("Search")
        .task { viewModel.loadSongs(context: context) }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondaryText)
            TextField("Search songs, artists, albums", text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .onSubmit { executeSearch(with: viewModel.query) }
            if !viewModel.query.isEmpty {
                Button {
                    Haptics.light()
                    viewModel.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondaryText)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondaryBackground)
        )
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    @ViewBuilder
    private var contentSection: some View {
        if viewModel.query.isEmpty {
            emptyStateContent
        } else if viewModel.isSearching && viewModel.results.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Searching your library…")
                    .font(HBFont.body(13))
                    .foregroundColor(.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.bottom, 60)
        } else if viewModel.results.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "music.note")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.secondaryText)
                Text("No matches")
                    .font(HBFont.heading(20))
                Text("Try a different title, artist, or album.")
                    .font(HBFont.body(13))
                    .foregroundColor(.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.bottom, 60)
        } else {
            resultsList
        }
    }

    private var emptyStateContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !searchHistory.isEmpty {
                    historySection
                }
                categoriesSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Searches")
                .font(HBFont.heading(18))
                .foregroundColor(.primaryText)

            ForEach(searchHistory, id: \.self) { term in
                Button { selectHistory(term) } label: {
                    historyRow(for: term)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func historyRow(for term: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.secondaryText)
            Text(term)
                .font(HBFont.body(14))
                .foregroundColor(.primaryText)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondaryBackground)
        )
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Browse Categories")
                .font(HBFont.heading(18))
                .foregroundColor(.primaryText)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2),
                spacing: 14
            ) {
                ForEach(categories, id: \.self) { category in
                    Text(category)
                        .font(HBFont.body(16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 82)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.secondaryBackground)
                                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                        )
                        .foregroundColor(.primaryText)
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.isSearching {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }

                ForEach(viewModel.results, id: \.persistentID) { song in
                    Button {
                        Haptics.light()
                        play(song: song)
                    } label: {
                        SearchResultRow(song: song)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    private func play(song: Song) {
        guard let index = viewModel.results.firstIndex(where: { $0.persistentID == song.persistentID }) else { return }
        player.play(songs: viewModel.results, startAt: index)
    }

    private func executeSearch(with term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.query = trimmed
        addToHistory(trimmed)
    }

    private func selectHistory(_ term: String) {
        Haptics.light()
        executeSearch(with: term)
    }

    private func addToHistory(_ term: String) {
        var history = searchHistory
        history.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        history.insert(term, at: 0)
        if history.count > 10 {
            history = Array(history.prefix(10))
        }
        storeHistory(history)
    }

    private func storeHistory(_ history: [String]) {
        searchHistoryData = (try? JSONEncoder().encode(history)) ?? Data()
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(message)
                .font(HBFont.body(12, weight: .medium))
                .foregroundColor(.primaryText)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red.opacity(0.18))
        )
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // Removed bottom spacer; the only mini-player host lives in MainTabView
}

private struct SearchResultRow: View {
    let song: Song

    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(data: song.artworkData)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(HBFont.body(15, weight: .semibold))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(HBFont.body(13))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)

                Text(song.albumName)
                    .font(HBFont.body(11))
                    .foregroundColor(.secondaryText.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "play.fill")
                .foregroundColor(.accentGreen)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.secondaryBackground)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        )
    }
}
