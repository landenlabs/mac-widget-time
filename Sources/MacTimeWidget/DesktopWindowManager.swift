import AppKit
import SwiftUI

class DesktopWindowManager: NSObject {
    private var window: DesktopWindow?
    private var hostingController: NSHostingController<DesktopClockView>?
    private var sizeObservation: NSKeyValueObservation?
    private let appState: AppState

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
        // kCGDesktopWindowLevel + 1: above wallpaper, below normal app windows
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(CGWindowLevelKey(rawValue: 2)!)) + 1)
        win.contentViewController = controller

        placeWindow(win)
        win.orderFront(nil)
        self.window = win

        // Resize the window whenever SwiftUI reports a new ideal size.
        // Keep the bottom-right corner anchored so the widget grows upward.
        sizeObservation = controller.observe(\.preferredContentSize, options: [.new]) { [weak self, weak win] ctrl, _ in
            let size = ctrl.preferredContentSize
            guard size.width > 0, size.height > 0, let win = win else { return }
            DispatchQueue.main.async {
                let rightEdge = win.frame.maxX
                let bottomEdge = win.frame.minY
                win.setFrame(
                    NSRect(x: rightEdge - size.width, y: bottomEdge, width: size.width, height: size.height),
                    display: true,
                    animate: false
                )
            }
        }
    }

    private func placeWindow(_ win: NSWindow) {
        guard let screen = NSScreen.main else { return }
        var x = appState.widgetX
        var y = appState.widgetY
        if x == 0 && y == 0 {
            // Default: bottom-right, above the Dock
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
}

class DesktopWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
