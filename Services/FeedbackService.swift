import Foundation
import UIKit
import Network
import Combine

@MainActor
final class FeedbackService: ObservableObject {
    static let shared = FeedbackService()

    struct FeedbackPayload: Codable, Hashable, Identifiable {
        let id: UUID
        let topic: String
        let message: String
        let email: String?
        let timestamp: Date
        let appVersion: String
        let osVersion: String
        let device: String
        let userID: String?
    }

    @Published private(set) var isSubmitting = false
    @Published private(set) var lastError: String?

    private var queue: [FeedbackPayload] = []
    private let monitor = NWPathMonitor()
    private var monitorQueue = DispatchQueue(label: "FeedbackMonitor")

    private init() {
        queue = FeedbackStorage.load()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            if path.status == .satisfied {
                Task { await self.flushQueue() }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    func submit(topic: String, message: String, email: String?, userID: String?) {
        let payload = FeedbackPayload(
            id: UUID(),
            topic: topic,
            message: message,
            email: email?.isEmpty == false ? email : nil,
            timestamp: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            device: UIDevice.current.model,
            userID: userID
        )
        queue.append(payload)
        FeedbackStorage.save(queue)
        Task { await flushQueue() }
    }

    func retryPending() {
        Task { await flushQueue() }
    }

    private func flushQueue() async {
        guard !queue.isEmpty, let endpoint = Secrets.feedbackEndpointURL else { return }
        guard monitor.currentPath.status == .satisfied else { return }

        isSubmitting = true
        lastError = nil
        defer { isSubmitting = false }

        var remaining: [FeedbackPayload] = []

        for payload in queue {
            do {
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let data = try JSONEncoder().encode(payload)
                let (_, response) = try await URLSession.shared.upload(for: request, from: data)
                guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                    throw URLError(.badServerResponse)
                }
                ToastCenter.shared.success("Feedback sent. Thanks!")
            } catch {
                remaining.append(payload)
                lastError = error.localizedDescription
                ToastCenter.shared.error("Feedback failed: \(error.localizedDescription)")
            }
        }
        queue = remaining
        FeedbackStorage.save(queue)
    }
}

private enum FeedbackStorage {
    private static var url: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("feedback_queue.json")
    }

    static func load() -> [FeedbackService.FeedbackPayload] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([FeedbackService.FeedbackPayload].self, from: data)) ?? []
    }

    static func save(_ payloads: [FeedbackService.FeedbackPayload]) {
        let data = try? JSONEncoder().encode(payloads)
        try? data?.write(to: url, options: .atomic)
    }
}
