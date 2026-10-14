import AppKit
import SwiftUI

// MenuBarExtra can retain its SwiftUI view while ordering the panel out.
// Observe the containing AppKit window instead of relying only on onDisappear.
struct PanelDismissObserver: NSViewRepresentable {
    let onDismiss: () -> Void

    func makeNSView(context: Context) -> PanelDismissView {
        let view = PanelDismissView()
        view.onDismiss = onDismiss
        return view
    }

    func updateNSView(_ view: PanelDismissView, context: Context) {
        view.onDismiss = onDismiss
    }
}

final class PanelDismissView: NSView {
    var onDismiss: () -> Void = {}
    private var visibilityObservation: NSKeyValueObservation?
    private var observers: [NSObjectProtocol] = []
    private var wasVisible = false

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeObservers()
        wasVisible = window?.isVisible ?? false
        guard let window else { return }
        visibilityObservation = window.observe(\.isVisible, options: [.new]) { [weak self] _, _ in
            self?.checkAfterWindowUpdate()
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            self?.dismissIfPreviouslyVisible()
        })
        checkAfterWindowUpdate()
    }

    private func checkAfterWindowUpdate() {
        // Wait for orderFront/orderOut to settle. Temporary focus changes from
        // a date-picker popup do not change visibility and keep the draft.
        guard let observedWindow = window else { return }
        DispatchQueue.main.async { [weak self, weak observedWindow] in
            guard let self, let observedWindow, self.window === observedWindow else { return }
            if observedWindow.isVisible { self.wasVisible = true }
            else { self.dismissIfPreviouslyVisible() }
        }
    }

    private func dismissIfPreviouslyVisible() {
        guard wasVisible else { return }
        wasVisible = false
        onDismiss()
    }

    private func removeObservers() {
        visibilityObservation?.invalidate()
        visibilityObservation = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    deinit { removeObservers() }
}
