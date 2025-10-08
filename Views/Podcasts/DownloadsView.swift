import SwiftUI

struct DownloadsView: View {
    @ObservedObject private var manager = EpisodeDownloadManager.shared

    var body: some View {
        List {
            ForEach(Array(manager.states.keys), id: \.self) { key in
                downloadRow(for: key)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Downloads")
    }

    @ViewBuilder
        private func downloadRow(for key: String) -> some View {
            let state = manager.states[key] ?? .notStarted
            let filename = URL(string: key)?.lastPathComponent ?? key
            HStack {
                Text(filename)
                    // FIX: Replaced custom HBTypography with standard system font
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer()
                switch state {
                case .completed:
                    // FIX: Replaced custom Color.accentGreen with standard .green
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                case .inProgress(let progress):
                    ProgressView(value: progress)
                        .frame(width: 120)
                case .failed:
                    Image(systemName: "exclamationmark.triangle").foregroundColor(.red)
                case .notStarted:
                    EmptyView()
                }
            }
        }
    }
