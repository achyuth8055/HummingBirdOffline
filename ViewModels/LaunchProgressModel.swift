import Foundation
import Combine

@MainActor
final class LaunchProgressModel: ObservableObject {
    static let shared = LaunchProgressModel()

    @Published var progress: Double = 0
    @Published var done: Bool = false

    private var parts: [String: Double] = [:]

    private init() {}

    func set(_ key: String, value: Double) {
        parts[key] = max(0, min(1, value))
        let total = parts.values.reduce(0, +)
        progress = min(1, total / 4.0)
        if progress >= 1, !done {
            done = true
        }
    }

    func startTimeout(seconds: Double = 8) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if !done {
                progress = 1
                done = true
            }
        }
    }
}
