import AppKit
import SwiftUI
import XCTest
@testable import TalkingAlarm

final class InterfaceRenderTests: XCTestCase {
    func testRenderNativeScreens() async throws {
        guard let directory = ProcessInfo.processInfo.environment["TALKING_ALARM_RENDER_DIR"] else {
            throw XCTSkip("Set TALKING_ALARM_RENDER_DIR to render the native UI for visual review.")
        }
        try await MainActor.run {
            _ = NSApplication.shared
            let output = URL(fileURLWithPath: directory)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let store = AlarmStore(startsScheduling: false)
            // The fallback message is the owner's example; these render fixtures
            // never enter the user's saved alarms or start a scheduler.
            let alarm = store.alarms.first ?? Alarm(hour: 7, minute: 30, message: "Wake Up Alarm", days: Set(1...7))
            try Self.render(AlarmMenu(store: store), name: "alarms", output: output)
            if store.alarms.isEmpty {
                store.alarms = [alarm]
                try Self.render(AlarmMenu(store: store), name: "alarms-fixture", output: output)
            }
            try Self.render(AlarmEditor(store: store, alarm: alarm, close: {}), name: "edit-alarm", output: output)
            try Self.render(AlarmEditor(store: store, alarm: nil, close: {}), name: "add-alarm", output: output)
            try Self.render(AlarmAlert(alarm: alarm, dismiss: {}), name: "alarm-alert", output: output, size: NSSize(width: 440, height: 280))
            try Self.render(AlarmRow(alarm: alarm, editMode: false, revealDelete: false, edit: {}, toggle: {}, delete: {}).tint(AlarmTheme.accent), name: "row-closed", output: output, size: NSSize(width: 358, height: 140))
            try Self.render(AlarmRow(alarm: alarm, editMode: false, revealDelete: true, edit: {}, toggle: {}, delete: {}).tint(AlarmTheme.accent), name: "row-delete", output: output, size: NSSize(width: 358, height: 140))
        }
    }

    @MainActor private static func render<V: View>(_ view: V, name: String, output: URL, size: NSSize = NSSize(width: 390, height: 650)) throws {
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height).preferredColorScheme(.dark))
        let window = NSWindow(contentRect: NSRect(origin: CGPoint(x: -10000, y: -10000), size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw CocoaError(.fileWriteUnknown) }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: output.appendingPathComponent("\(name).png"))
        XCTAssertEqual(host.bounds.size, size)
    }
}
