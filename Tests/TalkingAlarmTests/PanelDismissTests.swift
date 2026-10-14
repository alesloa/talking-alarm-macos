import AppKit
import XCTest
@testable import TalkingAlarm

final class PanelDismissTests: XCTestCase {
    @MainActor func testHidingAndReopeningRetainedPanelResetsEachPresentationOnce() async throws {
        _ = NSApplication.shared
        let observer = PanelDismissView()
        var dismissals = 0
        observer.onDismiss = { dismissals += 1 }
        let window = Self.window(content: observer)
        defer { window.close() }

        window.makeKeyAndOrderFront(nil)
        try await Self.flushEvents()
        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(dismissals, 0)
        window.orderOut(nil)
        try await Self.flushEvents()
        XCTAssertFalse(window.isVisible)
        XCTAssertEqual(dismissals, 1)
        window.orderOut(nil)
        try await Self.flushEvents()
        XCTAssertEqual(dismissals, 1)
        window.makeKeyAndOrderFront(nil)
        try await Self.flushEvents()
        XCTAssertEqual(dismissals, 1)
        window.orderOut(nil)
        try await Self.flushEvents()
        XCTAssertEqual(dismissals, 2)
    }

    @MainActor func testOpeningPopupKeepsVisiblePanelDraft() async throws {
        _ = NSApplication.shared
        let observer = PanelDismissView()
        var dismissals = 0
        observer.onDismiss = { dismissals += 1 }
        let window = Self.window(content: observer)
        let popup = Self.window(content: NSView())
        defer { popup.close(); window.close() }
        window.makeKeyAndOrderFront(nil)
        try await Self.flushEvents()
        popup.makeKeyAndOrderFront(nil)
        try await Self.flushEvents()
        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(dismissals, 0)
        popup.close()
        window.makeKeyAndOrderFront(nil)
        try await Self.flushEvents()
        XCTAssertEqual(dismissals, 0)
    }

    @MainActor func testClosingPanelResetsOnlyOnce() async throws {
        _ = NSApplication.shared
        let observer = PanelDismissView()
        var dismissals = 0
        observer.onDismiss = { dismissals += 1 }
        let window = Self.window(content: observer)
        window.makeKeyAndOrderFront(nil)
        try await Self.flushEvents()
        window.close()
        try await Self.flushEvents()
        XCTAssertEqual(dismissals, 1)
    }

    @MainActor private static func window(content: NSView) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 390, height: 700), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = content
        return window
    }

    @MainActor private static func flushEvents() async throws {
        // Suspend so queued AppKit/SwiftUI callbacks can run on the main queue.
        try await Task.sleep(nanoseconds: 150_000_000)
    }
}
