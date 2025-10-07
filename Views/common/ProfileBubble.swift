//
//  ProfileBubble.swift
//  HummingBirdOffline
//
//  Created by Achyuth on 05/10/25.
//


import SwiftUI

/// Small circular avatar next to the greeting.
/// If `photoURL` is nil, it shows the first letter of the email as initials.
struct ProfileBubble: View {
    let email: String?
    let photoURL: URL?

    private var initials: String {
        guard let e = email, let first = e.first else { return "U" }
        return String(first).uppercased()
    }

    var body: some View {
        Group {
            if let photoURL {
                // Async network image
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure(_), .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                // Initials fallback
                ZStack {
                    Circle().fill(Color.secondaryBackground)
                    Text(initials)
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(Color.accentGreen.opacity(0.6), lineWidth: 1)
        )
        .accessibilityLabel(email ?? "Profile")
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(Color.secondaryBackground)
            Image(systemName: "person.fill")
                .foregroundColor(.secondaryText)
        }
    }
}
