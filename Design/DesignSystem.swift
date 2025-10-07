//
//  DesignSystem.swift
//

import SwiftUI

// MARK: - Typography

enum HBFont {
    // Align with typography tokens: headings use bold display style, body uses SF Pro Text.
    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }
}

// MARK: - Colors

extension Color {
    // Backgrounds (premium dark palette)
    static let primaryBackground = Color(hex: "#121212")
    static let secondaryBackground = Color(hex: "#1E1E1E")
    static let tertiaryBackground = Color(hex: "#2A2A2A") // rail tint

    // Accents
    static let accentGreen = Color(hex: "#1ED760")
    static let accentBlue = Color(hex: "#1E90FF")
    static let accentPurple = Color(hex: "#9D4EDD")
    static let accentOrange = Color(hex: "#FF6B35")

    // Text
    static let primaryText = Color.white
    static let secondaryText = Color(hex: "#B3B3B3")
    static let tertiaryText = Color(hex: "#737373")

    // Status
    static let successGreen = Color(hex: "#4CAF50")
    static let errorRed = Color(hex: "#EF5350")
    static let warningYellow = Color(hex: "#FFC107")

    // Podcast UI
    static let podcastPrimary = Color(hex: "#8E44AD")
    static let podcastSecondary = Color(hex: "#6C3483")
}

extension Color {
    init(hex: String, alpha: Double = 1.0) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        self.init(.sRGB,
                  red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                  green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                  blue: Double(rgb & 0x0000FF) / 255.0,
                  opacity: alpha)
    }
}

// MARK: - View Modifiers

struct HBCard: ViewModifier {
    var cornerRadius: CGFloat = 16
    var shadow: Bool = true
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.secondaryBackground)
                    .shadow(
                        color: shadow ? Color.black.opacity(0.2) : Color.clear,
                        radius: shadow ? 10 : 0,
                        y: shadow ? 6 : 0
                    )
            )
    }
}

extension View {
    func hbCard(cornerRadius: CGFloat = 16, shadow: Bool = true) -> some View {
        modifier(HBCard(cornerRadius: cornerRadius, shadow: shadow))
    }
}

struct Frosted: ViewModifier {
    var cornerRadius: CGFloat = 20
    var material: Material = .ultraThinMaterial
    
    func body(content: Content) -> some View {
        content
            .background(
                material,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}

extension View {
    func frosted(cornerRadius: CGFloat = 20, material: Material = .ultraThinMaterial) -> some View {
        modifier(Frosted(cornerRadius: cornerRadius, material: material))
    }
}

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Gradient Backgrounds

extension LinearGradient {
    static func artworkGradient(from colors: [Color]) -> LinearGradient {
        LinearGradient(
            colors: colors.isEmpty ? [.primaryBackground, .secondaryBackground] : colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static let defaultPlayerBackground = LinearGradient(
        colors: [
            Color.secondaryBackground.opacity(0.9),
            Color.primaryBackground
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Animations

extension Animation {
    static let bouncy = Animation.spring(response: 0.35, dampingFraction: 0.7, blendDuration: 0)
    static let smooth = Animation.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)
    static let snappyBounce = Animation.spring(response: 0.28, dampingFraction: 0.75, blendDuration: 0)
}

// MARK: - Spacing

enum HBSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

enum HBCornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

// MARK: - Shadow Styles

extension View {
    func hbShadow(style: HBShadowStyle = .medium) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
}

enum HBShadowStyle {
    case small
    case medium
    case large
    
    var color: Color {
        Color.black.opacity(0.2)
    }
    
    var radius: CGFloat {
        switch self {
        case .small: return 5
        case .medium: return 10
        case .large: return 20
        }
    }
    
    var x: CGFloat { 0 }
    
    var y: CGFloat {
        switch self {
        case .small: return 2
        case .medium: return 6
        case .large: return 12
        }
    }
}

// MARK: - Button Styles

struct HBButtonStyle: ButtonStyle {
    var color: Color = .accentGreen
    var isProminent: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HBFont.body(15, weight: .semibold))
            .foregroundColor(isProminent ? .white : color)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(isProminent ? color : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .stroke(color, lineWidth: isProminent ? 0 : 2)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.bouncy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == HBButtonStyle {
    static var hbPrimary: HBButtonStyle {
        HBButtonStyle(color: .accentGreen, isProminent: true)
    }
    
    static var hbSecondary: HBButtonStyle {
        HBButtonStyle(color: .accentGreen, isProminent: false)
    }
}

// MARK: - Loading Indicator

struct HBLoadingView: View {
    var message: String = "Loading..."
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)
            
            Text(message)
                .font(HBFont.body(14))
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primaryBackground)
    }
}
