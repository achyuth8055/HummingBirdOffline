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
        .onAppear {
            if UserDefaults.standard.bool(forKey: "HBHasSeenOnboarding") {
                hasCompletedOnboarding = true
            }
        }
    }

}
