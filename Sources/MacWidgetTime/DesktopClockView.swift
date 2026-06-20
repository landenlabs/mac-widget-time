// Copyright (c) 2026 LanDen Labs - Dennis Lang
import SwiftUI

private extension VerticalAlignment {
    private enum RowVAlignmentKey: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d[.top] }
    }
    static let rowVAlignment = VerticalAlignment(RowVAlignmentKey.self)
}

private struct StackSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

struct DesktopClockView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var windowManager: DesktopWindowManager
    @ObservedObject var sunService: SunTimesService = .shared
    let widgetID: UUID
    @State private var now = Date()
    @State private var stackSize: CGSize = .zero

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var config: WidgetConfig? { appState.widgets.first { $0.id == widgetID } }

    var body: some View {
        Group {
            if let config {
                contentWithBar(config: config)
                    .padding(12)
                    .overlay(alignment: .topLeading) {
                        if windowManager.isDragging {
                            Text("drag to reposition")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
                                .padding(.leading, 4)
                                .padding(.top, 4)
                        }
                    }
                    .overlay {
                        if windowManager.isDragging {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.85),
                                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                        }
                    }
            }
        }
        .onReceive(timer) { now = $0 }
    }

    @ViewBuilder
    private func contentWithBar(config: WidgetConfig) -> some View {
        let measuredStack = entryStack(config: config)
            .background(
                GeometryReader { g in
                    Color.clear.preference(key: StackSizeKey.self, value: g.size)
                }
            )
            .onPreferenceChange(StackSizeKey.self) { stackSize = $0 }

        if config.dayBar.enabled, let source = config.dayBarSourceEntry {
            let bar = dayBar(for: source, config: config)
            switch (config.orientation, config.dayBar.alignment) {
            case (.horizontal, .above):
                VStack(spacing: 6) { bar; measuredStack }
            case (.horizontal, .below), (.horizontal, _):
                VStack(spacing: 6) { measuredStack; bar }
            case (.vertical, .leading):
                HStack(spacing: 6) { bar; measuredStack }
            case (.vertical, .trailing), (.vertical, _):
                HStack(spacing: 6) { measuredStack; bar }
            }
        } else {
            measuredStack
        }
    }

    @ViewBuilder
    private func dayBar(for source: ClockEntry, config: WidgetConfig) -> some View {
        let thickness = CGFloat(config.dayBar.thickness)
        let horizontal = config.orientation == .horizontal
        let length = horizontal ? max(40, stackSize.width) : max(40, stackSize.height)
        let tz = source.timeZone
        let sunTimes = resolveSunTimes(for: source)

        DayBarView(
            orientation: config.orientation,
            length: length,
            thickness: thickness,
            sunriseFraction: sunTimes.map { dayFraction(for: $0.sunrise, in: tz) },
            sunsetFraction:  sunTimes.map { dayFraction(for: $0.sunset,  in: tz) },
            nowFraction: dayFraction(for: now, in: tz)
        )
    }

    private func resolveSunTimes(for source: ClockEntry) -> SunTimesService.SunTimes? {
        guard let lat = source.latitude, let lon = source.longitude else { return nil }
        return sunService.times(latitude: lat, longitude: lon, on: now)
    }

    @ViewBuilder
    private func entryStack(config: WidgetConfig) -> some View {
        switch config.orientation {
        case .vertical:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(config.entries) { ClockEntryView(entry: $0, now: now, orientation: .vertical) }
            }
        case .horizontal:
            HStack(alignment: .rowVAlignment, spacing: 16) {
                ForEach(config.entries) { entry in
                    ClockEntryView(entry: entry, now: now, orientation: .horizontal)
                        .alignmentGuide(.rowVAlignment) { d in
                            switch entry.rowAlignment {
                            case .top:    return d[.top]
                            case .center: return d[VerticalAlignment.center]
                            case .bottom: return d[.bottom]
                            default:      return d[.top]
                            }
                        }
                }
            }
        }
    }
}

struct ClockEntryView: View {
    let entry: ClockEntry
    let now: Date
    let orientation: WidgetOrientation

    private var color: Color { Color(hex: entry.textColor) ?? .white }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = entry.formatString
        formatter.timeZone = entry.timeZone
        let s = formatter.string(from: now)
        return entry.leadingZero.apply(to: s, formatString: entry.formatString, date: now, tz: entry.timeZone)
    }

    var body: some View {
        if orientation == .vertical {
            VStack(alignment: entry.rowAlignment.horizontal, spacing: 1) {
                labelView
                timeView
            }
            .frame(maxWidth: .infinity, alignment: entry.rowAlignment.frameAlignment)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                labelView
                timeView
            }
        }
    }

    @ViewBuilder private var labelView: some View {
        if !entry.label.isEmpty {
            Text(entry.label)
                .font(.system(size: max(entry.fontSize * 0.38, 11), weight: .semibold, design: .monospaced))
                .foregroundColor(color.opacity(0.75))
                .shadow(color: entry.shadowEnabled ? .black.opacity(0.8) : .clear, radius: 2, x: 1, y: 1)
        }
    }

    private var timeView: some View {
        Text(formattedTime)
            .font(.system(size: entry.fontSize, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .shadow(color: entry.shadowEnabled ? .black.opacity(0.9) : .clear, radius: 3, x: 1, y: 1)
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int), hex.count == 6 || hex.count == 8 else { return nil }
        let r, g, b, a: Double
        switch hex.count {
        case 6:
            (r, g, b, a) = (Double((int >> 16) & 0xFF) / 255,
                            Double((int >> 8)  & 0xFF) / 255,
                            Double( int        & 0xFF) / 255, 1)
        case 8:
            (r, g, b, a) = (Double((int >> 24) & 0xFF) / 255,
                            Double((int >> 16) & 0xFF) / 255,
                            Double((int >> 8)  & 0xFF) / 255,
                            Double( int        & 0xFF) / 255)
        default:
            return nil
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
