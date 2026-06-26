// Copyright (c) 2026 LanDen Labs - Dennis Lang
import Foundation
import AppKit

enum WidgetOrientation: String, Codable, CaseIterable {
    case vertical, horizontal
    var label: String { rawValue.capitalized }
}

enum DayBarAlignment: String, Codable, CaseIterable {
    case above, below, leading, trailing

    static func choices(for orientation: WidgetOrientation) -> [DayBarAlignment] {
        orientation == .horizontal ? [.above, .below] : [.leading, .trailing]
    }

    static func defaultFor(_ orientation: WidgetOrientation) -> DayBarAlignment {
        orientation == .horizontal ? .below : .trailing
    }

    var label: String {
        switch self {
        case .above:    return "Above"
        case .below:    return "Below"
        case .leading:  return "Left"
        case .trailing: return "Right"
        }
    }
}

struct DayBarConfig: Codable, Equatable {
    var enabled: Bool
    var alignment: DayBarAlignment
    var thickness: Double
    var sourceEntryID: UUID?

    init(enabled: Bool = false,
         alignment: DayBarAlignment = .below,
         thickness: Double = 14,
         sourceEntryID: UUID? = nil) {
        self.enabled = enabled
        self.alignment = alignment
        self.thickness = thickness
        self.sourceEntryID = sourceEntryID
    }

    enum CodingKeys: String, CodingKey { case enabled, alignment, thickness, sourceEntryID }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled       = try c.decodeIfPresent(Bool.self,             forKey: .enabled)       ?? false
        alignment     = try c.decodeIfPresent(DayBarAlignment.self,  forKey: .alignment)     ?? .below
        thickness     = try c.decodeIfPresent(Double.self,           forKey: .thickness)     ?? 14
        sourceEntryID = try c.decodeIfPresent(UUID.self,             forKey: .sourceEntryID)
    }
}

struct ScreenPosition: Codable, Equatable {
    var x: Double
    var y: Double
}

struct WidgetConfig: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var entries: [ClockEntry]
    var orientation: WidgetOrientation
    var widgetX: Double
    var widgetY: Double
    var screenPositions: [String: ScreenPosition]
    var dayBar: DayBarConfig

    init(name: String = "Widget",
         entries: [ClockEntry] = [],
         orientation: WidgetOrientation = .vertical,
         widgetX: Double = 0,
         widgetY: Double = 0) {
        self.id = UUID()
        self.name = name
        self.entries = entries
        self.orientation = orientation
        self.widgetX = widgetX
        self.widgetY = widgetY
        self.screenPositions = [:]
        self.dayBar = DayBarConfig(alignment: DayBarAlignment.defaultFor(orientation))
    }

    var positionX: Double { screenPositions[ScreenFingerprint.current]?.x ?? widgetX }
    var positionY: Double { screenPositions[ScreenFingerprint.current]?.y ?? widgetY }

    /// Resolves the entry the day bar should track. Falls back to the first entry.
    var dayBarSourceEntry: ClockEntry? {
        if let id = dayBar.sourceEntryID, let match = entries.first(where: { $0.id == id }) {
            return match
        }
        return entries.first
    }

    enum CodingKeys: String, CodingKey {
        case id, name, entries, orientation, widgetX, widgetY, screenPositions, dayBar
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decodeIfPresent(UUID.self,                       forKey: .id)              ?? UUID()
        name            = try c.decodeIfPresent(String.self,                     forKey: .name)            ?? "Widget"
        entries         = try c.decodeIfPresent([ClockEntry].self,               forKey: .entries)         ?? []
        orientation     = try c.decodeIfPresent(WidgetOrientation.self,          forKey: .orientation)     ?? .vertical
        widgetX         = try c.decodeIfPresent(Double.self,                     forKey: .widgetX)         ?? 0
        widgetY         = try c.decodeIfPresent(Double.self,                     forKey: .widgetY)         ?? 0
        screenPositions = try c.decodeIfPresent([String: ScreenPosition].self,   forKey: .screenPositions) ?? [:]
        dayBar          = try c.decodeIfPresent(DayBarConfig.self,               forKey: .dayBar)
                          ?? DayBarConfig(alignment: DayBarAlignment.defaultFor(orientation))
    }
}

/// Identifies the current set of physically-connected displays so each
/// arrangement (laptop only, laptop + 1 external, 2 externals, …) can
/// remember its own widget position. Keyed on display IDs rather than
/// frames so simply moving a window never changes the fingerprint.
enum ScreenFingerprint {
    static var current: String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        let ids = NSScreen.screens
            .compactMap { $0.deviceDescription[key] as? NSNumber }
            .map { $0.uint32Value }
            .sorted()
        return ids.isEmpty ? "none" : ids.map(String.init).joined(separator: "|")
    }
}
