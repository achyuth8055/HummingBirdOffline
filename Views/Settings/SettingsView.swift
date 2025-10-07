import SwiftUI
import FirebaseAuth
import MediaPlayer
import SwiftData
import MessageUI

struct SettingsView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var player: PlayerViewModel
    @Environment(\.modelContext) private var context
    @StateObject private var sleepTimer = SleepTimer.shared
    @StateObject private var eqManager = EqualizerManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showSleepTimerSheet = false
    @State private var showEqualizerSheet = false
    @State private var isShowingPaywall = false
    @State private var showAppleMusicPicker = false
    @State private var showPermissionAlert = false
    @State private var isImporting = false
    @State private var importProgress: String = ""
    @State private var showingImporter = false
    @State private var showMailComposer = false
    @State private var showFeedbackFallback = false

    var body: some View {
        List {
            Section("Music Library") {
                Button {
                    handleAppleMusicImport()
                } label: {
                    HStack {
                        Label("Import from Apple Music", systemImage: "music.note.list")
                        Spacer()
                        if isImporting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(isImporting)
                
                if !importProgress.isEmpty {
                    Text(importProgress)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Button {
                    showingImporter = true
                } label: {
                    Label("Import Audio Files", systemImage: "folder")
                }
                .disabled(isImporting)
            }
            
            Section("Profile") {
                HStack {
                    Image(systemName: "person.circle.fill").font(.largeTitle).foregroundColor(.accentGreen)
                    VStack(alignment: .leading) {
                        Text(authVM.userSession?.displayName ?? authVM.userSession?.email ?? "Guest")
                        Text("Signed in").font(.caption).foregroundColor(.secondaryText)
                    }
                    Spacer()
                    Button { /* open profile later */ } label: {
                        Image(systemName: "bell.badge").font(.title3)
                    }
                }
                Button("Sign Out") { authVM.signOut() }.foregroundColor(.red)
            }

            Section("Notifications") {
                Toggle(isOn: $notificationManager.isEnabled) {
                    Label("Playback & Library Alerts", systemImage: "bell")
                }
                .disabled(notificationManager.authorizationStatus == .denied)
                
                if notificationManager.authorizationStatus == .denied {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.yellow)
                            Text("Notifications denied. Tap to open Settings.")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                }
            }

            Section("Audio Quality") {
                Button {
                    showEqualizerSheet = true
                } label: {
                    HStack {
                        Label("Equalizer", systemImage: "waveform")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
            }

            Section("Sleep Timer") {
                if sleepTimer.isActive {
                    HStack {
                        Label("Active", systemImage: "moon.fill")
                        Spacer()
                        Text("\(sleepTimer.remainingMinutes) min")
                            .foregroundColor(.accentGreen)
                        Button("Cancel") {
                            sleepTimer.stop()
                        }
                        .foregroundColor(.red)
                    }
                } else {
                    Button {
                        showSleepTimerSheet = true
                    } label: {
                        Label("Set Sleep Timer", systemImage: "moon")
                    }
                }
            }

            Section("Premium") {
                Button("Upgrade to HummingBird Pro") {
                    Haptics.light()
                    isShowingPaywall = true
                }
                Text("• Ad-free experience\n• Unlimited skips\n• High quality audio\n• Lyrics support")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }

            Section("Appearance") {
                ForEach(accentChoices, id: \.self) { hex in
                    HStack {
                        Circle().fill(Color(hex: hex)).frame(width: 22, height: 22)
                        Text(hex)
                        Spacer()
                        if ThemeManager.shared.accentColorSwiftUI == Color(hex: hex) {
                            Image(systemName: "checkmark")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { ThemeManager.shared.setAccent(hex: hex) }
                }
            }

            Section("Playback") {
                Toggle("Crossfade", isOn: $player.enableCrossfade)
                Stepper("Crossfade: \(Int(player.crossfadeSeconds))s",
                        value: $player.crossfadeSeconds, in: 0...12, step: 1)
                    .disabled(!player.enableCrossfade)
                
                Toggle("Gapless Playback", isOn: .constant(true))
                    .disabled(true)
                    .foregroundColor(.secondaryText)
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0").foregroundColor(.secondaryText)
                }
                Button("Rate HummingBird") {
                    // TODO: Open App Store rating
                }
                Button("Send Feedback") {
                    sendFeedback()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.primaryBackground)
        .navigationTitle("Settings")
        .task {
            await notificationManager.checkAuthorizationStatus()
        }
        .sheet(isPresented: $showSleepTimerSheet) {
            SleepTimerSheet()
        }
        .sheet(isPresented: $showEqualizerSheet) {
            EqualizerView()
        }
        .sheet(isPresented: $isShowingPaywall) {
            NavigationStack { PaywallView() }
        }
        .sheet(isPresented: $showAppleMusicPicker) {
            AppleMusicPicker(isPresented: $showAppleMusicPicker) { items in
                Task {
                    await importAppleMusicItems(items)
                }
            }
        }
        .alert("Permission Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("HummingBird needs access to your Media Library to import songs. Please enable access in Settings.")
        }
        .sheet(isPresented: $showingImporter) {
            ImportSongsPicker { urls in
                guard !urls.isEmpty else { return }
                Task {
                    await MainActor.run {
                        isImporting = true
                        importProgress = "Importing files..."
                    }
                    
                    let added = await ImportCoordinator.importSongs(from: urls, context: context)
                    
                    await MainActor.run {
                        isImporting = false
                        importProgress = ""
                        
                        if added > 0 {
                            Haptics.light()
                            ToastCenter.shared.success("Imported \(added) \(added == 1 ? "song" : "songs")")
                        } else {
                            ToastCenter.shared.info("These songs are already in your library")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showMailComposer) {
            MailComposerView(
                recipients: ["feedback@hummingbird.app"],
                subject: "HummingBird Feedback",
                body: """
                
                
                ---
                App Version: 1.0.0
                Device: \(UIDevice.current.model)
                iOS: \(UIDevice.current.systemVersion)
                """
            )
        }
        .alert("Send Feedback", isPresented: $showFeedbackFallback) {
            Button("Copy Email") {
                UIPasteboard.general.string = "feedback@hummingbird.app"
                ToastCenter.shared.success("Email copied to clipboard")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mail is not configured on this device. Please email us at feedback@hummingbird.app")
        }
    }
    
    // MARK: - Apple Music Import Methods
    
    private func handleAppleMusicImport() {
        Task {
            let status = AppleMusicImporter.authorizationStatus()
            
            switch status {
            case .authorized:
                showAppleMusicPicker = true
                
            case .notDetermined:
                let granted = await AppleMusicImporter.requestPermission()
                if granted {
                    await MainActor.run {
                        showAppleMusicPicker = true
                    }
                } else {
                    await MainActor.run {
                        showPermissionAlert = true
                    }
                }
                
            case .denied, .restricted:
                await MainActor.run {
                    showPermissionAlert = true
                }
                
            @unknown default:
                await MainActor.run {
                    showPermissionAlert = true
                }
            }
        }
    }
    
    // MARK: - Send Feedback
    
    private func sendFeedback() {
        guard MFMailComposeViewController.canSendMail() else {
            showFeedbackFallback = true
            return
        }
        showMailComposer = true
    }
    
    private func importAppleMusicItems(_ items: [MPMediaItem]) async {
        guard !items.isEmpty else { return }
        
        await MainActor.run {
            isImporting = true
            importProgress = "Importing \(items.count) song(s)..."
        }
        
        let result = await AppleMusicImporter.importMediaItems(items, context: context)
        
        await MainActor.run {
            isImporting = false
            importProgress = ""
            
            if result.imported > 0 {
                Haptics.light()
                ToastCenter.shared.success("Imported \(result.imported) song(s)")
            }
            
            if result.skipped > 0 {
                ToastCenter.shared.info("\(result.skipped) song(s) already in library")
            }
            
            if !result.errors.isEmpty {
                let errorCount = result.errors.count
                ToastCenter.shared.error("Failed to import \(errorCount) song(s)")
            }
        }
    }
}

// MARK: - Sleep Timer Sheet
struct SleepTimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var player: PlayerViewModel
    @StateObject private var sleepTimer = SleepTimer.shared
    
    let options = [5, 10, 15, 30, 45, 60]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(options, id: \.self) { minutes in
                    Button {
                        sleepTimer.start(minutes: minutes) {
                            Task { @MainActor in
                                player.pause()
                            }
                        }
                        Haptics.light()
                        dismiss()
                    } label: {
                        HStack {
                            Text("\(minutes) minutes")
                            Spacer()
                            Image(systemName: "moon.fill")
                                .foregroundColor(.accentGreen)
                        }
                    }
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Equalizer Sheet
struct EqualizerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var eqManager = EqualizerManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(EqualizerManager.Preset.allCases) { preset in
                    Button {
                        eqManager.currentPreset = preset
                        Haptics.light()
                        dismiss()
                    } label: {
                        HStack {
                            Text(preset.rawValue)
                            Spacer()
                            if eqManager.currentPreset == preset {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentGreen)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Equalizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
