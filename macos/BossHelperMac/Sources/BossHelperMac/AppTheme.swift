import SwiftUI

enum AppTheme {
    static let pinkLight = Color(
        red: 251.0 / 255.0,
        green: 114.0 / 255.0,
        blue: 153.0 / 255.0
    )

    static let pinkDark = Color(
        red: 255.0 / 255.0,
        green: 143.0 / 255.0,
        blue: 177.0 / 255.0
    )

    static func accentColor(appTheme: String, colorScheme: ColorScheme) -> Color {
        switch appTheme {
        case "light":
            return pinkLight
        case "dark":
            return pinkDark
        default:
            return colorScheme == .dark ? pinkDark : pinkLight
        }
    }
}
