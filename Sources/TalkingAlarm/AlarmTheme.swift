import AppKit
import SwiftUI

// AppKit resolves these colors using the containing window's system appearance.
// The shared palette keeps the menu, editor, clock, and alert in sync.
enum AlarmTheme {
    static let background = adaptive(light: .init(white: 0.96, alpha: 1), dark: .init(white: 0.065, alpha: 1))
    static let surface = adaptive(light: .white, dark: .init(white: 0.115, alpha: 1))
    static let field = adaptive(light: .init(white: 0.90, alpha: 1), dark: .init(white: 0.17, alpha: 1))
    static let text = Color(nsColor: .labelColor)
    static let secondary = adaptive(light: .init(white: 0.36, alpha: 1), dark: .init(white: 0.68, alpha: 1))
    static let border = adaptive(light: .init(white: 0.76, alpha: 1), dark: .init(white: 0.27, alpha: 1))
    static let majorTick = adaptive(light: .init(white: 0.42, alpha: 1), dark: .init(white: 0.56, alpha: 1))
    static let minorTick = adaptive(light: .init(white: 0.72, alpha: 1), dark: .init(white: 0.31, alpha: 1))
    // Preserve the owner's original orange; only light/dark appearance follows macOS.
    static let accent = Color(red: 1, green: 0.70, blue: 0.35)
    static let accentLabel = Color(white: 0.065)
    static let accentText = adaptive(light: .init(srgbRed: 0.60, green: 0.29, blue: 0.04, alpha: 1), dark: .init(srgbRed: 1, green: 0.70, blue: 0.35, alpha: 1))
    static let destructive = adaptive(light: .init(srgbRed: 0.72, green: 0.12, blue: 0.16, alpha: 1), dark: .init(srgbRed: 1, green: 0.40, blue: 0.42, alpha: 1))
    static let radius: CGFloat = 16
    static let width: CGFloat = 390
    static let height: CGFloat = 700

    private static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        dynamic { isDark($0) ? dark : light }
    }

    private static func dynamic(_ resolve: @escaping (NSAppearance) -> NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            var color = NSColor.clear
            appearance.performAsCurrentDrawingAppearance { color = resolve(appearance) }
            return color
        })
    }

}
