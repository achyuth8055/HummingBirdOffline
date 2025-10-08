//
//  RootGateView.swift
//  HummingBirdOffline
//
//  Created by Achyuth on 05/10/25.
//


import SwiftUI

struct RootGateView: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var performedLegacyMigration = false
    @EnvironmentObject private var authVM: AuthViewModel

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                ModernOnboardingView {
                    markOnboardingComplete()
                }
            } else {
                ContentView()             // shows MainTabView when signed in; LoginView otherwise
            }
        }
        // Splash overlay removed to prevent re-show after onboarding completion.
        .preferredColorScheme(.dark)
        .task { migrateLegacyIfNeeded() }
    }

    private func migrateLegacyIfNeeded() {
        guard !performedLegacyMigration else { return }
        performedLegacyMigration = true
        // Legacy keys used: HBHasSeenOnboarding / hasCompletedOnboarding / HBHasSeenOnboarding
        if !hasCompletedOnboarding {
            let legacy1 = UserDefaults.standard.bool(forKey: "HBHasSeenOnboarding")
            let legacy2 = UserDefaults.standard.bool(forKey: "HBHasSeenOnboarding")
            if legacy1 || legacy2 { hasCompletedOnboarding = true }
        }
    }

    private func markOnboardingComplete() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "HBHasSeenOnboarding") // write legacy for safety
    }
}
