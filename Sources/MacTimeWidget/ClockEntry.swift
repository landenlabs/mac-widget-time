import Foundation

struct ClockEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var label: String
    var timeZoneIdentifier: String
    var formatString: String
    var fontSize: Double
    var textColor: String
    var shadowEnabled: Bool

    init(label: String, timeZoneIdentifier: String, formatString: String,
         fontSize: Double = 32, textColor: String = "#FFFFFF", shadowEnabled: Bool = true) {
        self.id = UUID()
        self.label = label
        self.timeZoneIdentifier = timeZoneIdentifier
        self.formatString = formatString
        self.fontSize = fontSize
        self.textColor = textColor
        self.shadowEnabled = shadowEnabled
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    // Custom decoder so old entries (without textColor / shadowEnabled) still load.
    enum CodingKeys: String, CodingKey {
        case id, label, timeZoneIdentifier, formatString, fontSize, textColor, shadowEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                 = try c.decodeIfPresent(UUID.self,   forKey: .id)                 ?? UUID()
        label              = try c.decode(          String.self, forKey: .label)
        timeZoneIdentifier = try c.decode(          String.self, forKey: .timeZoneIdentifier)
        formatString       = try c.decode(          String.self, forKey: .formatString)
        fontSize           = try c.decodeIfPresent( Double.self, forKey: .fontSize)           ?? 32
        textColor          = try c.decodeIfPresent( String.self, forKey: .textColor)          ?? "#FFFFFF"
        shadowEnabled      = try c.decodeIfPresent( Bool.self,   forKey: .shadowEnabled)      ?? true
    }
}
