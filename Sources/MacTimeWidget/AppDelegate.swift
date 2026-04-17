import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var desktopWindowManager: DesktopWindowManager?
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let manager = DesktopWindowManager(appState: AppState.shared)
        manager.setup()
        desktopWindowManager = manager

        setupStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Time Widget")

        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc func toggleDragMode() {
        desktopWindowManager?.toggleDragMode()
    }

    @objc func openSettings() {
        if settingsWindowController == nil {
            let view = SettingsView(appState: AppState.shared) { [weak self] in
                self?.desktopWindowManager?.updatePosition()
            }
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.title = "Time Widget Settings"
            win.contentView = NSHostingView(rootView: view)
            win.center()
            settingsWindowController = NSWindowController(window: win)
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleLaunchAtLogin() {
        launchAtLoginEnabled.toggle()
        setLoginItem(enabled: launchAtLoginEnabled)
    }

    private var launchAtLoginEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "launchAtLogin") }
        set { UserDefaults.standard.set(newValue, forKey: "launchAtLogin") }
    }

    private func setLoginItem(enabled: Bool) {
        let path = Bundle.main.bundlePath
        let script = enabled
            ? "tell application \"System Events\" to make login item at end with properties {path:\"\(path)\", hidden:false}"
            : "tell application \"System Events\" to delete (every login item whose path is \"\(path)\")"
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let isDragging = AppState.shared.isDraggable
        let moveTitle = isDragging ? "Done Moving Widget" : "Move Widget…"
        menu.addItem(NSMenuItem(title: moveTitle, action: #selector(toggleDragMode), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.state = launchAtLoginEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }
}
