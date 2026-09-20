import AppKit
import SwiftUI

/// A movable, non-modal panel for tool dialogs: it never dims the editor, opens centered on
/// the canvas the first time, and reopens wherever it was last left (for the app session).
/// The close button reports through `onClose` so callers can treat it as Cancel.
@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    /// Top-left corners (screen coordinates) per panel, so a panel reopens where it was left.
    private static var positions: [String: NSPoint] = [:]
    let identifier: NSUserInterfaceItemIdentifier
    private let name: String
    var onClose: (() -> Void)?
    private var panel: NSPanel?
    private var dismissing = false

    init(name: String) {
        self.name = name
        identifier = NSUserInterfaceItemIdentifier(name)
    }

    func show(title: String, content: some View) {
        let panel = self.panel ?? makePanel()
        let wasVisible = panel.isVisible
        let topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        panel.title = title
        // A hosting *view* sized once, not a controller with `.preferredContentSize`:
        // that option makes AppKit measure the SwiftUI view during its constraint pass,
        // and SwiftUI's measurement invalidates layout re-entrantly, which AppKit treats
        // as a fatal exception.
        let host = NSHostingView(rootView: AnyView(content.roundedControls()))
        let size = host.fittingSize
        panel.contentView = host
        if size.width > 0, size.height > 0 { panel.setContentSize(size) }
        if wasVisible {
            panel.setFrameTopLeftPoint(topLeft) // Content changes must not shift the panel.
        } else if let saved = Self.positions[name] {
            panel.setFrameTopLeftPoint(saved)
        } else if let center = (NSApp.mainWindow ?? NSApp.keyWindow).flatMap(Self.canvasCenter) {
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
        } else {
            panel.center()
        }
        panel.makeKeyAndOrderFront(nil)
        remember(panel)
    }

    /// Hides the panel without reporting a close.
    func close() {
        guard let panel, panel.isVisible else { return }
        remember(panel)
        dismissing = true
        panel.orderOut(nil)
        dismissing = false
    }

    var isVisible: Bool { panel?.isVisible == true }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.identifier = identifier
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        self.panel = panel
        return panel
    }

    private func remember(_ panel: NSWindow) {
        Self.positions[name] = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
    }

    /// Screen-space center of the editor's canvas area, falling back to the window's.
    static func canvasCenter(in window: NSWindow) -> NSPoint? {
        func find(_ view: NSView) -> CanvasView? {
            if let canvas = view as? CanvasView { return canvas }
            for child in view.subviews { if let canvas = find(child) { return canvas } }
            return nil
        }
        guard let content = window.contentView else { return nil }
        guard let canvas = find(content) else { return NSPoint(x: window.frame.midX, y: window.frame.midY) }
        let rect = window.convertToScreen(canvas.convert(canvas.bounds, to: nil))
        return NSPoint(x: rect.midX, y: rect.midY)
    }

    func windowDidMove(_ notification: Notification) {
        if let panel, panel.isVisible { remember(panel) }
    }

    func windowWillClose(_ notification: Notification) {
        if let panel { remember(panel) }
        if !dismissing { onClose?() }
    }

    /// Returns keyboard focus to a panel, e.g. after a click on the canvas.
    static func refocus(_ identifier: NSUserInterfaceItemIdentifier) {
        NSApp.windows.first { $0.identifier == identifier && $0.isVisible }?.makeKey()
    }
}
