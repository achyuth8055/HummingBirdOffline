//
//  SplashOverlay.swift
//  HummingBirdOffline
//
//  Created by Achyuth on 05/10/25.
//


import SwiftUI

struct SplashOverlay: View {
    @State private var visible = true
    var body: some View {
        ZStack {
            if visible {
                Color.primaryBackground.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "bird.fill").font(.system(size: 64)).foregroundColor(.accentGreen)
                    Text("HummingBirdOffline").font(.system(size: 20, weight: .semibold))
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeOut(duration: 0.35)) { visible = false }
        }
    }
}
