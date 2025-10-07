//
//  SleepTimer.swift
//  HummingBirdOffline
//

import Foundation
import Combine

@MainActor
final class SleepTimer: ObservableObject {
    static let shared = SleepTimer()
    
    @Published var isActive: Bool = false
    @Published var remainingMinutes: Int = 0
    
    private var timer: Timer?
    private var endDate: Date?
    private var onComplete: (() -> Void)?
    
    private init() {}
    
    func start(minutes: Int, onComplete: @escaping () -> Void) {
        stop() // Cancel any existing timer
        
        self.onComplete = onComplete
        self.remainingMinutes = minutes
        self.endDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        self.isActive = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        isActive = false
        remainingMinutes = 0
    }
    
    private func tick() {
        guard let end = endDate else { return }
        
        let remaining = end.timeIntervalSinceNow
        if remaining <= 0 {
            // Timer finished
            stop()
            onComplete?()
        } else {
            remainingMinutes = Int(ceil(remaining / 60.0))
        }
    }
}
