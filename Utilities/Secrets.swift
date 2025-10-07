import Foundation

enum Secrets {
    private static let dictionary: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any]
        else { return [:] }
        return dict
    }()

    static func string(forKey key: String) -> String {
        dictionary[key] as? String ?? ""
    }

    static var podcastAPIKey: String { string(forKey: "PODCAST_API_KEY") }
    static var feedbackEndpointURL: URL? {
        let value = string(forKey: "FEEDBACK_ENDPOINT_URL")
        guard !value.isEmpty else { return nil }
        return URL(string: value)
    }
}
