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
                // Position is stored as the TOP edge, so keep the top-left corner
                // anchored while the content size settles — growing/shrinking the
                // window downward, never sliding the top edge.
                let topEdge  = win.frame.maxY
                let leftEdge = win.frame.minX
                let screen   = win.screen ?? NSScreen.main
                var x = leftEdge
                if let vf = screen?.visibleFrame {
                    x = min(max(x, vf.minX), vf.maxX - size.width)
                }
                win.setFrame(
                    NSRect(x: x, y: topEdge - size.height, width: size.width, height: size.height),
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
        let size = win.frame.size
        var x = config.positionX
        var y = config.positionY  // stored as TOP edge (frame.maxY)

        // No saved position for this set of displays → seed a sensible default
        // anchored to the top-right of the main screen.
        let hasSaved = config.screenPositions[ScreenFingerprint.current] != nil
        if !hasSaved && x == 0 && y == 0 {
            guard let screen = NSScreen.main else { return }
            let widgetIndex = appState.widgets.firstIndex(where: { $0.id == widgetID }) ?? 0
            x = screen.visibleFrame.maxX - size.width - 20 - Double(widgetIndex) * 30
            y = screen.visibleFrame.maxY - Double(widgetIndex) * 30
            appState.updatePosition(for: widgetID, x: x, y: y)
        } else {
            // Clamp the saved top-left so the widget stays fully on whichever
            // connected screen best contains it (max overlap, not a single
            // corner — maxY is exclusive in CGRect.contains).
            let widgetRect = NSRect(x: x, y: y - size.height, width: size.width, height: size.height)
            let screen = bestScreen(for: widgetRect) ?? NSScreen.main
            if let vf = screen?.visibleFrame {
                x = min(max(x, vf.minX), vf.maxX - size.width)
                y = min(max(y, vf.minY + size.height), vf.maxY)
            }
        }

        win.setFrameTopLeftPoint(NSPoint(x: x, y: y))
    }

    /// The connected screen whose frame overlaps `rect` the most, or nil if
    /// the rect lies entirely off every screen.
    private func bestScreen(for rect: NSRect) -> NSScreen? {
        NSScreen.screens
            .map { (screen: $0, overlap: overlapArea($0.frame, rect)) }
            .filter { $0.overlap > 0 }
            .max { $0.overlap < $1.overlap }?
            .screen
    }

    private func overlapArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let r = a.intersection(b)
        return r.isNull ? 0 : r.width * r.height
    }

    func updatePosition() {
        guard let win = window,
              let config = appState.widgets.first(where: { $0.id == widgetID }) else { return }
        win.setFrameTopLeftPoint(NSPoint(x: config.positionX, y: config.positionY))
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
            let topY = origin.y + (self.window?.frame.height ?? 0)
            self.appState.updatePosition(for: self.widgetID, x: origin.x, y: topY)
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

        appState.updatePosition(for: widgetID, x: win.frame.origin.x, y: win.frame.maxY)
    }
}

class DesktopWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
