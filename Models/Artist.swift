import Foundation
import SwiftData

@Model
final class Artist {
    @Attribute(.unique) var name: String
    @Relationship(inverse: \Song.artist) var songs: [Song] = []
    init(name: String) { self.name = name }
}
