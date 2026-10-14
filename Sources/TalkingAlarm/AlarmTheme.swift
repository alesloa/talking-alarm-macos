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
    static let accent = Color.accentColor
    static let destructive = adaptive(light: .init(srgbRed: 0.72, green: 0.12, blue: 0.16, alpha: 1), dark: .init(srgbRed: 1, green: 0.40, blue: 0.42, alpha: 1))
    static let radius: CGFloat = 16
    static let width: CGFloat = 390
    static let height: CGFloat = 700

    // An accent chosen in System Settings can be very pale or very dark.
    // Use whichever label color has more contrast on filled controls.
    static let accentLabel = dynamic { _ in
        luminance(.controlAccentColor) > 0.179 ? .black : .white
    }

    // Plain action labels keep the system accent hue, with enough contrast
    // against all three unfilled surfaces in the current appearance.
    static let accentText = dynamic { appearance in
        let dark = isDark(appearance)
        let base = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? .systemBlue
        let surface = dark ? NSColor(white: 0.17, alpha: 1) : NSColor(white: 0.90, alpha: 1)
        let target: CGFloat = dark ? 1 : 0
        for step in 0...20 {
            let amount = CGFloat(step) / 20
            let color = NSColor(srgbRed: base.redComponent * (1 - amount) + target * amount,
                                green: base.greenComponent * (1 - amount) + target * amount,
                                blue: base.blueComponent * (1 - amount) + target * amount, alpha: 1)
            let values = [luminance(color), luminance(surface)].sorted()
            if (values[1] + 0.05) / (values[0] + 0.05) >= 4.5 { return color }
        }
        return dark ? .white : .black
    }

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

    private static func luminance(_ color: NSColor) -> Double {
        guard let rgb = color.usingColorSpace(.sRGB) else { return 0 }
        func linear(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
    }
}
