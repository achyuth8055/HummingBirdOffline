//
//  ModernOnboardingView.swift
//  HummingBirdOffline
//
//  Modern first-install onboarding flow with slider
//

import SwiftUI

struct ModernOnboardingView: View {
    let onFinish: () -> Void
    
    @State private var currentPage = 0
    
    struct OnboardingPage: Identifiable {
        let id = UUID()
        let illustration: OnboardingIllustration
        let title: String
        let description: String
    }
    
    enum OnboardingIllustration {
        case cloudImport
        case offlinePlayback
        case playlists
        case modernUI
    }
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            illustration: .cloudImport,
            title: "Cloud Import",
            description: "Upload your favorite music into Cloud Services & Download from Offline Music Player."
        ),
        OnboardingPage(
            illustration: .offlinePlayback,
            title: "Offline Playback",
            description: "Listen to your music anytime, anywhere without internet connection."
        ),
        OnboardingPage(
            illustration: .playlists,
            title: "Custom Playlists",
            description: "Create and organize your perfect playlists with custom cover art."
        ),
        OnboardingPage(
            illustration: .modernUI,
            title: "Modern UI Experience",
            description: "Enjoy a beautiful, intuitive interface designed for music lovers."
        )
    ]
    
    var body: some View {
        ZStack {
            Color.primaryBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        pageView(for: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .animation(.easeInOut, value: currentPage)
                
                // Bottom controls
                bottomControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .padding(.top, 20)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func pageView(for page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Illustration
            illustrationView(for: page.illustration)
                .frame(height: 300)
                .padding(.horizontal, 40)
            
            // Text content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(HBFont.heading(28))
                    .foregroundColor(.primaryText)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(HBFont.body(16))
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            Spacer()
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    @ViewBuilder
    private func illustrationView(for illustration: OnboardingIllustration) -> some View {
        switch illustration {
        case .cloudImport:
            cloudImportIllustration
        case .offlinePlayback:
            offlinePlaybackIllustration
        case .playlists:
            playlistsIllustration
        case .modernUI:
            modernUIIllustration
        }
    }
    
    // Cloud Import Illustration
    private var cloudImportIllustration: some View {
        ZStack {
            // Background gradient circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentGreen.opacity(0.2), Color.accentGreen.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 280, height: 280)
            
            VStack(spacing: 20) {
                // Cloud services icons arranged in a grid
                HStack(spacing: 30) {
                    cloudServiceIcon("Google Drive", systemImage: "g.circle.fill", color: .blue)
                    cloudServiceIcon("OneDrive", systemImage: "cloud.fill", color: .accentBlue)
                }
                
                // Central phone with download arrow
                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color.secondaryBackground)
                        .frame(width: 140, height: 180)
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                    
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.accentGreen)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.primaryText)
                    }
                }
                
                HStack(spacing: 30) {
                    cloudServiceIcon("Files", systemImage: "folder.fill", color: .accentBlue)
                    cloudServiceIcon("Apple Music", systemImage: "music.note", color: .red)
                }
            }
        }
    }
    
    private func cloudServiceIcon(_ label: String, systemImage: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(color)
            }
        }
    }
    
    // Offline Playback Illustration
    private var offlinePlaybackIllustration: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentPurple.opacity(0.2), Color.accentPurple.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 280, height: 280)
            
            VStack(spacing: 24) {
                // Headphones icon
                ZStack {
                    Circle()
                        .fill(Color.accentGreen.opacity(0.15))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "headphones")
                        .font(.system(size: 60, weight: .medium))
                        .foregroundColor(.accentGreen)
                }
                
                // Offline badge
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Offline Mode")
                        .font(HBFont.body(16, weight: .semibold))
                }
                .foregroundColor(.primaryText)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.secondaryBackground)
                )
            }
        }
    }
    
    // Playlists Illustration
    private var playlistsIllustration: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentOrange.opacity(0.2), Color.accentOrange.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 280, height: 280)
            
            VStack(spacing: 20) {
                // Stack of playlist cards
                ZStack {
                    playlistCard(offset: 20, rotation: -8, color: .accentPurple)
                    playlistCard(offset: 10, rotation: -4, color: .accentBlue)
                    playlistCard(offset: 0, rotation: 0, color: .accentGreen)
                }
                
                // Add playlist button
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Create Playlist")
                        .font(HBFont.body(16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.accentGreen)
                )
            }
        }
    }
    
    private func playlistCard(offset: CGFloat, rotation: Double, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(color.opacity(0.3))
            .frame(width: 140, height: 140)
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                    .padding(12)
                }
            )
            .offset(y: offset)
            .rotationEffect(.degrees(rotation))
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }
    
    // Modern UI Illustration
    private var modernUIIllustration: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentBlue.opacity(0.2), Color.accentBlue.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 280, height: 280)
            
            VStack(spacing: 24) {
                // App icon style display
                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentGreen, Color.accentGreen.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.accentGreen.opacity(0.4), radius: 20, y: 10)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // Features badges
                HStack(spacing: 12) {
                    featureBadge(icon: "waveform", color: .accentGreen)
                    featureBadge(icon: "slider.horizontal.3", color: .accentPurple)
                    featureBadge(icon: "paintbrush.fill", color: .accentOrange)
                }
            }
        }
    }
    
    private func featureBadge(icon: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 50, height: 50)
            
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)
        }
    }
    
    // Bottom controls
    private var bottomControls: some View {
        HStack(spacing: 16) {
            // Skip button
            if currentPage < pages.count - 1 {
                Button("Skip") {
                    Haptics.light()
                    onFinish()
                }
                .font(HBFont.body(15, weight: .medium))
                .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            // Next/Get Started button
            Button(action: {
                if currentPage < pages.count - 1 {
                    Haptics.light()
                    withAnimation(.hbSnappyMedium) {
                        currentPage += 1
                    }
                } else {
                    Haptics.medium()
                    onFinish()
                }
            }) {
                HStack(spacing: 10) {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(HBFont.body(16, weight: .semibold))
                    
                    Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.accentGreen)
                )
            }
        }
    }
}

#Preview {
    ModernOnboardingView(onFinish: {})
}
