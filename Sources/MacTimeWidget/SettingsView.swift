import SwiftUI
import CoreLocation

// MARK: - Navigation

private enum Nav: Hashable {
    case general
    case about
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
        .onChange(of: appState.entries) { entries in
            if case .entry(let id) = nav, !entries.contains(where: { $0.id == id }) {
                nav = .general
            }
        }
    }

    // MARK: Sidebar
    // VStack instead of safeAreaInset so the button bar is outside the List's
    // hit-test area — prevents the List from swallowing button clicks.

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $nav) {
                Section("Widget") {
                    Label("Position", systemImage: "slider.horizontal.3")
                        .tag(Nav.general)
                    Label("About", systemImage: "info.circle")
                        .tag(Nav.about)
                }
                Section("Clocks") {
                    ForEach(appState.entries) { entry in
                        Label {
                            Text(entry.label.isEmpty ? "(unnamed)" : entry.label)
                        } icon: {
                            // Clock icon with a small colour dot in the corner.
                            Image(systemName: "clock")
                                .overlay(alignment: .bottomTrailing) {
                                    Circle()
                                        .fill(Color(hex: entry.textColor) ?? .white)
                                        .frame(width: 7, height: 7)
                                        .shadow(color: .black.opacity(0.4), radius: 1)
                                }
                        }
                        .tag(Nav.entry(entry.id))
                    }
                    .onDelete { appState.removeEntries(at: $0) }
                }
            }
            .listStyle(.sidebar)
            .frame(maxHeight: .infinity)

            Divider()
            HStack(spacing: 0) {
                Button {
                    let e = appState.addEntry()
                    nav = .entry(e.id)
                } label: {
                    Image(systemName: "plus").frame(width: 26, height: 22)
                }
                .buttonStyle(.borderless)

                if case .entry(let id) = nav {
                    Divider().frame(height: 16)
                    Button {
                        appState.entries = appState.entries.filter { $0.id != id }
                        nav = .general
                    } label: {
                        Image(systemName: "minus").frame(width: 26, height: 22)
                    }
                    .buttonStyle(.borderless)
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
            positionPanel
        case .about:
            AboutView()
        case .entry(let id):
            if let idx = appState.entries.firstIndex(where: { $0.id == id }) {
                EntryEditView(entry: $appState.entries[idx])
                    .id(id)
            } else {
                positionPanel
            }
        }
    }

    // MARK: Position panel

    private var positionPanel: some View {
        ScrollView {
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
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mac Time Widget")
                            .font(.title.bold())
                        Text("Version \(appVersion)")
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Description").font(.headline)
                    Text("A lightweight desktop clock widget that shows multiple time zones directly on your desktop. Each clock entry has its own label, format, font size, colour, and shadow.")
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Details").font(.headline)
                    infoRow("Author",    "Dennis Lang")
                    infoRow("Built",     buildDate)
                    infoRow("Settings",  settingsPath)
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting(
                            [URL(fileURLWithPath: settingsPath)]
                        )
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        if let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String { return "\(v) (\(b))" }
        return v
    }

    private var buildDate: String {
        guard let url = Bundle.main.executableURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attrs[.modificationDate] as? Date else { return "—" }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }

    private var settingsPath: String {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent(Bundle.main.bundleIdentifier ?? "MacTimeWidget")
        return dir.appendingPathComponent("settings.json").path
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label).foregroundColor(.secondary).frame(width: 72, alignment: .leading)
            Text(value).textSelection(.enabled)
        }
    }
}

// MARK: - Screen mini-map

struct ScreenMapView: View {
    @Binding var widgetX: Double
    @Binding var widgetY: Double
    var widgetSize: CGSize
    var onChanged: () -> Void

    private let mapSize = CGSize(width: 360, height: 202)

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
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))

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

                // Custom scroll list instead of Picker — avoids the parent Form
                // scrolling to the selected row on appear, which caused blank-space jumps.
                LabeledContent("Time Zone") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Filter…", text: $tzSearch)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    ForEach(filteredTZs, id: \.self) { tz in
                                        Text(tz)
                                            .font(.system(size: 12))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                tz == entry.timeZoneIdentifier
                                                    ? Color.accentColor.opacity(0.2) : Color.clear
                                            )
                                            .contentShape(Rectangle())
                                            .onTapGesture { entry.timeZoneIdentifier = tz }
                                            .id(tz)
                                    }
                                }
                            }
                            .frame(maxWidth: 260, maxHeight: 110)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                            .onAppear {
                                proxy.scrollTo(entry.timeZoneIdentifier, anchor: .center)
                            }
                            .onChange(of: entry.timeZoneIdentifier) { id in
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
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

                LabeledContent("Text Color") {
                    HStack(spacing: 10) {
                        TextField("#FFFFFF", text: $entry.textColor)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .font(.system(.body, design: .monospaced))
                        ColorPicker("", selection: colorPickerBinding, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 32, height: 26)
                    }
                }

                LabeledContent("Text Shadow") {
                    Toggle("", isOn: $entry.shadowEnabled)
                        .labelsHidden()
                }

                LabeledContent("Preview") {
                    Text(previewTime)
                        .font(.system(size: min(entry.fontSize, 28), weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: entry.textColor) ?? .white)
                        .shadow(color: entry.shadowEnabled ? .black.opacity(0.9) : .clear, radius: 3, x: 1, y: 1)
                        .padding(8)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(6)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private var colorPickerBinding: Binding<Color> {
        Binding(
            get: { Color(hex: entry.textColor) ?? .white },
            set: { color in
                guard let ns = NSColor(color).usingColorSpace(.sRGB) else { return }
                entry.textColor = String(
                    format: "#%02X%02X%02X",
                    Int((ns.redComponent   * 255).rounded()),
                    Int((ns.greenComponent * 255).rounded()),
                    Int((ns.blueComponent  * 255).rounded())
                )
            }
        )
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
