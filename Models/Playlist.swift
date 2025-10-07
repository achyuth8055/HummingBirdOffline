import Foundation
import SwiftData

@Model
final class Playlist {
    @Attribute(.unique) var id: UUID
    var name: String
    var dateCreated: Date
    var artworkData: Data?
    @Relationship var songs: [Song] = []
    init(id: UUID = UUID(), name: String, dateCreated: Date = .now, artworkData: Data? = nil) {
        self.id = id; self.name = name; self.dateCreated = dateCreated; self.artworkData = artworkData
    }
}
