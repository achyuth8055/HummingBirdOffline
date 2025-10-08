import SwiftUI
import UIKit
import Combine

struct ToastMessage: Identifiable, Equatable {
    enum Style {
        case success
        case info
        case error

        var tint: Color {
            switch self {
            case .success: return .accentGreen
            case .info: return .secondaryText
            case .error: return .red
            }
        }
    }

    let id = UUID()
    let text: String
    let style: Style
    let duration: TimeInterval

    init(text: String, style: Style = .info, duration: TimeInterval = 2.6) {
        self.text = text
        self.style = style
        self.duration = duration
    }

    static func success(_ text: String) -> ToastMessage { ToastMessage(text: text, style: .success) }
    static func info(_ text: String) -> ToastMessage { ToastMessage(text: text, style: .info) }
    static func error(_ text: String) -> ToastMessage { ToastMessage(text: text, style: .error) }
}

@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    @Published private(set) var current: ToastMessage?

    private var queue: [ToastMessage] = []
    private var displayTask: Task<Void, Never>?

    func show(_ message: ToastMessage) {
        queue.append(message)
        processQueue()
    }

    func success(_ text: String) { show(.success(text)) }
    func info(_ text: String) { show(.info(text)) }
    func error(_ text: String) { show(.error(text)) }

    private func processQueue() {
        guard displayTask == nil else { return }

        displayTask = Task { [weak self] in
            guard let self else { return }
            while !queue.isEmpty {
                let message = queue.removeFirst()
                await MainActor.run {
                    current = message
                    UIAccessibility.post(notification: .announcement, argument: message.text)
                    Haptics.light()
                }
                try? await Task.sleep(nanoseconds: UInt64(message.duration * 1_000_000_000))
                await MainActor.run { current = nil }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
            await MainActor.run { self.displayTask = nil }
        }
    }
}

struct ToastView: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundColor(message.style.tint)
                .font(.system(size: 14, weight: .semibold))
                .symbolEffect(.bounce, value: message.id)
            Text(message.text)
                .font(HBFont.body(13, weight: .medium))
                .foregroundColor(.primaryText)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 18)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.secondaryBackground.opacity(0.8))
                )
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.1), value: message.id)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message.text)
    }

    private var iconName: String {
        switch message.style {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}
