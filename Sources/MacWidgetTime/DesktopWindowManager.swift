// Copyright (c) 2026 LanDen Labs - Dennis Lang
import AppKit
import SwiftUI

class DesktopWindowManager: NSObject, ObservableObject {
    let widgetID: UUID
    private let appState: AppState
    private var window: DesktopWindow?
    private var hostingController: NSHostingController<DesktopClockView>?
    private var sizeObservation: NSKeyValueObservation?
    private var dragOverlay: DragOverlayView?
    private var isDragModeActive = false

    @Published var isDragging: Bool = false

    private let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(CGWindowLevelKey(rawValue: 2)!)) + 1)

    init(widgetID: UUID, appState: AppState) {
        self.widgetID = widgetID
        self.appState = appState
    }

    func setup() {
        let view = DesktopClockView(appState: appState, windowManager: self, widgetID: widgetID)
        let controller = NSHostingController(rootView: view)
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
        win.isReleasedWhenClosed = false
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        win.level = desktopLevel
        win.contentViewController = controller

        placeWindow(win)
        win.orderFront(nil)
        self.window = win

        sizeObservation = controller.observe(\.preferredContentSize, options: [.new]) { [weak self, weak win] ctrl, _ in
            let size = ctrl.preferredContentSize
            guard size.width > 0, size.height > 0, let win = win else { return }
            DispatchQueue.main.async { [weak self, weak win] in
                guard let win = win else { return }
                let leftEdge   = win.frame.minX
                let bottomEdge = win.frame.minY
                let screen = win.screen ?? NSScreen.main
                let maxX = screen.map { $0.frame.maxX - size.width } ?? leftEdge
                let x = min(leftEdge, maxX)
                win.setFrame(
                    NSRect(x: x, y: bottomEdge, width: size.width, height: size.height),
                    display: true, animate: false
                )
                if let self {
                    self.appState.widgetSizes[self.widgetID] = size
                    self.dragOverlay?.frame = win.contentView?.bounds ?? .zero
                }
            }
        }
    }

    func teardown() {
        sizeObservation?.invalidate()
        sizeObservation = nil
        if isDragModeActive { isDragging = false }
        dragOverlay?.removeFromSuperview()
        dragOverlay = nil
        window?.close()
        window = nil
        hostingController = nil
    }

    // MARK: - Position

    private func placeWindow(_ win: NSWindow) {
        guard let config = appState.widgets.first(where: { $0.id == widgetID }) else { return }
        var x = config.positionX
        var y = config.positionY

        if x == 0 && y == 0 {
            guard let screen = NSScreen.main else { return }
            let widgetIndex = appState.widgets.firstIndex(where: { $0.id == widgetID }) ?? 0
            x = screen.visibleFrame.maxX - 374 - Double(widgetIndex) * 30
            y = screen.visibleFrame.minY + 60 + Double(widgetIndex) * 30
            appState.updatePosition(for: widgetID, x: x, y: y)
        } else {
            let savedOrigin = NSPoint(x: x, y: y)
            let screen = NSScreen.screens.first(where: { $0.frame.contains(savedOrigin) }) ?? NSScreen.main
            if let vf = screen?.visibleFrame {
                x = max(vf.minX, x)
                y = max(vf.minY, y)
            }
        }

        win.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func updatePosition() {
        guard let win = window,
              let config = appState.widgets.first(where: { $0.id == widgetID }) else { return }
        win.setFrameOrigin(NSPoint(x: config.positionX, y: config.positionY))
    }

    // MARK: - Drag mode

    func toggleDragMode() {
        isDragModeActive ? disableDragMode() : enableDragMode()
    }

    private func enableDragMode() {
        guard let win = window else { return }
        isDragModeActive = true
        isDragging = true

        win.ignoresMouseEvents = false
        win.level = .floating

        let overlay = DragOverlayView(frame: win.contentView?.bounds ?? .zero)
        overlay.autoresizingMask = [.width, .height]
        overlay.onMove = { [weak self] origin in
            guard let self else { return }
            self.appState.updatePosition(for: self.widgetID, x: origin.x, y: origin.y)
        }
        win.contentView?.addSubview(overlay, positioned: .above, relativeTo: nil)
        dragOverlay = overlay
    }

    private func disableDragMode() {
        guard let win = window else { return }
        isDragModeActive = false
        isDragging = false

        dragOverlay?.removeFromSuperview()
        dragOverlay = nil

        win.ignoresMouseEvents = true
        win.level = desktopLevel

        appState.updatePosition(for: widgetID, x: win.frame.origin.x, y: win.frame.origin.y)
    }
}

class DesktopWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
