import SwiftUI

/// First-launch onboarding to select topics of interest
struct OnboardingTopicsView: View {
    @AppStorage("hasCompletedTopicsOnboarding") private var hasCompleted = false
    @AppStorage("selectedTopics") private var selectedTopicsRaw = ""
    @State private var selectedTopics: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    
    private let availableTopics = [
        Topic(id: "tech", name: "Technology", icon: "cpu", color: .accentBlue),
        Topic(id: "music", name: "Music", icon: "music.note", color: .accentPurple),
        Topic(id: "motivation", name: "Motivation", icon: "flame.fill", color: .accentOrange),
        Topic(id: "sports", name: "Sports", icon: "figure.run", color: .accentGreen),
        Topic(id: "business", name: "Business", icon: "briefcase.fill", color: .accentBlue),
        Topic(id: "comedy", name: "Comedy", icon: "face.smiling", color: .accentOrange),
        Topic(id: "news", name: "News", icon: "newspaper.fill", color: .secondaryText),
        Topic(id: "education", name: "Education", icon: "graduationcap.fill", color: .accentPurple),
        Topic(id: "health", name: "Health & Fitness", icon: "heart.fill", color: .accentGreen),
        Topic(id: "arts", name: "Arts & Culture", icon: "paintpalette.fill", color: .accentPurple)
    ]
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            Color.primaryBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        instructionText
                        topicsGrid
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }
                
                Spacer()
                
                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.accentGreen)
                .padding(.top, 60)
            
            Text("Personalize Your Experience")
                .font(HBFont.heading(28))
                .foregroundColor(.primaryText)
            
            Text("Select topics you're interested in")
                .font(HBFont.body(16))
                .foregroundColor(.secondaryText)
        }
        .padding(.bottom, 32)
    }
    
    // MARK: - Instruction Text
    
    private var instructionText: some View {
        Text("Choose at least 3 topics to get started")
            .font(HBFont.body(14, weight: .medium))
            .foregroundColor(.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Topics Grid
    
    private var topicsGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(availableTopics) { topic in
                TopicCard(
                    topic: topic,
                    isSelected: selectedTopics.contains(topic.id)
                ) {
                    toggleTopic(topic.id)
                }
            }
        }
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        Button {
            saveAndContinue()
        } label: {
            HStack {
                Text("Continue")
                    .font(HBFont.body(17, weight: .semibold))
                    .foregroundColor(canContinue ? .primaryBackground : .secondaryText)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(canContinue ? .primaryBackground : .secondaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(canContinue ? Color.accentGreen : Color.secondaryBackground)
            )
        }
        .disabled(!canContinue)
        .animation(.spring(response: 0.3), value: canContinue)
    }
    
    // MARK: - Helpers
    
    private var canContinue: Bool {
        selectedTopics.count >= 3
    }
    
    private func toggleTopic(_ id: String) {
        Haptics.light()
        if selectedTopics.contains(id) {
            selectedTopics.remove(id)
        } else {
            selectedTopics.insert(id)
        }
    }
    
    private func saveAndContinue() {
        Haptics.medium()
        
        // Save selected topics as comma-separated string
        selectedTopicsRaw = Array(selectedTopics).joined(separator: ",")
        hasCompleted = true
        
        dismiss()
    }
}

// MARK: - Topic Model

private struct Topic: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
}

// MARK: - Topic Card

private struct TopicCard: View {
    let topic: Topic
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? topic.color.opacity(0.2) : Color.secondaryBackground)
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: topic.icon)
                        .font(.system(size: 28))
                        .foregroundColor(isSelected ? topic.color : .secondaryText)
                }
                
                Text(topic.name)
                    .font(HBFont.body(14, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primaryText : .secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? topic.color.opacity(0.1) : Color.secondaryBackground.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                isSelected ? topic.color : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Preview

#Preview {
    OnboardingTopicsView()
        .preferredColorScheme(.dark)
}
