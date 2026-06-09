// Copyright (c) 2026 LanDen Labs - Dennis Lang
import Foundation
import SwiftUI

enum RowAlignment: String, Codable, CaseIterable {
    case left, center, right, top, bottom

    static func choices(for orientation: WidgetOrientation) -> [RowAlignment] {
        orientation == .vertical ? [.left, .center, .right] : [.top, .center, .bottom]
    }

    var horizontal: HorizontalAlignment {
        switch self {
        case .left:          return .leading
        case .center:        return .center
        case .right:         return .trailing
        case .top, .bottom:  return .center
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .left:   return .leading
        case .center: return .center
        case .right:  return .trailing
        case .top:    return .top
        case .bottom: return .bottom
        }
    }

    var label: String { rawValue.capitalized }
}

struct ClockEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var label: String
    var timeZoneIdentifier: String
    var formatString: String
    var fontSize: Double
    var textColor: String
    var shadowEnabled: Bool
    var rowAlignment: RowAlignment
    var latitude: Double?
    var longitude: Double?

    init(label: String, timeZoneIdentifier: String, formatString: String,
         fontSize: Double = 32, textColor: String = "#FFFFFF", shadowEnabled: Bool = true,
         rowAlignment: RowAlignment = .left,
         latitude: Double? = nil, longitude: Double? = nil) {
        self.id = UUID()
        self.label = label
        self.timeZoneIdentifier = timeZoneIdentifier
        self.formatString = formatString
        self.fontSize = fontSize
        self.textColor = textColor
        self.shadowEnabled = shadowEnabled
        self.rowAlignment = rowAlignment
        self.latitude = latitude
        self.longitude = longitude
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    // Custom decoder so old entries (without newer fields) still load.
    enum CodingKeys: String, CodingKey {
        case id, label, timeZoneIdentifier, formatString, fontSize, textColor, shadowEnabled, rowAlignment, latitude, longitude
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                 = try c.decodeIfPresent(UUID.self,         forKey: .id)                 ?? UUID()
        label              = try c.decode(          String.self,       forKey: .label)
        timeZoneIdentifier = try c.decode(          String.self,       forKey: .timeZoneIdentifier)
        formatString       = try c.decode(          String.self,       forKey: .formatString)
        fontSize           = try c.decodeIfPresent( Double.self,       forKey: .fontSize)           ?? 32
        textColor          = try c.decodeIfPresent( String.self,       forKey: .textColor)          ?? "#FFFFFF"
        shadowEnabled      = try c.decodeIfPresent( Bool.self,         forKey: .shadowEnabled)      ?? true
        rowAlignment       = try c.decodeIfPresent( RowAlignment.self, forKey: .rowAlignment)       ?? .left
        latitude           = try c.decodeIfPresent( Double.self,       forKey: .latitude)
        longitude          = try c.decodeIfPresent( Double.self,       forKey: .longitude)
    }
}
