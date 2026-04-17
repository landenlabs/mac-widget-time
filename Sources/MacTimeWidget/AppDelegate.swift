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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Time Widget")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = launchAtLoginEnabled ? .on : .off
        menu.addItem(launchItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    private var launchAtLoginEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "launchAtLogin") }
        set { UserDefaults.standard.set(newValue, forKey: "launchAtLogin") }
    }

    @objc private func toggleLaunchAtLogin() {
        launchAtLoginEnabled.toggle()
        // Rebuild menu to reflect updated state
        setupStatusItem()
        setLoginItem(enabled: launchAtLoginEnabled)
    }

    private func setLoginItem(enabled: Bool) {
        let appPath = Bundle.main.bundlePath
        // Use AppleScript as a simple cross-version approach (no entitlements needed for SPM builds)
        let script = enabled
            ? "tell application \"System Events\" to make login item at end with properties {path:\"\(appPath)\", hidden:false}"
            : "tell application \"System Events\" to delete (every login item whose path is \"\(appPath)\")"
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
    }

    @objc func openSettings() {
        if settingsWindowController == nil {
            let view = SettingsView(appState: AppState.shared) { [weak self] in
                self?.desktopWindowManager?.updatePosition()
            }
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: 440),
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
}
