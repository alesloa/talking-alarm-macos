import AppKit
import SwiftUI

struct RowSwipe {
    static let actionWidth: CGFloat = 72
    static let actionGap: CGFloat = 8
    static let revealWidth = actionWidth + actionGap
    private let start: CGFloat
    private(set) var offset: CGFloat

    init(offset: CGFloat) { start = offset; self.offset = offset }
    mutating func update(translation: CGFloat) -> CGFloat {
        offset = max(-Self.revealWidth, min(0, start + translation))
        return offset
    }
    func shouldOpen(velocity: CGFloat = 0) -> Bool {
        offset + max(-1000, min(1000, velocity)) * 0.10 < -Self.revealWidth / 2
    }
}

/// Native pointer input avoids the SwiftUI Button/ScrollView capturing the drag.
/// The whole card translates, while Delete is a separate trailing action panel.
struct RowInputSurface: NSViewRepresentable {
    let offset: CGFloat
    let enabled: Bool
    let swipeEnabled: Bool
    let begin: () -> Void
    let changed: (CGFloat) -> Void
    let settle: (Bool) -> Void
    let edit: () -> Void
    let toggle: () -> Void
    let delete: () -> Void

    func makeNSView(context: Context) -> RowInputView {
        let view = RowInputView()
        view.setAccessibilityElement(false)
        return view
    }
    func updateNSView(_ view: RowInputView, context: Context) {
        view.offset = offset
        view.alarmEnabled = enabled
        view.swipeEnabled = swipeEnabled
        view.onBegin = begin
        view.onChange = changed
        view.onSettle = settle
        view.onEdit = edit
        view.onToggle = toggle
        view.onDelete = delete
    }
}

final class RowInputView: NSView {
    var offset: CGFloat = 0
    var alarmEnabled = true
    var swipeEnabled = true
    var onBegin: (() -> Void)?
    var onChange: ((CGFloat) -> Void)?
    var onSettle: ((Bool) -> Void)?
    var onEdit: (() -> Void)?
    var onToggle: (() -> Void)?
    var onDelete: (() -> Void)?
    private var mouseStart: CGPoint?
    private var mouseSwipe: RowSwipe?
    private var dragging = false
    private var moved = false
    private var pressedDelete = false
    private var pressedToggle = false
    private var pressedInlineDelete = false
    private var previousX: CGFloat = 0
    private var previousTime: TimeInterval = 0
    private var velocity: CGFloat = 0
    private var scrollSwipe: RowSwipe?
    private var scrollTranslation: CGFloat = 0
    private var scrollTimer: Timer?

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        finishScroll()
        mouseStart = convert(event.locationInWindow, from: nil)
        pressedDelete = isDeleteRegion(mouseStart!)
        pressedToggle = isToggleRegion(mouseStart!)
        pressedInlineDelete = isInlineDeleteRegion(mouseStart!)
        mouseSwipe = RowSwipe(offset: offset)
        previousX = mouseStart!.x
        previousTime = event.timestamp
        velocity = 0; dragging = false; moved = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseStart, swipeEnabled else { return }
        let point = convert(event.locationInWindow, from: nil)
        let dx = point.x - start.x, dy = point.y - start.y
        if hypot(dx, dy) > 4 { moved = true }
        if !dragging {
            guard abs(dx) > 4, abs(dx) > abs(dy) else { return }
            dragging = true
            onBegin?()
        }
        if event.timestamp > previousTime {
            velocity = (point.x - previousX) / (event.timestamp - previousTime)
        }
        previousX = point.x; previousTime = event.timestamp
        if let value = mouseSwipe?.update(translation: dx) { onChange?(value) }
    }
    override func mouseUp(with event: NSEvent) {
        if dragging, let swipe = mouseSwipe {
            onSettle?(swipe.shouldOpen(velocity: event.timestamp - previousTime < 0.12 ? velocity : 0))
        } else if !moved {
            let point = convert(event.locationInWindow, from: nil)
            if pressedToggle, isToggleRegion(point) { onToggle?() }
            else if pressedInlineDelete, isInlineDeleteRegion(point) { onDelete?() }
            else if pressedDelete, isDeleteRegion(point) { onDelete?() }
            else if offset < 0 { onSettle?(false) }
            else { onEdit?() }
        }
        mouseStart = nil; mouseSwipe = nil; dragging = false
        pressedDelete = false; pressedToggle = false; pressedInlineDelete = false
    }

    private func isDeleteRegion(_ point: CGPoint) -> Bool {
        offset < 0 && bounds.contains(point) && point.x >= bounds.width + offset + RowSwipe.actionGap
    }

    private func isToggleRegion(_ point: CGPoint) -> Bool {
        CGRect(x: bounds.width - 18 - 44 + offset, y: bounds.midY - 14, width: 44, height: 28).contains(point)
    }

    private func isInlineDeleteRegion(_ point: CGPoint) -> Bool {
        !swipeEnabled && CGRect(x: 14, y: bounds.midY - 14, width: 28, height: 28).contains(point)
    }

    override func scrollWheel(with event: NSEvent) {
        if !swipeEnabled || (scrollSwipe == nil && abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX)) {
            super.scrollWheel(with: event)
            return
        }
        // Momentum must not reopen or close a row after the fingers lift.
        guard event.momentumPhase.isEmpty else { return }
        if scrollSwipe == nil {
            scrollSwipe = RowSwipe(offset: offset)
            scrollTranslation = 0
            onBegin?()
        }
        scrollTranslation += event.scrollingDeltaX
        if let value = scrollSwipe?.update(translation: scrollTranslation) { onChange?(value) }
        scrollTimer?.invalidate()
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            finishScroll()
        } else if event.phase.isEmpty {
            let timer = Timer(timeInterval: 0.14, repeats: false) { [weak self] _ in self?.finishScroll() }
            scrollTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { scrollTimer?.invalidate(); scrollTimer = nil; scrollSwipe = nil }
    }

    private func finishScroll() {
        scrollTimer?.invalidate(); scrollTimer = nil
        if let swipe = scrollSwipe { onSettle?(swipe.shouldOpen()) }
        scrollSwipe = nil
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let actions: [(String, Selector, String)] = [
            ("Edit Alarm", #selector(editAlarm), "pencil"),
            (alarmEnabled ? "Disable Alarm" : "Enable Alarm", #selector(toggleAlarm), "power"),
            ("Delete Alarm", #selector(deleteAlarm), "trash")
        ]
        for (title, action, symbol) in actions {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            menu.addItem(item)
        }
        return menu
    }

    @objc private func editAlarm() { onEdit?() }
    @objc private func toggleAlarm() { onToggle?() }
    @objc private func deleteAlarm() { onDelete?() }
}
