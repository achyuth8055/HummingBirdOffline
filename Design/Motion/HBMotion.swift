import SwiftUI

// Motion tokens for consistent, snappy interactions
public extension Animation {
    static var hbSnappyShort: Animation { .snappy(duration: 0.24, extraBounce: 0.05) }
    static var hbSnappyMedium: Animation { .snappy(duration: 0.32, extraBounce: 0.06) }
    static var hbSpringLarge: Animation { .spring(response: 0.45, dampingFraction: 0.86) }
}

