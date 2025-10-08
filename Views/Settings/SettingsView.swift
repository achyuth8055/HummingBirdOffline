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
    @State private var showAboutSheet = false
    @State private var showWebView = false
    @State private var webViewURL: URL?
    @State private var fontSize: Double = 14.0
    @AppStorage("HBFontSize") private var savedFontSize: Double = 14.0

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
                if ProStatusManager.shared.isPro {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundColor(.accentGreen)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("HummingBird Pro")
                                .font(HBFont.body(15, weight: .semibold))
                            Text("All premium features unlocked")
                                .font(HBFont.body(12))
                                .foregroundColor(.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else {
                    Button("Upgrade to HummingBird Pro") {
                        Haptics.light()
                        isShowingPaywall = true
                    }
                    Text("• Ad-free experience\n• Unlimited skips\n• High quality audio\n• Lyrics support")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }

            Section("Appearance") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Accent Color")
                        .font(HBFont.body(13, weight: .medium))
                        .foregroundColor(.secondaryText)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                        ForEach(accentChoices, id: \.self) { hex in
                            Button {
                                ThemeManager.shared.setAccent(hex: hex)
                                Haptics.light()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 44, height: 44)
                                    
                                    if ThemeManager.shared.accentColorSwiftUI == Color(hex: hex) {
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                            .frame(width: 50, height: 50)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Font Size")
                                .font(HBFont.body(13, weight: .medium))
                                .foregroundColor(.secondaryText)
                            Spacer()
                            Text("\(Int(fontSize))pt")
                                .font(HBFont.body(13, weight: .semibold))
                                .foregroundColor(.accentGreen)
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "textformat.size.smaller")
                                .foregroundColor(.secondaryText)
                            Slider(value: $fontSize, in: 12...18, step: 1)
                                .tint(.accentGreen)
                            Image(systemName: "textformat.size.larger")
                                .foregroundColor(.secondaryText)
                        }
                        
                        // Live preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview")
                                .font(.system(size: 11))
                                .foregroundColor(.tertiaryText)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Song Title Preview")
                                    .font(.system(size: fontSize, weight: .medium))
                                    .foregroundColor(.primaryText)
                                Text("Artist Name")
                                    .font(.system(size: fontSize - 2))
                                    .foregroundColor(.secondaryText)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.primaryBackground)
                            )
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 8)
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
            
            Section("Help & Feedback") {
                Button {
                    showAboutSheet = true
                } label: {
                    Label("About", systemImage: "info.circle")
                }
                
                Button {
                    openPrivacyPolicy()
                } label: {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                
                Button {
                    openTermsOfUse()
                } label: {
                    Label("Terms of Use", systemImage: "doc.text")
                }
                
                Button {
                    reportBug()
                } label: {
                    Label("Report a Bug", systemImage: "ant")
                }
                
                Button {
                    requestFeature()
                } label: {
                    Label("Request a Feature", systemImage: "lightbulb")
                }
                
                Button {
                    writeReview()
                } label: {
                    Label("Write a Review", systemImage: "star")
                }
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0").foregroundColor(.secondaryText)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.primaryBackground)
        .navigationTitle("Settings")
        .task {
            await notificationManager.checkAuthorizationStatus()
            fontSize = savedFontSize
        }
        .onChange(of: fontSize) { _, newValue in
            savedFontSize = newValue
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
        .sheet(isPresented: $showAboutSheet) {
            AboutSheet()
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
    
    // MARK: - Help & Feedback Methods
    
    private func openPrivacyPolicy() {
        Haptics.light()
        if let url = URL(string: "https://hummingbird.app/privacy") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openTermsOfUse() {
        Haptics.light()
        if let url = URL(string: "https://hummingbird.app/terms") {
            UIApplication.shared.open(url)
        }
    }
    
    private func reportBug() {
        Haptics.light()
        guard MFMailComposeViewController.canSendMail() else {
            showFeedbackFallback = true
            return
        }
        showMailComposer = true
    }
    
    private func requestFeature() {
        Haptics.light()
        guard MFMailComposeViewController.canSendMail() else {
            showFeedbackFallback = true
            return
        }
        showMailComposer = true
    }
    
    private func writeReview() {
        Haptics.light()
        // TODO: Replace with your actual App Store ID
        if let url = URL(string: "https://apps.apple.com/app/id0000000000?action=write-review") {
            UIApplication.shared.open(url)
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

// MARK: - About Sheet
struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // App Icon and Name
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.accentGreen.gradient)
                        
                        Text("HummingBird")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primaryText)
                        
                        Text("Version 1.0.0")
                            .font(.system(size: 14))
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.top, 32)
                    
                    // Description
                    VStack(spacing: 12) {
                        Text("Your Personal Music Companion")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primaryText)
                        
                        Text("HummingBird is a modern, offline-first music player designed for iOS. Enjoy your favorite music with a beautiful interface, powerful features, and complete privacy.")
                            .font(.system(size: 15))
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        FeatureRow(icon: "music.note", title: "Offline Playback", description: "Play your music anytime, anywhere")
                        FeatureRow(icon: "waveform", title: "Equalizer", description: "Customize your sound")
                        FeatureRow(icon: "moon.fill", title: "Sleep Timer", description: "Fall asleep to your music")
                        FeatureRow(icon: "mic.fill", title: "Podcast Support", description: "Listen to your favorite shows")
                        FeatureRow(icon: "heart.fill", title: "Favorites & Playlists", description: "Organize your music your way")
                    }
                    .padding(.horizontal, 24)
                    
                    // Developer Info
                    VStack(spacing: 8) {
                        Text("Developed with ❤️")
                            .font(.system(size: 14))
                            .foregroundColor(.secondaryText)
                        
                        Text("© 2025 HummingBird")
                            .font(.system(size: 13))
                            .foregroundColor(.tertiaryText)
                    }
                    .padding(.bottom, 32)
                }
            }
            .background(Color.primaryBackground.ignoresSafeArea())
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.accentGreen)
                }
            }
        }
    }
}

// MARK: - Feature Row
private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.accentGreen)
                .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
        }
    }
}
