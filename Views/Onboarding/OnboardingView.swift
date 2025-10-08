import SwiftUI

struct OnboardingView: View {
    struct Page: Identifiable {
        let id: Int
        let systemImage: String
        let title: String
        let subtitle: String
    }

    let onFinish: () -> Void

    @State private var pageIndex: Int = 0
    private let pages: [Page] = [
        Page(id: 0, systemImage: "sparkles", title: "Welcome to HummingBirdOffline", subtitle: "Your music and podcast library, beautifully organized and always available offline."),
        Page(id: 1, systemImage: "tray.and.arrow.down.fill", title: "Import Your Music", subtitle: "Head to Settings → Import to bring in tracks from Files, AirDrop, or Apple Music downloads."),
        Page(id: 2, systemImage: "airpodspro", title: "Enjoy Anywhere", subtitle: "Create playlists, queue podcasts, and listen without a connection. Tap Next to choose your podcast interests.")
    ]

    // Persisted selected topics for personalization
    @AppStorage("HBSelectedTopics") private var selectedTopicsRaw: String = ""
    private var selectedTopics: [String] {
        selectedTopicsRaw.split(separator: "|").map(String.init)
    }

    private let allTopics = ["Tech", "Music", "Motivation", "Sports", "Comedy", "Business", "News", "Health", "Science"]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $pageIndex) {
                ForEach(pages) { page in
                    pageView(for: page)
                        .padding(.horizontal, 32)
                        .padding(.top, 44)
                        .padding(.bottom, 32)
                        .tag(page.id)
                }

                // Extra page for topic selection
                ChooseTopicsView(allTopics: allTopics, selectedTopics: selectedTopics) { newSelection in
                    selectedTopicsRaw = newSelection.joined(separator: "|")
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .tag(pages.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            controls
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
        }
        .background(Color.primaryBackground.ignoresSafeArea())
    }

    private func pageView(for page: Page) -> some View {
        GeometryReader { geo in
            VStack(spacing: 32) {
                Spacer()
                Image(systemName: page.systemImage)
                    .font(.system(size: min(120, geo.size.width * 0.3), weight: .semibold))
                    .foregroundStyle(Color.accentGreen)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.secondaryBackground.opacity(0.9))
                            .shadow(color: .black.opacity(0.22), radius: 18, y: 12)
                    )
                    .scaleEffect(pageIndex == page.id ? 1 : 0.9)
                    .animation(.hbSnappyMedium, value: pageIndex)

                VStack(spacing: 16) {
                    Text(page.title)
                        .font(HBFont.heading(28))
                        .foregroundColor(.primaryText)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .scale))

                    Text(page.subtitle)
                        .font(HBFont.body(16))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
                .animation(.hbSnappyMedium, value: pageIndex)

                Spacer()
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button("Skip") {
                Haptics.light()
                onFinish()
            }
            .font(HBFont.body(15, weight: .medium))
            .foregroundColor(.secondaryText)

            Spacer()

            Button(action: advance) {
                HStack(spacing: 12) {
                    Text(pageIndex < pages.count ? "Next" : "Get Started")
                        .font(HBFont.body(15, weight: .semibold))
                    Image(systemName: pageIndex < pages.count ? "arrow.right" : "checkmark")
                        .font(.body.weight(.semibold))
                }
                .foregroundColor(.primaryBackground)
                .padding(.horizontal, 26)
                .padding(.vertical, 14)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.accentGreen)
                )
            }
        }
    }

    private func advance() {
        // Advance through base pages, then topics page, then finish
        if pageIndex < pages.count {
            withAnimation(.hbSnappyMedium) { pageIndex += 1 }
            return
        }

        // We're on the topics page (index == pages.count)
        Haptics.medium()
        onFinish()
    }
}

// MARK: - ChooseTopicsView
private struct ChooseTopicsView: View {
    let allTopics: [String]
    @State var selectedTopics: [String]
    var onChange: ([String]) -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("Choose your interests")
                .font(HBFont.heading(22))
                .foregroundColor(.primaryText)

            Text("Pick 3–5 topics to personalize podcast recommendations")
                .font(HBFont.body(13))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)

            // Chips - use an adaptive grid to wrap chips reliably
            let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(allTopics, id: \.self) { topic in
                    Button(action: {
                        toggle(topic)
                    }) {
                        Text(topic)
                            .font(HBFont.body(13, weight: .medium))
                            .foregroundColor(selectedTopics.contains(topic) ? .black : .primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedTopics.contains(topic) ? Color.accentGreen : Color.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .onChange(of: selectedTopics) { new in onChange(new) }
    }

    private func toggle(_ topic: String) {
        if selectedTopics.contains(topic) {
            selectedTopics.removeAll { $0 == topic }
        } else if selectedTopics.count < 5 {
            selectedTopics.append(topic)
        } else {
            // if already 5, replace oldest
            selectedTopics.removeFirst()
            selectedTopics.append(topic)
        }
    }
}

// Flow wrapping is handled with LazyVGrid above.

#Preview {
    OnboardingView(onFinish: {})
}
