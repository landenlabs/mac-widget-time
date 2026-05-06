import Foundation
import SwiftUI

enum RowAlignment: String, Codable, CaseIterable {
    case left, center, right

    var horizontal: HorizontalAlignment {
        switch self {
        case .left:   return .leading
        case .center: return .center
        case .right:  return .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .left:   return .leading
        case .center: return .center
        case .right:  return .trailing
        }
    }

    var label: String {
        switch self {
        case .left:   return "Left"
        case .center: return "Center"
        case .right:  return "Right"
        }
    }
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

    init(label: String, timeZoneIdentifier: String, formatString: String,
         fontSize: Double = 32, textColor: String = "#FFFFFF", shadowEnabled: Bool = true,
         rowAlignment: RowAlignment = .left) {
        self.id = UUID()
        self.label = label
        self.timeZoneIdentifier = timeZoneIdentifier
        self.formatString = formatString
        self.fontSize = fontSize
        self.textColor = textColor
        self.shadowEnabled = shadowEnabled
        self.rowAlignment = rowAlignment
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    // Custom decoder so old entries (without newer fields) still load.
    enum CodingKeys: String, CodingKey {
        case id, label, timeZoneIdentifier, formatString, fontSize, textColor, shadowEnabled, rowAlignment
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
    }
}
