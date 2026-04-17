import SwiftUI
import CoreLocation

// MARK: - Navigation

private enum Nav: Hashable {
    case general
    case entry(UUID)
}

// MARK: - SettingsView

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var nav: Nav = .general
    var onPositionChanged: (() -> Void)?

    var body: some View {
        HSplitView {
            sidebar.frame(minWidth: 170, maxWidth: 210)
            detail.frame(minWidth: 460)
        }
        .frame(minWidth: 660, minHeight: 500)
        // If the selected entry is deleted, fall back to general panel
        .onChange(of: appState.entries) { entries in
            if case .entry(let id) = nav, !entries.contains(where: { $0.id == id }) {
                nav = .general
            }
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: $nav) {
            Section("Widget") {
                Label("Position & Appearance", systemImage: "slider.horizontal.3")
                    .tag(Nav.general)
            }
            Section("Clocks") {
                ForEach(appState.entries) { entry in
                    Label(entry.label.isEmpty ? "(unnamed)" : entry.label,
                          systemImage: "clock")
                        .tag(Nav.entry(entry.id))
                }
                .onDelete { appState.removeEntries(at: $0) }
            }
        }
        .listStyle(.sidebar)
        // safeAreaInset keeps buttons visible below the list without fighting for VStack space
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                Button {
                    let e = appState.addEntry()
                    nav = .entry(e.id)
                } label: {
                    Image(systemName: "plus").frame(width: 26, height: 22)
                }
                .buttonStyle(.plain)

                if case .entry(let id) = nav {
                    Divider().frame(height: 16)
                    Button {
                        nav = .general
                        appState.entries = appState.entries.filter { $0.id != id }
                    } label: {
                        Image(systemName: "minus").frame(width: 26, height: 22)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.bar)
        }
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        switch nav {
        case .general:
            generalPanel
        case .entry(let id):
            if let idx = appState.entries.firstIndex(where: { $0.id == id }) {
                EntryEditView(entry: $appState.entries[idx])
                    .id(id)   // force a fresh view (resets Form scroll) when selection changes
            } else {
                generalPanel
            }
        }
    }

    // MARK: Position & Appearance panel

    private var generalPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                positionSection
                Divider()
                appearanceSection
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Widget Position")
                .font(.headline)

            ScreenMapView(
                widgetX: $appState.widgetX,
                widgetY: $appState.widgetY,
                widgetSize: appState.widgetSize
            ) { onPositionChanged?() }

            HStack(spacing: 20) {
                coordField(label: "X:", value: $appState.widgetX)
                coordField(label: "Y:", value: $appState.widgetY)
            }

            Text("(0, 0) = screen bottom-left. Drag the blue block above to reposition.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func coordField(label: String, value: Binding<Double>) -> some View {
        HStack(spacing: 6) {
            Text(label).frame(width: 18, alignment: .trailing)
            TextField("0", value: value, formatter: NumberFormatter())
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .onChange(of: value.wrappedValue) { _ in onPositionChanged?() }
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.headline)

            HStack(spacing: 10) {
                Text("Text Color:")
                TextField("#FFFFFF", text: $appState.textColor)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .font(.system(.body, design: .monospaced))
                ColorPicker("", selection: colorPickerBinding, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 32, height: 26)
            }

            Toggle("Text Shadow", isOn: $appState.shadowEnabled)
        }
    }

    /// Two-way binding between the hex string in AppState and SwiftUI Color for ColorPicker.
    private var colorPickerBinding: Binding<Color> {
        Binding(
            get: {
                Color(hex: appState.textColor) ?? .white
            },
            set: { color in
                guard let ns = NSColor(color).usingColorSpace(.sRGB) else { return }
                appState.textColor = String(
                    format: "#%02X%02X%02X",
                    Int((ns.redComponent   * 255).rounded()),
                    Int((ns.greenComponent * 255).rounded()),
                    Int((ns.blueComponent  * 255).rounded())
                )
            }
        )
    }
}

// MARK: - Screen mini-map

struct ScreenMapView: View {
    @Binding var widgetX: Double
    @Binding var widgetY: Double
    var widgetSize: CGSize
    var onChanged: () -> Void

    private let mapSize = CGSize(width: 360, height: 202)   // 16:9, fills panel nicely

    private var screen: CGRect {
        guard let f = NSScreen.main?.frame else { return CGRect(x: 0, y: 0, width: 2560, height: 1440) }
        return CGRect(x: f.minX, y: f.minY, width: f.width, height: f.height)
    }
    private var sx: Double { mapSize.width  / screen.width  }
    private var sy: Double { mapSize.height / screen.height }

