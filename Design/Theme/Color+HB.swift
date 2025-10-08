import SwiftUI

// Central color tokens for HummingBird’s dark theme
// Palette:
// - primaryBackground = #121212
// - secondaryBackground = #1E1E1E
// - railTint = #2A2A2A
// - primaryText = #FFFFFF
// - secondaryText = #B3B3B3
// - accentGreen = #1ED760

public enum HBColor {
    public static let primaryBackground = Color(hex: "#121212")
    public static let secondaryBackground = Color(hex: "#1E1E1E")
    public static let railTint = Color(hex: "#2A2A2A")

    public static let primaryText = Color.white
    public static let secondaryText = Color(hex: "#B3B3B3")

    public static let accentGreen = Color(hex: "#1ED760")
    public static let accentPurple = Color(hex: "#8B5CF6")
    public static let accentOrange = Color(hex: "#FB923C")
    public static let accentBlue = Color(hex: "#3B82F6")
    
    // Podcast-specific colors
    public static let podcastPrimary = Color(hex: "#9333EA")
    public static let podcastSecondary = Color(hex: "#7C3AED")
}

// MARK: - SwiftUI Color Extensions for Easy Access
extension Color {
    static var primaryBackground: Color { HBColor.primaryBackground }
    static var secondaryBackground: Color { HBColor.secondaryBackground }
    static var railTint: Color { HBColor.railTint }
    static var primaryText: Color { HBColor.primaryText }
    static var secondaryText: Color { HBColor.secondaryText }
    static var accentGreen: Color { HBColor.accentGreen }
    static var accentPurple: Color { HBColor.accentPurple }
    static var accentOrange: Color { HBColor.accentOrange }
    static var accentBlue: Color { HBColor.accentBlue }
    static var podcastPrimary: Color { HBColor.podcastPrimary }
    static var podcastSecondary: Color { HBColor.podcastSecondary }
}
