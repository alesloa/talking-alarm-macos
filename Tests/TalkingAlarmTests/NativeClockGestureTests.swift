import AppKit
import SwiftUI
import XCTest
@testable import TalkingAlarm

@MainActor private final class ClockFixture: ObservableObject {
    @Published var time = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 7, minute: 30))!
}

final class NativeClockGestureTests: XCTestCase {
    func testNativeMouseDragUpdatesBothHandsAndClockBinding() async throws {
        await MainActor.run {
            _ = NSApplication.shared
            let fixture = ClockFixture()
            let host = NSHostingView(rootView: ClockHarness(fixture: fixture))
            let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 200, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.makeKeyAndOrderFront(nil)
            defer { window.close() }
            host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))

            // Start on the minute-hand grip at six, then drag clockwise to nine.
            Self.send(.leftMouseDown, phase: 0.5, window: window)
            for step in 1...15 { Self.send(.leftMouseDragged, phase: 0.5 + Double(step) / 60, window: window) }
            Self.send(.leftMouseUp, phase: 0.75, window: window)
            XCTAssertEqual(Calendar.current.component(.hour, from: fixture.time), 7)
            XCTAssertEqual(Calendar.current.component(.minute, from: fixture.time), 45)

            // The short hand now points to 7:45; moving it one clock hour
            // updates the same binding and preserves the selected minutes.
            let hourPhase = 7.75 / 12
            Self.send(.leftMouseDown, phase: hourPhase, window: window, length: 200 * ClockGeometry.hourLength)
            for step in 1...12 { Self.send(.leftMouseDragged, phase: hourPhase + Double(step) / 144, window: window, length: 200 * ClockGeometry.hourLength) }
            Self.send(.leftMouseUp, phase: 8.75 / 12, window: window, length: 200 * ClockGeometry.hourLength)
            XCTAssertEqual(Calendar.current.component(.hour, from: fixture.time), 8)
            XCTAssertEqual(Calendar.current.component(.minute, from: fixture.time), 45)
        }
    }

    @MainActor private static func send(_ type: NSEvent.EventType, phase: Double, window: NSWindow, length: Double = 200 * ClockGeometry.minuteLength) {
        let point = ClockGeometry.point(phase: phase, center: CGPoint(x: 100, y: 100), length: length)
        let event = NSEvent.mouseEvent(with: type, location: CGPoint(x: point.x, y: 200 - point.y), modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1)!
        window.sendEvent(event)
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
    }
}

private struct ClockHarness: View {
    @ObservedObject var fixture: ClockFixture
    var body: some View { AlarmClockFace(time: $fixture.time).frame(width: 200, height: 200) }
}
