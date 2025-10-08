//
//  WhatsNewView.swift
//  HummingBirdOffline
//
//  Modal view to showcase new features after app updates
//

import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lastSeenVersion") private var lastSeenVersion: String = ""
    
    struct FeatureItem: Identifiable {
        let id = UUID()
        let icon: String
        let iconColor: Color
        let title: String
        let description: String
    }
    
    private let features: [FeatureItem] = [
        FeatureItem(
            icon: "pencil.circle.fill",
            iconColor: .accentGreen,
            title: "Edit Album Cover, Title",
            description: "You can change picture, name of the track by swiping left on the song"
        ),
        FeatureItem(
            icon: "arrow.down.circle.fill",
            iconColor: .accentGreen,
            title: "Weekly Updates",
            description: "App gets weekly updates, turn on notifications to stay updated"
        ),
        FeatureItem(
            icon: "music.note.list",
            iconColor: .accentGreen,
            title: "Playlists",
            description: "Organize tracks in playlists, add Cover art"
        ),
        FeatureItem(
            icon: "music.note",
            iconColor: .accentGreen,
            title: "Support",
            description: "Supports many audio formats"
        )
    ]
    
    var body: some View {
        ZStack {
            Color.primaryBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("New Features")
                        .font(HBFont.heading(32))
                        .foregroundColor(.primaryText)
                        .padding(.top, 60)
                        .padding(.bottom, 20)
                }
                
                // Feature list
                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(features) { feature in
                            featureRow(feature)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
                
                Spacer()
            }
            
            // Continue button at bottom
            VStack {
                Spacer()
                Button(action: {
                    Haptics.medium()
                    // Save current version
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        lastSeenVersion = version
                    }
                    dismiss()
                }) {
                    Text("Continue")
                        .font(HBFont.body(17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.accentGreen)
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func featureRow(_ feature: FeatureItem) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(feature.iconColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(feature.iconColor)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(HBFont.body(17, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                Text(feature.description)
                    .font(HBFont.body(14))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WhatsNewView()
}
