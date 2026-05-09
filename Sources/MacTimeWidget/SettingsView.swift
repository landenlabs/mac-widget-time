import SwiftUI
import CoreLocation

// MARK: - Navigation

private enum Nav: Hashable {
    case about
    case widgetGeneral(UUID)
    case entry(UUID)
}

// MARK: - SettingsView

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var nav: Nav
    var onPositionChanged: (() -> Void)?

    init(appState: AppState, onPositionChanged: (() -> Void)? = nil) {
        self.appState = appState
        self.onPositionChanged = onPositionChanged
        _nav = State(initialValue: appState.widgets.first.map { .widgetGeneral($0.id) } ?? .about)
    }

    var body: some View {
        HSplitView {
            sidebar.frame(minWidth: 190, maxWidth: 230)
            detail.frame(minWidth: 480)
        }
        .frame(minWidth: 700, minHeight: 520)
        .onChange(of: appState.widgets) { widgets in
            switch nav {
            case .widgetGeneral(let id):
                if !widgets.contains(where: { $0.id == id }) {
                    nav = widgets.first.map { .widgetGeneral($0.id) } ?? .about
                }
            case .entry(let id):
                if !widgets.flatMap(\.entries).contains(where: { $0.id == id }) {
                    nav = widgets.first.map { .widgetGeneral($0.id) } ?? .about
                }
            case .about:
                break
            }
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $nav) {
                Label("About", systemImage: "info.circle").tag(Nav.about)

                ForEach(appState.widgets) { widget in
                    Section(widget.name) {
                        Label("Settings", systemImage: "slider.horizontal.3")
                            .tag(Nav.widgetGeneral(widget.id))
                        ForEach(widget.entries) { entry in
                            Label {
                                Text(entry.label.isEmpty ? "(unnamed)" : entry.label)
                            } icon: {
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
                        .onDelete { appState.removeEntries(from: widget.id, at: $0) }
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(maxHeight: .infinity)

            Divider()
            HStack(spacing: 0) {
                Button { addClock() } label: {
                    Image(systemName: "plus").frame(width: 26, height: 22)
                }
                .buttonStyle(.borderless)
                .help("Add clock to this widget")

                if canRemoveFocused {
                    Divider().frame(height: 16)
                    Button { removeFocused() } label: {
                        Image(systemName: "minus").frame(width: 26, height: 22)
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Divider().frame(height: 16)
                Button {
                    let w = appState.addWidget()
                    nav = .widgetGeneral(w.id)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                        Text("Widget").font(.system(size: 11))
                    }
                    .frame(height: 22)
                    .padding(.horizontal, 6)
                }
                .buttonStyle(.borderless)
                .help("Add new widget")
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
        case .about:
            AboutView()
        case .widgetGeneral(let id):
            if let idx = appState.widgets.firstIndex(where: { $0.id == id }) {
                WidgetGeneralView(
                    appState: appState,
                    widget: $appState.widgets[idx],
                    onPositionChanged: onPositionChanged
                )
                .id(id)
            }
        case .entry(let id):
            if let (wi, ei) = findEntry(id: id) {
                EntryEditView(entry: $appState.widgets[wi].entries[ei])
                    .id(id)
            }
        }
    }

    // MARK: Helpers

    private var canRemoveFocused: Bool {
        switch nav {
        case .widgetGeneral(let id):
            return appState.widgets.count > 1 && appState.widgets.contains(where: { $0.id == id })
        case .entry(let id):
            return appState.widgets.flatMap(\.entries).contains(where: { $0.id == id })
        case .about:
            return false
        }
    }

    private func addClock() {
        let widgetID: UUID
        switch nav {
        case .widgetGeneral(let id):
            widgetID = id
        case .entry(let entryID):
            widgetID = appState.widgets.first(where: { $0.entries.contains(where: { $0.id == entryID }) })?.id
                ?? appState.widgets[0].id
        case .about:
            widgetID = appState.widgets[0].id
        }
        if let entry = appState.addEntry(to: widgetID) {
            nav = .entry(entry.id)
        }
    }

    private func removeFocused() {
        switch nav {
        case .widgetGeneral(let id):
            guard appState.widgets.count > 1 else { return }
            appState.removeWidget(id: id)
        case .entry(let entryID):
            guard let widget = appState.widgets.first(where: { $0.entries.contains(where: { $0.id == entryID }) }),
                  let ei = widget.entries.firstIndex(where: { $0.id == entryID }) else { return }
            appState.removeEntries(from: widget.id, at: IndexSet([ei]))
            nav = .widgetGeneral(widget.id)
        case .about:
            break
        }
    }

    private func findEntry(id: UUID) -> (Int, Int)? {
        for (wi, widget) in appState.widgets.enumerated() {
            if let ei = widget.entries.firstIndex(where: { $0.id == id }) {
                return (wi, ei)
            }
        }
        return nil
    }
}

// MARK: - Widget General Panel

struct WidgetGeneralView: View {
    @ObservedObject var appState: AppState
    @Binding var widget: WidgetConfig
    var onPositionChanged: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Widget").font(.headline)

                Form {
                    LabeledContent("Name") {
                        TextField("Widget name", text: $widget.name)
                            .frame(maxWidth: 200)
                    }
                    LabeledContent("Orientation") {
                        Picker("", selection: $widget.orientation) {
                            ForEach(WidgetOrientation.allCases, id: \.self) { o in
                                Text(o.label).tag(o)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .horizontalRadioGroupLayout()
                        .labelsHidden()
                    }
                }

                Divider()

                Text("Position").font(.headline)

                ScreenMapView(
                    widgetX: posXBinding,
                    widgetY: posYBinding,
                    widgetSize: appState.widgetSizes[widget.id] ?? CGSize(width: 200, height: 80)
                ) { onPositionChanged?() }

                HStack(spacing: 20) {
                    coordField(label: "X:", value: posXBinding)
                    coordField(label: "Y:", value: posYBinding)
                }

                Text("(0, 0) = screen bottom-left. Drag the blue block above to reposition.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var posXBinding: Binding<Double> {
        Binding(
            get: { widget.positionX },
            set: { newX in
                widget.widgetX = newX
                widget.screenPositions[ScreenFingerprint.current] = ScreenPosition(x: newX, y: widget.positionY)
            }
        )
    }

    private var posYBinding: Binding<Double> {
        Binding(
            get: { widget.positionY },
            set: { newY in
                widget.widgetY = newY
                widget.screenPositions[ScreenFingerprint.current] = ScreenPosition(x: widget.positionX, y: newY)
            }
        )
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

// MARK: - Animated GIF view (plays once, stops on last frame)

struct AnimatedGIFView: NSViewRepresentable {
    let url: URL?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSImageView {
        let v = NSImageView()
        v.imageScaling = .scaleProportionallyDown
        v.animates = false
        if let url { context.coordinator.load(url: url, into: v) }
        return v
    }

    func updateNSView(_ v: NSImageView, context: Context) {}

    class Coordinator {
        private var timer: Timer?
        private var frames: [(image: NSImage, duration: TimeInterval)] = []
        private var frameIndex = 0
        private weak var imageView: NSImageView?

        func load(url: URL, into imageView: NSImageView) {
            self.imageView = imageView
            guard let data = try? Data(contentsOf: url) else { return }

            // Pre-extract every frame as an independent NSImage via CGImage so each
            // is a true snapshot — mutating NSBitmapImageRep.currentFrame in-place
            // doesn't reliably refresh an NSImageView without this copy step.
            guard let source = NSImage(data: data),
                  let rep = source.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
                  let frameCount = rep.value(forProperty: .frameCount) as? Int,
                  frameCount > 1
            else {
                imageView.image = NSImage(data: data)
                return
            }

            frames = (0..<frameCount).compactMap { i in
                rep.setProperty(.currentFrame, withValue: NSNumber(value: i))
                let duration = (rep.value(forProperty: .currentFrameDuration) as? TimeInterval) ?? 0.1
                guard let cg = rep.cgImage else { return nil }
                return (NSImage(cgImage: cg, size: rep.size), duration)
            }

            frameIndex = 0
            show(frameIndex)
            scheduleNext()
        }

        private func show(_ index: Int) {
            imageView?.image = frames[index].image
        }

        private func scheduleNext() {
            let delay = frames[frameIndex].duration
            timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                guard let self else { return }
                let next = self.frameIndex + 1
                guard next < self.frames.count else { return }  // stop — stay on last frame
                self.frameIndex = next
                self.show(next)
                self.scheduleNext()
            }
        }

        deinit { timer?.invalidate() }
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                if let gifURL = Bundle.module.url(forResource: "landen_labs_about", withExtension: "gif") {
                    AnimatedGIFView(url: gifURL)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                }

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
                    Text("A lightweight desktop clock widget that shows multiple time zones directly on your desktop. Supports multiple independent widgets, each with its own clocks, colors, orientation, and per-screen position.")
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

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Created by LanDen Labs (2026)")
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text("GitHub:")
                            .foregroundColor(.secondary)
                        Link("https://github.com/landenlabs/mac-widget-time",
                             destination: URL(string: "https://github.com/landenlabs/mac-widget-time")!)
                        .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? AppVersion
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

                LabeledContent("Alignment") {
                    Picker("", selection: $entry.rowAlignment) {
                        ForEach(RowAlignment.allCases, id: \.self) { alignment in
                            Text(alignment.label).tag(alignment)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .horizontalRadioGroupLayout()
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
