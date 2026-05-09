import Foundation
import AppKit

enum WidgetOrientation: String, Codable, CaseIterable {
    case vertical, horizontal
    var label: String { rawValue.capitalized }
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
    }

    var positionX: Double { screenPositions[ScreenFingerprint.current]?.x ?? widgetX }
    var positionY: Double { screenPositions[ScreenFingerprint.current]?.y ?? widgetY }

    enum CodingKeys: String, CodingKey {
        case id, name, entries, orientation, widgetX, widgetY, screenPositions
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
    }
}

enum ScreenFingerprint {
    static var current: String {
        NSScreen.screens
            .sorted { lhs, rhs in
                lhs.frame.minX != rhs.frame.minX
                    ? lhs.frame.minX < rhs.frame.minX
                    : lhs.frame.minY < rhs.frame.minY
            }
            .map { "\(Int($0.frame.width))x\(Int($0.frame.height))@\(Int($0.frame.minX)),\(Int($0.frame.minY))" }
            .joined(separator: "|")
    }
}
