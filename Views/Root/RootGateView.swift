//
//  RootGateView.swift
//  HummingBirdOffline
//
//  Created by Achyuth on 05/10/25.
//


import SwiftUI

/// Routes between Onboarding and the Auth/App flow, and shows the splash overlay on every cold launch.
struct RootGateView: View {
    @AppStorage("HBHasSeenOnboarding") private var hasSeenOnboarding = false
    @EnvironmentObject private var authVM: AuthViewModel

    var body: some View {
        Group {
            if !hasSeenOnboarding {
                OnboardingView {
                    hasSeenOnboarding = true
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                }
            } else {
                ContentView()             // shows MainTabView when signed in; LoginView otherwise
            }
        }
        .overlay(SplashOverlay().allowsHitTesting(true)) // remove this line if you don't use SplashOverlay
        .preferredColorScheme(.dark)
    }
}
