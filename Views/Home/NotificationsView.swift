import SwiftUI

struct NotificationItem: Codable, Identifiable {
    let id: String
    let title: String
    let message: String
    let timestamp: String
    let type: String
    var isRead: Bool
    
    var date: Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: timestamp) ?? Date()
    }
    
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var icon: String {
        switch type {
        case "feature": return "star.fill"
        case "library": return "music.note.list"
        case "podcast": return "waveform"
        default: return "bell.fill"
        }
    }
    
    var iconColor: Color {
        switch type {
        case "feature": return .accentOrange
        case "library": return .accentGreen
        case "podcast": return .podcastPrimary
        default: return .accentBlue
        }
    }
}

struct NotificationsView: View {
    @State private var notifications: [NotificationItem] = []
    @State private var showError = false
    
    var body: some View {
        Group {
            if notifications.isEmpty {
                emptyState
            } else {
                notificationsList
            }
        }
        .background(Color.primaryBackground.ignoresSafeArea())
        .navigationTitle("Notifications")
        .onAppear {
            loadNotifications()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondaryText.opacity(0.6))
            Text("You're all caught up")
                .font(HBFont.heading(20))
            Text("We'll let you know when something new arrives.")
                .font(HBFont.body(13))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var notificationsList: some View {
        List {
            if hasUnreadNotifications {
                Section(header: Text("New").font(HBFont.body(13, weight: .semibold))) {
                    ForEach($notifications.filter { !$0.wrappedValue.isRead }) { $notification in
                        NotificationRow(notification: $notification)
                            .listRowBackground(Color.secondaryBackground)
                    }
                }
            }
            
            if hasReadNotifications {
                Section(header: Text("Earlier").font(HBFont.body(13, weight: .semibold))) {
                    ForEach($notifications.filter { $0.wrappedValue.isRead }) { $notification in
                        NotificationRow(notification: $notification)
                            .listRowBackground(Color.secondaryBackground.opacity(0.5))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .toolbar {
            if hasUnreadNotifications {
                ToolbarItem(placement: .primaryAction) {
                    Button("Mark All Read") {
                        markAllAsRead()
                    }
                    .font(HBFont.body(14, weight: .medium))
                }
            }
        }
    }
    
    private var hasUnreadNotifications: Bool {
        notifications.contains { !$0.isRead }
    }
    
    private var hasReadNotifications: Bool {
        notifications.contains { $0.isRead }
    }
    
    private func loadNotifications() {
        guard let url = Bundle.main.url(forResource: "notifications", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([NotificationItem].self, from: data) else {
            showError = true
            return
        }
        notifications = decoded.sorted { $0.date > $1.date }
    }
    
    private func markAllAsRead() {
        withAnimation {
            for index in notifications.indices {
                notifications[index].isRead = true
            }
        }
        Haptics.light()
    }
}

private struct NotificationRow: View {
    @Binding var notification: NotificationItem
    
    var body: some View {
        Button {
            withAnimation {
                notification.isRead = true
            }
            Haptics.light()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(notification.iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: notification.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(notification.iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(HBFont.body(15, weight: notification.isRead ? .regular : .semibold))
                            .foregroundColor(.primaryText)
                        Spacer()
                        if !notification.isRead {
                            Circle()
                                .fill(Color.accentGreen)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text(notification.message)
                        .font(HBFont.body(13))
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                    
                    Text(notification.relativeTime)
                        .font(HBFont.body(11))
                        .foregroundColor(.tertiaryText)
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
