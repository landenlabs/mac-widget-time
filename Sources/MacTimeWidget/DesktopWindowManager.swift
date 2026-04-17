import AppKit
import SwiftUI

class DesktopWindowManager: NSObject {
    private var window: DesktopWindow?
    private var hostingController: NSHostingController<DesktopClockView>?
    private var sizeObservation: NSKeyValueObservation?
    private var dragOverlay: DragOverlayView?
    private var isDragMode = false
    private let appState: AppState

    private let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(CGWindowLevelKey(rawValue: 2)!)) + 1)

    init(appState: AppState) {
        self.appState = appState
    }

    func setup() {
        let controller = NSHostingController(rootView: DesktopClockView(appState: appState))
        controller.sizingOptions = .preferredContentSize
        hostingController = controller

        let win = DesktopWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        win.level = desktopLevel
        win.contentViewController = controller

        placeWindow(win)
        win.orderFront(nil)
        self.window = win

        // Resize window whenever SwiftUI reports a new ideal size.
        // Anchor the left and bottom edges so widgetX/Y stay accurate across restarts.
        // The widget grows rightward and upward as content changes.
        sizeObservation = controller.observe(\.preferredContentSize, options: [.new]) { [weak self, weak win] ctrl, _ in
            let size = ctrl.preferredContentSize
            guard size.width > 0, size.height > 0, let win = win else { return }
            DispatchQueue.main.async {
                let leftEdge   = win.frame.minX
                let bottomEdge = win.frame.minY
                // Clamp so the widget doesn't extend past the right edge of the screen
                let maxX = NSScreen.main.map { $0.frame.maxX - size.width } ?? leftEdge
                let x = min(leftEdge, maxX)
                win.setFrame(
                    NSRect(x: x, y: bottomEdge, width: size.width, height: size.height),
                    display: true, animate: false
                )
                self?.appState.widgetSize = size
                self?.dragOverlay?.frame = win.contentView?.bounds ?? .zero
            }
        }
    }

    // MARK: - Position

    private func placeWindow(_ win: NSWindow) {
        guard let screen = NSScreen.main else { return }
        var x = appState.widgetX
        var y = appState.widgetY
        if x == 0 && y == 0 {
            x = screen.frame.maxX - 374
            y = screen.frame.minY + 60
            appState.widgetX = x
            appState.widgetY = y
        }
        win.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func updatePosition() {
        guard let win = window else { return }
        win.setFrameOrigin(NSPoint(x: appState.widgetX, y: appState.widgetY))
    }

    // MARK: - Drag mode

    func toggleDragMode() {
        isDragMode ? disableDragMode() : enableDragMode()
    }

    private func enableDragMode() {
        guard let win = window else { return }
        isDragMode = true
        appState.isDraggable = true

        win.ignoresMouseEvents = false
        win.level = .floating  // raise above other windows while repositioning

        let overlay = DragOverlayView(frame: win.contentView?.bounds ?? .zero)
        overlay.autoresizingMask = [.width, .height]
        overlay.onMove = { [weak self] origin in
            self?.appState.widgetX = origin.x
            self?.appState.widgetY = origin.y
        }
        win.contentView?.addSubview(overlay, positioned: .above, relativeTo: nil)
        dragOverlay = overlay
    }

    private func disableDragMode() {
        guard let win = window else { return }
        isDragMode = false
        appState.isDraggable = false

        dragOverlay?.removeFromSuperview()
        dragOverlay = nil

        win.ignoresMouseEvents = true
        win.level = desktopLevel

        // Persist final position
        appState.widgetX = win.frame.origin.x
        appState.widgetY = win.frame.origin.y
    }
}

class DesktopWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
