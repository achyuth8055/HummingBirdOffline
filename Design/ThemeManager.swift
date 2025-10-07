//
//  ThemeManager.swift
//  HummingBirdOffline
//

import SwiftUI
import Combine

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    @AppStorage("HBAccentHex") private var accentHex: String = "#1ED760"
    var accentColorSwiftUI: Color { Color(hex: accentHex) }
    
    func setAccent(hex: String) {
        accentHex = hex
        objectWillChange.send()
    }
}

let accentChoices: [String] = [
    "#1ED760", // green
    "#FF6B6B", // coral
    "#7C83FD", // indigo
    "#FFC75F", // amber
    "#00C2A8"  // teal
]

