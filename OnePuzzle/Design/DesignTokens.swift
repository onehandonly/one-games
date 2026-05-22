import SwiftUI

// MARK: - Design Tokens
// Brand: "Quiet Confidence" — warm paper, deep indigo, coral accent

extension Color {
    // Surface
    static let appSurface = Color(light: "#FAF7F2", dark: "#14141C")
    static let appSurfaceElevated = Color(light: "#FFFFFF", dark: "#1F2030")

    // Text
    static let appTextPrimary = Color(light: "#1A1B26", dark: "#F3F1EB")
    static let appTextSecondary = Color(light: "#5C6071", dark: "#A0A3B4")

    // Accent
    static let appPrimary = Color(light: "#3E4FE5", dark: "#7D8CFF")
    static let appSecondary = Color(light: "#FF6B5B", dark: "#FF8676")

    // UI
    static let appBorder = Color(light: "#E6E1D8", dark: "#2B2C3D")

    // Feedback
    static let appCorrect = Color(light: "#2BA84A", dark: "#5BD877")
    static let appMisplaced = Color(light: "#E0A000", dark: "#F0BC4A")
    static let appAbsent = Color(light: "#E6E1D8", dark: "#2B2C3D")
    static let appError = Color(light: "#D93B3B", dark: "#FF6B6B")
}

extension Color {
    init(light: String, dark: String) {
        self.init(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - Typography tokens
enum Typography {
    static let display = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let title = Font.system(.title, design: .rounded, weight: .bold)
    static let headline = Font.system(.title3, design: .rounded, weight: .bold)
    static let body = Font.system(.body, design: .default, weight: .regular)
    static let caption = Font.system(.caption, design: .default, weight: .regular)
    static let puzzleDigit = Font.system(.title2, design: .rounded, weight: .bold)
}

// MARK: - Spacing tokens
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Radius tokens
enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
}

// MARK: - Elevation tokens
enum Elevation {
    static let e1: CGFloat = 2
}

// MARK: - Motion tokens
enum Motion {
    static let standard: TimeInterval = 0.3
    static let celebrate: TimeInterval = 0.6
}

// MARK: - Layout tokens (legacy)
enum AppLayout {
    static let tapTarget: CGFloat = 44
    static let gridSpacing: CGFloat = 6
    static let cornerRadius: CGFloat = 10
    static let padding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 16
}

// MARK: - Typography tokens (legacy)
enum AppFont {
    static let headline = Typography.headline
    static let puzzleCell = Typography.puzzleDigit
    static let body = Typography.body
    static let caption = Typography.caption
    static let streakNumber = Font.system(.largeTitle, design: .rounded, weight: .bold)
}
