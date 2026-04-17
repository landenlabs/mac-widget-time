import Foundation
import CoreGraphics

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var entries: [ClockEntry] { didSet { save() } }
    @Published var widgetX: Double       { didSet { save() } }
    @Published var widgetY: Double       { didSet { save() } }
    // Runtime — not persisted
    @Published var isDraggable: Bool = false
    @Published var widgetSize: CGSize    = CGSize(width: 200, height: 80)

    // MARK: - Persistence

    private struct Persisted: Codable {
        var entries: [ClockEntry]
        var widgetX: Double
        var widgetY: Double
    }

    private static var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent(Bundle.main.bundleIdentifier ?? "MacTimeWidget")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }

    init() {
        // Load from JSON if it exists.
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode(Persisted.self, from: data) {
            entries = saved.entries
            widgetX = saved.widgetX
            widgetY = saved.widgetY
            return
        }

        // Migrate from UserDefaults (previous storage) or use defaults.
        let defaults = UserDefaults.standard
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
        widgetX = defaults.double(forKey: "widgetX")
        widgetY = defaults.double(forKey: "widgetY")
        save()  // write migrated / default data to JSON
    }

    // Use direct assignment throughout so @Published reliably fires objectWillChange.

    func save() {
        guard let data = try? JSONEncoder().encode(
            Persisted(entries: entries, widgetX: widgetX, widgetY: widgetY)
        ) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    @discardableResult
    func addEntry() -> ClockEntry {
        let entry = ClockEntry(label: "New",
                               timeZoneIdentifier: TimeZone.current.identifier,
                               formatString: "HH:mm", fontSize: 32)
        entries = entries + [entry]
        return entry
    }

    func removeEntries(at offsets: IndexSet) {
        var e = entries
        e.remove(atOffsets: offsets)
        entries = e
    }
}
