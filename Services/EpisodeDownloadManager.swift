import Foundation
import Combine
import os

enum EpisodeDownloadState: Hashable {
    case notStarted
    case inProgress(progress: Double)
    case completed(url: URL)
    case failed(message: String)
}

final class EpisodeDownloadManager: NSObject, ObservableObject {
    static let shared = EpisodeDownloadManager()

    @Published private(set) var states: [String: EpisodeDownloadState] = [:]

    private lazy var downloadsDirectory: URL = {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("PodcastDownloads", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.hummingbird.podcastDownloads")
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private let logger = Logger(subsystem: "HummingBirdOffline", category: "EpisodeDownload")
    private var taskMap: [URLSessionTask: String] = [:]

    func startDownload(for episode: Episode) {
        let urlString = episode.audioURL
        guard let url = URL(string: urlString) else {
            logger.error("Invalid audio URL for episode \(episode.id, privacy: .public)")
            return
        }

        if case .inProgress = states[urlString] { return }
        if case .completed = states[urlString] { return }

        let task = session.downloadTask(with: url)
        taskMap[task] = urlString
        states[urlString] = .inProgress(progress: 0)
        task.resume()
        ToastCenter.shared.info("Downloading \(episode.title)")
    }

    func cancelDownload(for episode: Episode) {
        guard let entry = taskMap.first(where: { $0.value == episode.audioURL }) else { return }
        entry.key.cancel()
        taskMap.removeValue(forKey: entry.key)
        states[episode.audioURL] = .notStarted
    }

    func localFileURL(for episode: Episode) -> URL? {
        if case .completed(let url) = states[episode.audioURL] { return url }
        return episode.localFileURLValue
    }
}

extension EpisodeDownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let originalKey = taskMap[downloadTask],
              let originalURL = URL(string: originalKey) else { return }
        taskMap.removeValue(forKey: downloadTask)
        let destination = downloadsDirectory.appendingPathComponent(originalURL.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            DispatchQueue.main.async {
                ToastCenter.shared.success("Downloaded episode")
                self.states[originalKey] = .completed(url: destination)
            }
        } catch {
            DispatchQueue.main.async {
                self.states[originalKey] = .failed(message: error.localizedDescription)
                ToastCenter.shared.error("Download failed")
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let originalKey = taskMap[downloadTask], totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async { [weak self] in
            self?.states[originalKey] = .inProgress(progress: progress)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let originalKey = taskMap[task] else { return }
        taskMap.removeValue(forKey: task)
        if let error {
            DispatchQueue.main.async { [weak self] in
                self?.states[originalKey] = .failed(message: error.localizedDescription)
                ToastCenter.shared.error("Download error: \(error.localizedDescription)")
            }
        }
    }
}
