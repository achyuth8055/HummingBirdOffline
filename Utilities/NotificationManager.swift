//
//  NotificationManager.swift
//  HummingBirdOffline
//
//  Manages notification permissions and scheduling

import Foundation
import UserNotifications
import SwiftUI
import Combine

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled != oldValue {
                handleEnableToggle()
            }
        }
    }
    
    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Authorization
    
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isEnabled = (settings.authorizationStatus == .authorized)
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await checkAuthorizationStatus()
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func handleEnableToggle() {
        Task {
            if isEnabled && authorizationStatus == .notDetermined {
                let granted = await requestAuthorization()
                if !granted {
                    // Revert toggle if denied
                    isEnabled = false
                }
            }
        }
    }
    
    // MARK: - Scheduling (Future Use)
    
    func scheduleDownloadCompleteNotification(title: String) async {
        guard authorizationStatus == .authorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Download Complete"
        content.body = title
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        try? await UNUserNotificationCenter.current().add(request)
    }
    
    func schedulePlaybackReminder(songTitle: String, at date: Date) async {
        guard authorizationStatus == .authorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Continue Listening"
        content.body = "You were listening to \(songTitle)"
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        try? await UNUserNotificationCenter.current().add(request)
    }
}
