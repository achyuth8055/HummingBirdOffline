import SwiftUI
import Combine

// MARK: - Pro Status Manager
class ProStatusManager: ObservableObject {
    static let shared = ProStatusManager()
    
    @AppStorage("HBIsProUser") var isPro: Bool = false
    @Published var showSuccessMessage = false
    
    func simulatePurchase() {
        isPro = true
        showSuccessMessage = true
        // NOTE: Make sure 'Haptics' is defined in your project
        // Haptics.light()
    }
    
    func restorePurchase() {
        // In a real app, this would check with the App Store
        if isPro {
             // NOTE: Make sure 'Haptics' is defined in your project
            // Haptics.light()
        }
    }
}

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var proManager = ProStatusManager.shared
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if proManager.isPro {
                    proStatusBanner
                } else {
                    header
                    benefits
                    actionButtons
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
        .background(Color.primaryBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
                    .foregroundColor(.secondaryText)
            }
        }
        .alert("Purchase Status", isPresented: $showAlert) {
            Button("OK") {
                if proManager.isPro {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: proManager.showSuccessMessage) { _, newValue in
            if newValue {
                alertMessage = "🎉 Welcome to HummingBird Pro!\n\nAll premium features are now unlocked."
                showAlert = true
                proManager.showSuccessMessage = false
            }
        }
    }
    
    private var proStatusBanner: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentGreen, .accentBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("You're a Pro Member!")
                .font(.system(size: 28, weight: .bold)) // Placeholder for HBFont
                .foregroundColor(.primary)
            
            Text("Enjoy unlimited access to all premium features")
                .font(.system(size: 15)) // Placeholder for HBFont
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(benefitItems, id: \.self) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentGreen)
                        Text(item)
                            .font(.system(size: 14)) // Placeholder for HBFont
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unlock Premium Features")
                .font(.system(size: 28, weight: .bold)) // Placeholder for HBFont
                .foregroundColor(.primary)
            Text("Go premium for the full HummingBird experience.")
                .font(.system(size: 15)) // Placeholder for HBFont
                .foregroundColor(.secondary)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What you get")
                .font(.system(size: 20, weight: .bold)) // Placeholder for HBFont
                .foregroundColor(.primary)
            ForEach(benefitItems, id: \.self) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentGreen)
                    Text(item)
                        .font(.system(size: 14)) // Placeholder for HBFont
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button {
                proManager.simulatePurchase()
            } label: {
                HStack {
                    Text("Subscribe Now")
                    Image(systemName: "crown.fill")
                }
                .frame(maxWidth: .infinity)
            }
            // NOTE: Make sure .hbPrimary button style is defined
            .buttonStyle(.borderedProminent) // Placeholder

            Button {
                proManager.restorePurchase()
                if proManager.isPro {
                    alertMessage = "✅ Your Pro subscription has been restored!"
                } else {
                    alertMessage = "No previous purchase found. Please subscribe to unlock Pro features."
                }
                showAlert = true
            } label: {
                Text("Restore Purchase")
                    .frame(maxWidth: .infinity)
            }
            // NOTE: Make sure .hbSecondary button style is defined
             .buttonStyle(.bordered) // Placeholder
            
            Text("This is a simulated purchase flow for offline demo")
                .font(.system(size: 11)) // Placeholder for HBFont
                // ✅ FIX: Changed `.tertiary` to `.tertiaryText` to match your app's custom color name.
                .foregroundColor(.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }

    private var benefitItems: [String] {
        [
            "Download unlimited music and podcasts",
            "Exclusive high-fidelity audio",
            "Personalized mixes refreshed daily"
        ]
    }
}


#Preview {
    NavigationStack {
        PaywallView()
    }
    .preferredColorScheme(.dark)
    // NOTE: Make sure your PlayerViewModel has a shared instance for previews.
    // .environmentObject(PlayerViewModel.shared)
}
