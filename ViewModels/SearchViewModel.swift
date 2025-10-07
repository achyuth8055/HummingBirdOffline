import Foundation
import Combine
import SwiftData

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet { scheduleSearch() }
    }
    @Published private(set) var results: [Song] = []
    @Published private(set) var isSearching: Bool = false
    @Published private(set) var errorMessage: String?

    private var allSongs: [Song] = []
    private var searchTask: Task<Void, Never>?

    deinit { searchTask?.cancel() }

    func loadSongs(context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<Song>(
                sortBy: [SortDescriptor(\.title, order: .forward)]
            )
            allSongs = try context.fetch(descriptor)
            errorMessage = nil
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                scheduleSearch()
            }
        } catch {
            allSongs = []
            results = []
            isSearching = false
            errorMessage = "Failed to load songs: \(error.localizedDescription)"
        }
    }

    func refreshLibrary(context: ModelContext) {
        loadSongs(context: context)
    }

    func clear() {
        searchTask?.cancel()
        query = ""
        results = []
        errorMessage = nil
        isSearching = false
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !term.isEmpty else {
            results = []
            isSearching = false
            errorMessage = nil
            return
        }

        guard !allSongs.isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        let searchTerm = term

        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard let self, !Task.isCancelled else { return }
            let filtered = self.filteredSongs(for: searchTerm)
            self.results = filtered
            self.isSearching = false
            if self.errorMessage != nil, !filtered.isEmpty {
                self.errorMessage = nil
            }
        }
    }

    private func filteredSongs(for term: String) -> [Song] {
        let normalizedTokens = normalizedTokens(from: term)
        guard !normalizedTokens.isEmpty else { return [] }

        return allSongs.filter { song in
            let title = normalize(song.title)
            let artist = normalize(song.artistName)
            let album = normalize(song.albumName)
            return normalizedTokens.allSatisfy { token in
                title.contains(token) || artist.contains(token) || album.contains(token)
            }
        }
    }

    private func normalizedTokens(from text: String) -> [String] {
        let normalized = normalize(text)
        return normalized.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    private func normalize(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
