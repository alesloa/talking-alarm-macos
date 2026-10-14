import AppKit
import SwiftUI

/// AppKit handles the pointer directly so the first click in the menu bar
/// popover can grab a hand, without competing with the editor's ScrollView.
struct ClockInputSurface: NSViewRepresentable {
    @Binding var time: Date
    @Binding var selectedHand: ClockHand?

    func makeNSView(context: Context) -> ClockInputView { ClockInputView() }
    func updateNSView(_ view: ClockInputView, context: Context) {
        view.time = time
        view.onTimeChange = { time = $0 }
        view.onSelectionChange = { selectedHand = $0 }
    }
}

final class ClockInputView: NSView {
    var time = Date()
    var onTimeChange: ((Date) -> Void)?
    var onSelectionChange: ((ClockHand?) -> Void)?
    private var drag: ClockDrag?
    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let size = min(bounds.width, bounds.height)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        guard hypot(point.x - center.x, point.y - center.y) > 12 else { return }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let hand = ClockGeometry.nearestHand(at: point, center: center, size: size, hour: parts.hour!, minute: parts.minute!)
        drag = ClockDrag(hand: hand, phase: ClockGeometry.phase(at: point, center: center), hour: parts.hour!, minute: parts.minute!)
        onSelectionChange?(hand)
    }

    override func mouseDragged(with event: NSEvent) {
        guard var session = drag else { return }
        let point = convert(event.locationInWindow, from: nil)
        let selected = session.update(phase: ClockGeometry.phase(at: point, center: CGPoint(x: bounds.midX, y: bounds.midY)))
        drag = session
        time = Calendar.current.date(bySettingHour: selected.hour, minute: selected.minute, second: 0, of: time) ?? time
        onTimeChange?(time)
    }

    override func mouseUp(with event: NSEvent) {
        if drag != nil { mouseDragged(with: event) }
        drag = nil
        onSelectionChange?(nil)
    }
}
