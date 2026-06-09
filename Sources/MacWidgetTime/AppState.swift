// Copyright (c) 2026 LanDen Labs - Dennis Lang
import Foundation
import CoreGraphics

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var widgets: [WidgetConfig] { didSet { save() } }
    // Runtime — not persisted. Updated by each DesktopWindowManager for the ScreenMapView.
    @Published var widgetSizes: [UUID: CGSize] = [:]

    // MARK: - Persistence

    private struct Persisted: Codable {
        var widgets: [WidgetConfig]
    }

    private struct LegacyPersisted: Codable {
        var entries: [ClockEntry]
        var widgetX: Double
        var widgetY: Double
    }

    private static var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent(Bundle.main.bundleIdentifier ?? "MacWidgetTime")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }

    init() {
        if let data = try? Data(contentsOf: Self.fileURL) {
            // Try new multi-widget format first.
            if let saved = try? JSONDecoder().decode(Persisted.self, from: data), !saved.widgets.isEmpty {
                widgets = saved.widgets
                return
            }
            // Migrate from single-widget JSON format.
            if let legacy = try? JSONDecoder().decode(LegacyPersisted.self, from: data) {
                var w = WidgetConfig(name: "Widget 1", entries: legacy.entries,
                                     widgetX: legacy.widgetX, widgetY: legacy.widgetY)
                w.screenPositions[ScreenFingerprint.current] = ScreenPosition(x: legacy.widgetX, y: legacy.widgetY)
                widgets = [w]
                save()
                return
            }
        }

        // Migrate from UserDefaults (pre-JSON storage) or use hardcoded defaults.
        let defaults = UserDefaults.standard
        let entries: [ClockEntry]
        if let data = defaults.data(forKey: "clockEntries"),
           let old = try? JSONDecoder().decode([ClockEntry].self, from: data) {
            entries = old
        } else {
            entries = [
                ClockEntry(label: "Boston", timeZoneIdentifier: "America/New_York",
                           formatString: "hh:mm a", fontSize: 36),
                ClockEntry(label: "UTC",    timeZoneIdentifier: "UTC",
                           formatString: "HH:mm",   fontSize: 28),
            ]
        }
        let x = defaults.double(forKey: "widgetX")
        let y = defaults.double(forKey: "widgetY")
        var w = WidgetConfig(name: "Widget 1", entries: entries, widgetX: x, widgetY: y)
        if x != 0 || y != 0 {
            w.screenPositions[ScreenFingerprint.current] = ScreenPosition(x: x, y: y)
        }
        widgets = [w]
        save()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(Persisted(widgets: widgets)) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    // MARK: - Widget management

    @discardableResult
    func addWidget() -> WidgetConfig {
        let w = WidgetConfig(
            name: "Widget \(widgets.count + 1)",
            entries: [ClockEntry(label: "Local",
                                 timeZoneIdentifier: TimeZone.current.identifier,
                                 formatString: "HH:mm", fontSize: 32)]
        )
        widgets = widgets + [w]
        return w
    }

    func removeWidget(id: UUID) {
        guard widgets.count > 1 else { return }
        widgets = widgets.filter { $0.id != id }
    }

    // MARK: - Entry management

    @discardableResult
    func addEntry(to widgetID: UUID) -> ClockEntry? {
        guard let idx = widgets.firstIndex(where: { $0.id == widgetID }) else { return nil }
        let entry = ClockEntry(label: "New",
                               timeZoneIdentifier: TimeZone.current.identifier,
                               formatString: "HH:mm", fontSize: 32)
        var updated = widgets
        updated[idx].entries.append(entry)
        widgets = updated
        return entry
    }

    func removeEntries(from widgetID: UUID, at offsets: IndexSet) {
        guard let idx = widgets.firstIndex(where: { $0.id == widgetID }) else { return }
        var updated = widgets
        updated[idx].entries.remove(atOffsets: offsets)
        widgets = updated
    }

    func moveEntries(in widgetID: UUID, from source: IndexSet, to destination: Int) {
        guard let idx = widgets.firstIndex(where: { $0.id == widgetID }) else { return }
        var updated = widgets
        updated[idx].entries.move(fromOffsets: source, toOffset: destination)
        widgets = updated
    }

    // MARK: - Position

    func updatePosition(for widgetID: UUID, x: Double, y: Double) {
        guard let idx = widgets.firstIndex(where: { $0.id == widgetID }) else { return }
        var updated = widgets
        updated[idx].widgetX = x
        updated[idx].widgetY = y
        updated[idx].screenPositions[ScreenFingerprint.current] = ScreenPosition(x: x, y: y)
        widgets = updated
    }
}
