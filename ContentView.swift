import SwiftUI
import SwiftData
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var player: PlayerViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var phase
    @ObservedObject private var toastCenter = ToastCenter.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("lastSeenVersion") private var lastSeenVersion: String = ""
    @State private var showWhatsNew = false

    var body: some View {
        ZStack {
            if let session = authVM.userSession {
                MainTabView()
                    .task(id: session.uid) {
                        LaunchProgressModel.shared.set("firebase", value: 1.0)
                        LaunchProgressModel.shared.set("uiReady", value: 0.25)

                        await player.restoreState(context: modelContext)
                        LaunchProgressModel.shared.set("playerRestore", value: 1.0)

                        await LibraryImportService.scanLibraryFolder(context: modelContext) { fraction in
                            LaunchProgressModel.shared.set("libraryScan", value: max(0.25, min(1.0, fraction)))
                        }
                        LaunchProgressModel.shared.set("libraryScan", value: 1.0)
                        LaunchProgressModel.shared.set("uiReady", value: 1.0)
                    }
            } else {
                NavigationStack { LoginView() }
                    .onAppear {
                        PlayerViewModel.shared.clearQueueAndUI()
                        LaunchProgressModel.shared.set("firebase", value: 1.0)
                        LaunchProgressModel.shared.set("playerRestore", value: 1.0)
                        LaunchProgressModel.shared.set("libraryScan", value: 1.0)
                        LaunchProgressModel.shared.set("uiReady", value: 1.0)
                    }
            }

            if !LaunchProgressModel.shared.done {
                HBLaunchOverlay()
            }

            if let toast = toastCenter.current {
                ToastView(message: toast)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .background(Color.primaryBackground.ignoresSafeArea())
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: toastCenter.current)
        .onChange(of: authVM.userSession) { _, session in
            if session == nil {
                PlayerViewModel.shared.clearQueueAndUI()
            }
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                if authVM.userSession != nil {
                    player.saveState(context: modelContext)
                }
            }
        }
        .fullScreenCover(isPresented: Binding(get: { authVM.userSession != nil && !hasCompletedOnboarding }, set: { _ in })) {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView()
        }
        .onAppear {
            if UserDefaults.standard.bool(forKey: "HBHasSeenOnboarding") {
                hasCompletedOnboarding = true
            }
            
            // Check if app version has changed and show What's New
            checkForNewVersion()
        }
    }
    
    private func checkForNewVersion() {
        // Only check for version if user has completed onboarding and is signed in
        guard hasCompletedOnboarding, authVM.userSession != nil else { return }
        
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        
        // Show What's New if it's a different version and not empty
        if !lastSeenVersion.isEmpty && lastSeenVersion != currentVersion {
            // Wait a bit for the UI to settle before showing the sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showWhatsNew = true
            }
        } else if lastSeenVersion.isEmpty {
            // First time - just save the version without showing What's New
            lastSeenVersion = currentVersion
        }
    }

}
