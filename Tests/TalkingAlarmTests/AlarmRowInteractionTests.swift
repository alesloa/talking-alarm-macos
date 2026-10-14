import AppKit
import SwiftUI
import XCTest
@testable import TalkingAlarm

@MainActor private final class RowFixture: ObservableObject {
    @Published var opened = false
    @Published var enabled = true
    @Published var editMode = false
    var edits = 0
    var deletes = 0
    var alarm: Alarm { Alarm(hour: 7, minute: 30, message: "Wake Up Alarm", enabled: enabled) }
}

private struct RowHarness: View {
    @ObservedObject var fixture: RowFixture
    var body: some View {
        AlarmRow(alarm: fixture.alarm, editMode: fixture.editMode, revealDelete: fixture.opened,
            edit: { fixture.edits += 1 }, toggle: { fixture.enabled.toggle() },
            delete: { fixture.deletes += 1 }, setRevealed: { fixture.opened = $0 })
            .frame(width: 358).tint(AlarmTheme.accent).preferredColorScheme(.dark)
    }
}

final class AlarmRowInteractionTests: XCTestCase {
    func testWholeCardSlidesWithSwitchAndSeparateDeleteAction() async throws {
        try await MainActor.run {
            let (fixture, host, window, input) = try Self.makeWindow()
            defer { window.close() }
            let switchFrame = try Self.switchFrame(in: host)

            Self.send(.leftMouseDown, x: 160, window: window)
            Self.send(.leftMouseDragged, x: 140, window: window)
            XCTAssertEqual(input.offset, -20, accuracy: 0.1, "The whole card must track the pointer before release.")
            Self.send(.leftMouseDragged, x: 110, window: window)
            XCTAssertEqual(input.offset, -50, accuracy: 0.1)
            Self.send(.leftMouseUp, x: 110, window: window)
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
            XCTAssertTrue(fixture.opened)
            XCTAssertEqual(input.offset, -RowSwipe.revealWidth, accuracy: 0.1)
            XCTAssertEqual(fixture.edits, 0, "Dragging must not open the editor.")
            XCTAssertEqual(fixture.deletes, 0, "Dragging alone must never delete an alarm.")
            let movedSwitchFrame = try Self.switchFrame(in: host)
            XCTAssertEqual(movedSwitchFrame.minX, switchFrame.minX - RowSwipe.revealWidth, accuracy: 0.1)
            XCTAssertEqual(movedSwitchFrame.size, switchFrame.size)
            XCTAssertGreaterThan(movedSwitchFrame.minX, 0)

            // The toggle travels with the card and still works while open.
            Self.send(.leftMouseDown, x: movedSwitchFrame.midX, window: window)
            Self.send(.leftMouseUp, x: movedSwitchFrame.midX, window: window)
            XCTAssertFalse(fixture.enabled)
            XCTAssertTrue(fixture.opened)

            Self.send(.leftMouseDown, x: 110, window: window)
            Self.send(.leftMouseDragged, x: 200, window: window)
            Self.send(.leftMouseUp, x: 200, window: window)
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
            XCTAssertFalse(fixture.opened)
            XCTAssertEqual(input.offset, 0, accuracy: 0.1)
            XCTAssertEqual(try Self.switchFrame(in: host), switchFrame)

            // Open again, then click the exposed trash button.
            Self.send(.leftMouseDown, x: 160, window: window)
            Self.send(.leftMouseDragged, x: 70, window: window)
            Self.send(.leftMouseUp, x: 70, window: window)
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
            let frame = input.convert(input.bounds, to: host)
            XCTAssertGreaterThan(frame.maxX - RowSwipe.actionWidth, (try Self.switchFrame(in: host)).maxX)
            Self.send(.leftMouseDown, x: frame.maxX - 20, window: window)
            Self.send(.leftMouseUp, x: frame.maxX - 20, window: window)
            XCTAssertEqual(fixture.deletes, 1)
        }
    }

