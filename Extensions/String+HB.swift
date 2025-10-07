import Foundation

extension String {
    var hbPrimaryArtist: String {
        let first = self.split(separator: ",").first ?? Substring(self)
        return first.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
