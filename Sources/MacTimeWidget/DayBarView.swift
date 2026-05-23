import SwiftUI

/// A thin 24-hour bar showing day vs night (from sunrise/sunset for some location),
/// with subtle 3-hour ticks and a red "now" tick.
struct DayBarView: View {
    let orientation: WidgetOrientation
    let length: CGFloat
    let thickness: CGFloat
    /// Fraction of the day [0,1] where sunrise/sunset fall in the source timezone.
    let sunriseFraction: Double?
    let sunsetFraction: Double?
    /// Fraction of the day [0,1] for "now" in the source timezone.
    let nowFraction: Double

    private let nightColor = Color.black.opacity(0.78)
    private let dayColor   = Color.white.opacity(0.55)
    private let tickColor  = Color.white.opacity(0.45)
    private let outline    = Color.white.opacity(0.18)

    var body: some View {
        if orientation == .horizontal {
            horizontalBar
                .frame(width: length, height: thickness)
        } else {
            verticalBar
                .frame(width: thickness, height: length)
        }
    }

    private var horizontalBar: some View {
        ZStack(alignment: .topLeading) {
            // Night background.
            Rectangle().fill(nightColor)

            // Day band.
            if let sr = sunriseFraction, let ss = sunsetFraction {
                let start = min(sr, ss)
                let end   = max(sr, ss)
                Rectangle()
                    .fill(dayColor)
                    .frame(width: max(0, CGFloat(end - start) * length))
                    .offset(x: CGFloat(start) * length)
            }

            // 3-hour ticks (every 3h = every 1/8th).
            ForEach(1..<8, id: \.self) { i in
                Rectangle()
                    .fill(tickColor)
                    .frame(width: 1, height: thickness * 0.45)
                    .offset(x: CGFloat(Double(i) / 8.0) * length, y: thickness * 0.275)
            }

            // Now tick.
            Rectangle()
                .fill(Color.red)
                .frame(width: 2, height: thickness)
                .offset(x: max(0, min(length - 2, CGFloat(nowFraction) * length - 1)))
        }
        .overlay(Rectangle().stroke(outline, lineWidth: 0.5))
    }

    private var verticalBar: some View {
        // Bottom = 0h, top = 24h.
        ZStack(alignment: .bottomLeading) {
            Rectangle().fill(nightColor)

            if let sr = sunriseFraction, let ss = sunsetFraction {
                let start = min(sr, ss)
                let end   = max(sr, ss)
                Rectangle()
                    .fill(dayColor)
                    .frame(height: max(0, CGFloat(end - start) * length))
                    .offset(y: -CGFloat(start) * length)
            }

            ForEach(1..<8, id: \.self) { i in
                Rectangle()
                    .fill(tickColor)
                    .frame(width: thickness * 0.45, height: 1)
                    .offset(x: thickness * 0.275, y: -CGFloat(Double(i) / 8.0) * length)
            }

            Rectangle()
                .fill(Color.red)
                .frame(width: thickness, height: 2)
                .offset(y: -max(0, min(length - 2, CGFloat(nowFraction) * length - 1)))
        }
        .overlay(Rectangle().stroke(outline, lineWidth: 0.5))
    }
}

/// Convert a `Date` into a [0,1) fraction of the day in the given timezone.
func dayFraction(for date: Date, in tz: TimeZone) -> Double {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    let comps = cal.dateComponents([.hour, .minute, .second], from: date)
    let secs = Double((comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60 + (comps.second ?? 0))
    return secs / 86400.0
}
