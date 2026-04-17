import Foundation
import CoreGraphics

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var entries: [ClockEntry] { didSet { saveEntries() } }
    @Published var widgetX: Double { didSet { savePosition() } }
    @Published var widgetY: Double { didSet { savePosition() } }
    @Published var textColor: String { didSet { savePosition() } }
    @Published var shadowEnabled: Bool { didSet { savePosition() } }
    // Runtime state — not persisted
    @Published var isDraggable: Bool = false
    @Published var widgetSize: CGSize = CGSize(width: 200, height: 80)

    private let entriesKey = "clockEntries"
    private let positionKey = "widgetPosition"

    init() {
        if let data = UserDefaults.standard.data(forKey: "clockEntries"),
           let decoded = try? JSONDecoder().decode([ClockEntry].self, from: data) {
            entries = decoded
        } else {
            entries = [
                ClockEntry(label: "Boston", timeZoneIdentifier: "America/New_York", formatString: "hh:mm a", fontSize: 36),
                ClockEntry(label: "UTC", timeZoneIdentifier: "UTC", formatString: "HH:mm", fontSize: 28),
            ]
        }

        let defaults = UserDefaults.standard
        // Default to bottom-right: will be adjusted by DesktopWindowManager if 0
        widgetX = defaults.double(forKey: "widgetX")
        widgetY = defaults.double(forKey: "widgetY")
        textColor = defaults.string(forKey: "widgetTextColor") ?? "#FFFFFF"
        shadowEnabled = defaults.object(forKey: "widgetShadow") == nil ? true : defaults.bool(forKey: "widgetShadow")
    }

    func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
    }

    func savePosition() {
        UserDefaults.standard.set(widgetX, forKey: "widgetX")
        UserDefaults.standard.set(widgetY, forKey: "widgetY")
        UserDefaults.standard.set(textColor, forKey: "widgetTextColor")
        UserDefaults.standard.set(shadowEnabled, forKey: "widgetShadow")
    }

    @discardableResult
    func addEntry() -> ClockEntry {
        let entry = ClockEntry(label: "New", timeZoneIdentifier: TimeZone.current.identifier, formatString: "HH:mm", fontSize: 32)
        entries.append(entry)
        return entry
    }

    func removeEntries(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
    }
}
