import SwiftUI

// Typography tokens
// Headings use a bold display style; body uses system text with dynamic type.
public enum HBTypography {
    // Display / Headings 20–26pt
    public static func heading(_ size: CGFloat) -> SwiftUI.Font {
        // SF Pro Display-like appearance using system weight
        SwiftUI.Font.system(size: size, weight: .bold, design: .default)
    }

    // Body/UI 11–15pt
    public static func body(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
        SwiftUI.Font.system(size: size, weight: weight, design: .default)
    }

    // Emphatic display when needed (e.g., app name)
    public static func display(_ size: CGFloat) -> SwiftUI.Font {
        SwiftUI.Font.system(size: size, weight: .heavy, design: .default)
    }
}

// MARK: - Easy Access Extension
public typealias HBFont = HBTypography
