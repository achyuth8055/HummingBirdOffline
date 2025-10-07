//
//  RecommendationService.swift
//  HummingBirdOffline
//
//  Created by Achyuth on 05/10/25.
//


import Foundation
import SwiftData

enum RecommendationService {
    /// Most played first; falls back to recently added.
    static func mostPlayed(context: ModelContext, limit: Int) -> [Song] {
        let played: [Song] = (try? context.fetch(FetchDescriptor<Song>())) ?? []
        let sorted = played.sorted { $0.playCount > $1.playCount }
        let pick = Array(sorted.prefix(limit))
        if !pick.isEmpty { return pick }
        let recent = played.sorted { $0.dateAdded > $1.dateAdded }
        return Array(recent.prefix(limit))
    }

    static func recentlyAdded(context: ModelContext, limit: Int) -> [Song] {
        let all: [Song] = (try? context.fetch(FetchDescriptor<Song>())) ?? []
        return Array(all.sorted { $0.dateAdded > $1.dateAdded }.prefix(limit))
    }

    static func favorites(context: ModelContext, limit: Int) -> [Song] {
        let favs = (try? context.fetch(FetchDescriptor<Song>(predicate: #Predicate { $0.favorite == true }))) ?? []
        return Array(favs.prefix(limit))
    }
}