    private var widgetMapRect: CGRect {
        let mx    = (widgetX - screen.minX) * sx
        let myTop = mapSize.height - (widgetY - screen.minY + widgetSize.height) * sy
        return CGRect(
            x: mx, y: myTop,
            width:  max(10, widgetSize.width  * sx),
            height: max(5,  widgetSize.height * sy)
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

            RoundedRectangle(cornerRadius: 3)
                .fill(Color.accentColor.opacity(0.85))
                .frame(width: widgetMapRect.width, height: widgetMapRect.height)
                .offset(x: widgetMapRect.minX, y: widgetMapRect.minY)
        }
        .frame(width: mapSize.width, height: mapSize.height)
        .coordinateSpace(name: "screenMap")
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("screenMap"))
                .onChanged { value in
                    let nx = value.location.x / sx + screen.minX
                    let ny = (mapSize.height - value.location.y) / sy + screen.minY
                    widgetX = max(screen.minX, min(nx, screen.maxX - widgetSize.width))
                    widgetY = max(screen.minY, min(ny, screen.maxY - widgetSize.height))
                    onChanged()
                }
        )
        .help("Click or drag to reposition the widget")
    }
}

// MARK: - Entry editor

struct EntryEditView: View {
    @Binding var entry: ClockEntry
    @State private var tzSearch = ""
    @State private var cityQuery = ""
    @State private var geoStatus: GeoStatus = .idle
    @State private var isSearching = false

    enum GeoStatus {
        case idle, searching
        case found(String), notFound, error(String)
    }

    private var filteredTZs: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers.sorted()
        return tzSearch.isEmpty ? all : all.filter { $0.localizedCaseInsensitiveContains(tzSearch) }
    }

    var body: some View {
        Form {
            Section("Clock Entry") {
                LabeledContent("Label") {
                    TextField("e.g. Boston", text: $entry.label)
                }

                LabeledContent("Find Time Zone") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            TextField("", text: $cityQuery,
                                      prompt: Text("Paris, France  •  Austin, Texas"))
                                .frame(maxWidth: 260)
                                .onSubmit { findTimeZone() }
                            Button(isSearching ? "Searching…" : "Find") { findTimeZone() }
                                .disabled(cityQuery.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                        }
                        geoStatusView
                    }
                }

                LabeledContent("Time Zone") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Filter…", text: $tzSearch)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                        Picker("", selection: $entry.timeZoneIdentifier) {
                            ForEach(filteredTZs, id: \.self) { tz in Text(tz).tag(tz) }
                        }
                        .frame(maxWidth: 260, maxHeight: 110)
                        Text("Current: \(entry.timeZoneIdentifier)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }

                LabeledContent("Format") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("HH:mm", text: $entry.formatString)
                            .font(.system(.body, design: .monospaced))
                        Text("yyyy yy  MMM MM M  dd d  HH H  hh h  mm ss  a  EEE EEEE  zzz")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }

                LabeledContent("Font Size: \(Int(entry.fontSize))pt") {
                    Slider(value: $entry.fontSize, in: 12...96, step: 2)
                        .frame(maxWidth: 200)
                }

                LabeledContent("Preview") {
                    Text(previewTime)
                        .font(.system(size: min(entry.fontSize, 28), weight: .bold, design: .monospaced))
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private var geoStatusView: some View {
        switch geoStatus {
        case .idle:
            Text("International: \"City, Country\"  •  US: \"City, State\"")
                .font(.caption).foregroundColor(.secondary)
        case .searching:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.6)
                Text("Looking up…").font(.caption).foregroundColor(.secondary)
            }
        case .found(let tz):
            Label("Set to \(tz)", systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundColor(.green)
        case .notFound:
            VStack(alignment: .leading, spacing: 2) {
                Label("Location not found.", systemImage: "xmark.circle")
                    .font(.caption).foregroundColor(.orange)
                Text("Try: \"Paris, France\"  •  \"Boston, Massachusetts\"  •  \"Tokyo, Japan\"")
                    .font(.caption).foregroundColor(.secondary)
            }
        case .error(let msg):
            Label(msg, systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundColor(.red)
        }
    }

    private func findTimeZone() {
        let query = cityQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        geoStatus = .searching

        CLGeocoder().geocodeAddressString(query) { placemarks, error in
            DispatchQueue.main.async {
                isSearching = false
                if let tz = placemarks?.first?.timeZone {
                    entry.timeZoneIdentifier = tz.identifier
                    geoStatus = .found(tz.identifier)
                    if entry.label.isEmpty, let city = placemarks?.first?.locality {
                        entry.label = city
                    }
                } else if let e = error as? CLError, e.code == .geocodeFoundNoResult {
                    geoStatus = .notFound
                } else if let e = error {
                    geoStatus = .error(e.localizedDescription)
                } else {
                    geoStatus = .notFound
                }
            }
        }
    }

    private var previewTime: String {
        let fmt = DateFormatter()
        fmt.dateFormat = entry.formatString
        fmt.timeZone = entry.timeZone
        return fmt.string(from: Date())
    }
}
