import SwiftUI

struct NotificationsView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("You're all caught up")
                        .font(HBFont.heading(18))
                    Text("We'll let you know when something new arrives.")
                        .font(HBFont.body(13))
                        .foregroundColor(.secondaryText)
                }
                .padding(.vertical, 12)
            }
            .listRowBackground(Color.secondaryBackground)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.primaryBackground.ignoresSafeArea())
        .navigationTitle("Notifications")
    }
}
