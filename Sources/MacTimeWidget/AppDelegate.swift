import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var windowManagers: [UUID: DesktopWindowManager] = [:]
    private var settingsWindowController: NSWindowController?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let appState = AppState.shared
        for widget in appState.widgets {
            spawnWindowManager(for: widget.id)
        }

        // Sync window managers whenever the set of widget IDs changes.
        appState.$widgets
            .map { Set($0.map(\.id)) }
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncWindowManagers(to: AppState.shared.widgets)
            }
            .store(in: &cancellables)

        setupStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: - Window management

    private func spawnWindowManager(for widgetID: UUID) {
        guard windowManagers[widgetID] == nil else { return }
        let manager = DesktopWindowManager(widgetID: widgetID, appState: AppState.shared)
        manager.setup()
        windowManagers[widgetID] = manager
    }

    private func syncWindowManagers(to widgets: [WidgetConfig]) {
        let activeIDs = Set(widgets.map(\.id))
        for widget in widgets where windowManagers[widget.id] == nil {
            spawnWindowManager(for: widget.id)
        }
        for id in windowManagers.keys where !activeIDs.contains(id) {
            windowManagers[id]?.teardown()
            windowManagers.removeValue(forKey: id)
        }
    }

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

    @objc func toggleDragMode(_ sender: NSMenuItem?) {
        guard let id = sender?.representedObject as? UUID,
              let manager = windowManagers[id] else { return }
        manager.toggleDragMode()
    }

    @objc func addWidget() {
        AppState.shared.addWidget()
    }

    @objc func removeWidget(_ sender: NSMenuItem?) {
        guard let id = sender?.representedObject as? UUID else { return }
        AppState.shared.removeWidget(id: id)
    }

    @objc func openSettings() {
        if settingsWindowController == nil {
            let view = SettingsView(appState: AppState.shared) { [weak self] in
                self?.windowManagers.values.forEach { $0.updatePosition() }
            }
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 540),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.title = "Time Widget Settings"
            win.contentView = NSHostingView(rootView: view)
            win.center()
            let wc = NSWindowController(window: win)
            wc.shouldCascadeWindows = false
            settingsWindowController = wc

            // Release when closed so settings re-opens fresh next time.
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: win, queue: .main
            ) { [weak self] _ in
                self?.settingsWindowController = nil
            }
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

        let appState = AppState.shared
        for widget in appState.widgets {
            let isDragging = windowManagers[widget.id]?.isDragging ?? false
            let title = isDragging ? "Done Moving \(widget.name)" : "Move \(widget.name)…"
            let item = NSMenuItem(title: title, action: #selector(toggleDragMode(_:)), keyEquivalent: "")
            item.representedObject = widget.id
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Add Widget", action: #selector(addWidget), keyEquivalent: ""))

        if appState.widgets.count > 1 {
            let removeMenu = NSMenu()
            for widget in appState.widgets {
                let item = NSMenuItem(title: widget.name, action: #selector(removeWidget(_:)), keyEquivalent: "")
                item.representedObject = widget.id
                removeMenu.addItem(item)
            }
            let removeItem = NSMenuItem(title: "Remove Widget", action: nil, keyEquivalent: "")
            removeItem.submenu = removeMenu
            menu.addItem(removeItem)
        }

        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.state = launchAtLoginEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }
}
