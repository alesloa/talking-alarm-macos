import AppKit
import SwiftUI
import XCTest
@testable import TalkingAlarm

final class AppearanceTests: XCTestCase {
    func testExistingPanelUpdatesWhenAppearanceChanges() async throws {
        try await MainActor.run {
            _ = NSApplication.shared
            let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alarms.json")
            let store = AlarmStore(file: file, startsScheduling: false)
            let host = NSHostingView(rootView: AlarmMenu(store: store))
            let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: AlarmTheme.width, height: AlarmTheme.height), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderFront(nil)
            defer { window.close() }

            // Switch the same live view and window, without forcing a SwiftUI theme.
            for name in [NSAppearance.Name.aqua, .darkAqua, .aqua] {
                window.appearance = NSAppearance(named: name)
                host.layoutSubtreeIfNeeded()
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let pixel = try XCTUnwrap(bitmap.colorAt(x: 4, y: 4)?.usingColorSpace(.sRGB))
                if name == .aqua { XCTAssertGreaterThan(pixel.redComponent, 0.9) }
                else { XCTAssertLessThan(pixel.redComponent, 0.2) }
            }
        }
    }

    func testLabelsKeepContrastInBothSystemAppearances() async {
        await MainActor.run {
            for name in [NSAppearance.Name.aqua, .darkAqua] {
                NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
                    for background in [AlarmTheme.background, AlarmTheme.surface, AlarmTheme.field] {
                        let base = NSColor(background)
                        for foreground in [AlarmTheme.text, AlarmTheme.secondary, AlarmTheme.accentText, AlarmTheme.destructive] {
                            XCTAssertGreaterThanOrEqual(Self.contrast(NSColor(foreground), on: base), 4.5, "\(name.rawValue) labels must stay readable")
                        }
                    }
                    XCTAssertGreaterThanOrEqual(Self.contrast(NSColor(AlarmTheme.accentLabel), on: NSColor(AlarmTheme.accent)), 4.5)
                }
            }
        }
    }

    func testOrangeAccentIsPreservedInBothAppearances() async {
        await MainActor.run {
            for name in [NSAppearance.Name.aqua, .darkAqua] {
                NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
                    let color = NSColor(AlarmTheme.accent).usingColorSpace(.sRGB)!
                    XCTAssertEqual(color.redComponent, 1, accuracy: 0.001)
                    XCTAssertEqual(color.greenComponent, 0.70, accuracy: 0.001)
                    XCTAssertEqual(color.blueComponent, 0.35, accuracy: 0.001)
                }
            }
        }
    }

    private static func contrast(_ foreground: NSColor, on background: NSColor) -> Double {
        let fg = foreground.usingColorSpace(.sRGB)!, bg = background.usingColorSpace(.sRGB)!
        func luminance(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> Double {
            func linear(_ channel: CGFloat) -> Double {
                let value = Double(channel)
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }
        let alpha = fg.alphaComponent
        let fgLuminance = luminance(fg.redComponent * alpha + bg.redComponent * (1 - alpha),
                                    fg.greenComponent * alpha + bg.greenComponent * (1 - alpha),
                                    fg.blueComponent * alpha + bg.blueComponent * (1 - alpha))
        let bgLuminance = luminance(bg.redComponent, bg.greenComponent, bg.blueComponent)
        return (max(fgLuminance, bgLuminance) + 0.05) / (min(fgLuminance, bgLuminance) + 0.05)
    }
}
