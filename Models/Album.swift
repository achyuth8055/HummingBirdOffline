import Foundation
import SwiftData

@Model
final class Album {
    var title: String
    var artistName: String
    var artworkData: Data?
    @Relationship(inverse: \Song.album) var songs: [Song] = []
    init(title: String, artistName: String, artworkData: Data? = nil) {
        self.title = title; self.artistName = artistName; self.artworkData = artworkData
    }
}
