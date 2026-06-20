// Copyright (c) 2026 LanDen Labs - Dennis Lang
import Foundation
import SwiftUI

// MARK: - LeadingZeroConfig

struct LeadingZeroConfig: Codable, Equatable {
    var month:  Bool = false
    var day:    Bool = false
    var hour:   Bool = false
    var minute: Bool = true

    enum CodingKeys: String, CodingKey { case month, day, hour, minute }

    init() {}

    init(from decoder: Decoder) throws {
        let c  = try decoder.container(keyedBy: CodingKeys.self)
        month  = try c.decodeIfPresent(Bool.self, forKey: .month)  ?? false
        day    = try c.decodeIfPresent(Bool.self, forKey: .day)    ?? false
        hour   = try c.decodeIfPresent(Bool.self, forKey: .hour)   ?? false
        minute = try c.decodeIfPresent(Bool.self, forKey: .minute) ?? true
    }

    // Rebuild the format string so that stripped fields use a literal space + single-char
    // token instead of the zero-padded two-char token. E.g. "dd" → "' 'd" for day < 10.
    // Formatting with the rebuilt string produces space-padded output ("3" → " 3").
    func apply(to formatted: String, formatString: String, date: Date, tz: TimeZone) -> String {
        if month && day && hour && minute { return formatted }

        var cal = Calendar.current
        cal.timeZone = tz
        let comps     = cal.dateComponents([.month, .day, .hour, .minute], from: date)
        let monthVal  = comps.month  ?? 1
        let dayVal    = comps.day    ?? 1
        let hourVal   = comps.hour   ?? 0
        let minuteVal = comps.minute ?? 0
        let h12Val    = hourVal == 0 ? 12 : (hourVal > 12 ? hourVal - 12 : hourVal)

        var modified = ""
        var i = formatString.startIndex

        while i < formatString.endIndex {
            let c = formatString[i]

            if c == "'" {
                // Quoted literal — pass through unchanged (handles '' and 'text')
                modified.append(c)
                var j = formatString.index(after: i)
                while j < formatString.endIndex {
                    modified.append(formatString[j])
                    if formatString[j] == "'" { j = formatString.index(after: j); break }
                    j = formatString.index(after: j)
                }
                i = j
                continue
            }

            if c.isLetter {
                var j = formatString.index(after: i)
                while j < formatString.endIndex && formatString[j] == c {
                    j = formatString.index(after: j)
                }
                let tokenLen = formatString.distance(from: i, to: j)
                let token    = String(formatString[i..<j])

                // Only zero-padded 2-char tokens can have a leading zero.
                var rep: String? = nil
                if tokenLen == 2 {
                    switch c {
                    case "M" where !self.month  && monthVal  < 10: rep = "' 'M"
                    case "d" where !self.day    && dayVal    < 10: rep = "' 'd"
                    case "H" where !self.hour   && hourVal   < 10: rep = "' 'H"
                    case "h" where !self.hour   && h12Val    < 10: rep = "' 'h"
                    case "m" where !self.minute && minuteVal < 10: rep = "' 'm"
                    default: break
                    }
                }
                modified += rep ?? token
                i = j
                continue
            }

            modified.append(c)
            i = formatString.index(after: i)
        }

        if modified == formatString { return formatted }

        let fmt = DateFormatter()
        fmt.dateFormat = modified
        fmt.timeZone = tz
        return fmt.string(from: date)
    }
}

// MARK: - RowAlignment

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
    var leadingZero: LeadingZeroConfig

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
        self.leadingZero = LeadingZeroConfig()
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    // Custom decoder so old entries (without newer fields) still load.
    enum CodingKeys: String, CodingKey {
        case id, label, timeZoneIdentifier, formatString, fontSize, textColor, shadowEnabled, rowAlignment, latitude, longitude, leadingZero
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                 = try c.decodeIfPresent(UUID.self,              forKey: .id)                 ?? UUID()
        label              = try c.decode(          String.self,            forKey: .label)
        timeZoneIdentifier = try c.decode(          String.self,            forKey: .timeZoneIdentifier)
        formatString       = try c.decode(          String.self,            forKey: .formatString)
        fontSize           = try c.decodeIfPresent( Double.self,            forKey: .fontSize)           ?? 32
        textColor          = try c.decodeIfPresent( String.self,            forKey: .textColor)          ?? "#FFFFFF"
        shadowEnabled      = try c.decodeIfPresent( Bool.self,              forKey: .shadowEnabled)      ?? true
        rowAlignment       = try c.decodeIfPresent( RowAlignment.self,      forKey: .rowAlignment)       ?? .left
        latitude           = try c.decodeIfPresent( Double.self,            forKey: .latitude)
        longitude          = try c.decodeIfPresent( Double.self,            forKey: .longitude)
        leadingZero        = try c.decodeIfPresent( LeadingZeroConfig.self, forKey: .leadingZero)        ?? LeadingZeroConfig()
    }
}
