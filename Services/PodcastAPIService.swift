import Foundation

enum PodcastAPIService {
    struct Catalog: Decodable {
        let top: [PodcastDTO]
        let trending: [PodcastDTO]
        let suggested: [PodcastDTO]
    }

    struct PodcastDTO: Decodable {
        let id: String
        let title: String
        let author: String
        let artworkURL: String?
        let feedURL: String
        let description: String
        let categories: [String]

        func makeModel() -> Podcast {
            Podcast(
                id: id,
                title: title,
                author: author,
                artworkURL: artworkURL,
                feedURL: feedURL,
                categories: categories,
                description: description
            )
        }
    }

    private static var cachedCatalog: Catalog?

    private static func catalog() throws -> Catalog {
        if let cachedCatalog { return cachedCatalog }
        guard let url = Bundle.main.url(forResource: "podcasts_catalog", withExtension: "json", subdirectory: "Resources/Podcasts") ?? Bundle.main.url(forResource: "podcasts_catalog", withExtension: "json") else {
            throw NSError(domain: "PodcastAPIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing podcasts catalog JSON in bundle."])
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let catalog = try decoder.decode(Catalog.self, from: data)
        cachedCatalog = catalog
        return catalog
    }

    static func topPodcasts() -> [Podcast] {
        (try? catalog().top.map { $0.makeModel() }) ?? []
    }

    static func trendingPodcasts() -> [Podcast] {
        (try? catalog().trending.map { $0.makeModel() }) ?? []
    }

    static func suggested(excluding ids: Set<String> = []) -> [Podcast] {
        guard let list = try? catalog().suggested.map({ $0.makeModel() }) else { return [] }
        return list.filter { !ids.contains($0.id) }
    }

    static func search(term: String) -> [Podcast] {
        guard !term.isEmpty, let catalog = try? catalog() else { return [] }
        let haystack = (catalog.top + catalog.trending + catalog.suggested)
        let normalized = term.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return haystack
            .filter { dto in
                let title = dto.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                let author = dto.author.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                return title.contains(normalized) || author.contains(normalized)
            }
            .map { $0.makeModel() }
    }
}
