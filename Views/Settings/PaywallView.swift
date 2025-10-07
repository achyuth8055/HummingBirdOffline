import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                benefits
                actionButtons
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unlock Premium Features")
                .font(HBFont.heading(28))
                .foregroundColor(.primaryText)
            Text("Go premium for the full HummingBird experience.")
                .font(HBFont.body(15))
                .foregroundColor(.secondaryText)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What you get")
                .font(HBFont.heading(20))
                .foregroundColor(.primaryText)
            ForEach(benefitItems, id: \.self) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentGreen)
                    Text(item)
                        .font(HBFont.body(14))
                        .foregroundColor(.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button(action: {}) {
                Text("Subscribe Now")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.hbPrimary)

            Button(action: {}) {
                Text("Restore Purchase")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.hbSecondary)
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
    .environmentObject(PlayerViewModel.shared)
}