    func testNativeRightClickMenuHasWorkingActions() async throws {
        try await MainActor.run {
            let (fixture, _, window, input) = try Self.makeWindow()
            defer { window.close() }
            let event = Self.event(.rightMouseDown, x: 120, window: window)
            let menu = try XCTUnwrap(input.menu(for: event))
            XCTAssertEqual(menu.items.map(\.title), ["Edit Alarm", "Disable Alarm", "Delete Alarm"])
            menu.performActionForItem(at: 0)
            menu.performActionForItem(at: 1)
            menu.performActionForItem(at: 2)
            XCTAssertEqual(fixture.edits, 1)
            XCTAssertFalse(fixture.enabled)
            XCTAssertEqual(fixture.deletes, 1)
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            XCTAssertEqual(input.menu(for: event)?.items[1].title, "Enable Alarm")
        }
    }

    func testHorizontalScrollWheelTracksAndSettlesInBothDirections() async throws {
        try await MainActor.run {
            let (fixture, _, window, input) = try Self.makeWindow()
            defer { window.close() }
            let cg = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: -20, wheel3: 0))
            let left = try XCTUnwrap(NSEvent(cgEvent: cg))
            input.scrollWheel(with: left)
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            XCTAssertLessThan(input.offset, 0)
            for _ in 0..<4 { input.scrollWheel(with: left) }
            RunLoop.current.run(until: Date().addingTimeInterval(0.45))
            XCTAssertTrue(fixture.opened)
            cg.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: 20)
            cg.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: 20)
            let right = try XCTUnwrap(NSEvent(cgEvent: cg))
            for _ in 0..<5 { input.scrollWheel(with: right) }
            RunLoop.current.run(until: Date().addingTimeInterval(0.45))
            XCTAssertFalse(fixture.opened)
            XCTAssertEqual(fixture.deletes, 0)
        }
    }

    func testShortDragReturnsToClosedAndClickStillEdits() async throws {
        try await MainActor.run {
            let (fixture, _, window, _) = try Self.makeWindow()
            defer { window.close() }
            Self.send(.leftMouseDown, x: 150, window: window)
            Self.send(.leftMouseDragged, x: 140, window: window)
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            Self.send(.leftMouseUp, x: 140, window: window)
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
            XCTAssertFalse(fixture.opened)
            XCTAssertEqual(fixture.edits, 0)
            Self.send(.leftMouseDown, x: 150, window: window)
            Self.send(.leftMouseUp, x: 150, window: window)
            XCTAssertEqual(fixture.edits, 1)
        }
    }

    func testEditModeMinusStillDeletesWithFullRowInputSurface() async throws {
        try await MainActor.run {
            let (fixture, _, window, _) = try Self.makeWindow()
            defer { window.close() }
            fixture.editMode = true
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            Self.send(.leftMouseDown, x: 28, window: window)
            Self.send(.leftMouseUp, x: 28, window: window)
            XCTAssertEqual(fixture.deletes, 1)
            XCTAssertEqual(fixture.edits, 0)
        }
    }

    @MainActor private static func makeWindow() throws -> (RowFixture, NSHostingView<RowHarness>, NSWindow, RowInputView) {
        _ = NSApplication.shared
        let fixture = RowFixture()
        let host = NSHostingView(rootView: RowHarness(fixture: fixture))
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 358, height: 140), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        let input = try XCTUnwrap(descendants(of: host).compactMap { $0 as? RowInputView }.first)
        return (fixture, host, window, input)
    }

    @MainActor private static func switchFrame(in host: NSView) throws -> CGRect {
        let control = try XCTUnwrap(descendants(of: host).compactMap { $0 as? NSSwitch }.first)
        return control.convert(control.bounds, to: host)
    }
    @MainActor private static func descendants(of view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
    @MainActor private static func event(_ type: NSEvent.EventType, x: CGFloat, window: NSWindow) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: CGPoint(x: x, y: 70), modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1)!
    }
    @MainActor private static func send(_ type: NSEvent.EventType, x: CGFloat, window: NSWindow) {
        window.sendEvent(event(type, x: x, window: window))
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
    }
}
