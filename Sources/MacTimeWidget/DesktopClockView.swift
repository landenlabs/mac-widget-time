import SwiftUI

private extension VerticalAlignment {
    private enum RowVAlignmentKey: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d[.top] }
    }
    static let rowVAlignment = VerticalAlignment(RowVAlignmentKey.self)
}

struct DesktopClockView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var windowManager: DesktopWindowManager
    let widgetID: UUID
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var config: WidgetConfig? { appState.widgets.first { $0.id == widgetID } }

    var body: some View {
        Group {
            if let config {
                entryStack(config: config)
                    .padding(12)
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
    private func entryStack(config: WidgetConfig) -> some View {
        switch config.orientation {
        case .vertical:
            VStack(alignment: .leading, spacing: 6) {
                dragHint
                ForEach(config.entries) { ClockEntryView(entry: $0, now: now, orientation: .vertical) }
            }
        case .horizontal:
            HStack(alignment: .rowVAlignment, spacing: 16) {
                dragHint
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

    @ViewBuilder private var dragHint: some View {
        if windowManager.isDragging {
            Text("drag to reposition")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
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
        return formatter.string(from: now)
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
