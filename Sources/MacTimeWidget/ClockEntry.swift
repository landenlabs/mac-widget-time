import Foundation

struct ClockEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var label: String
    var timeZoneIdentifier: String
    var formatString: String
    var fontSize: Double = 32

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }
}
