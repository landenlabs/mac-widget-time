import SwiftUI
import CoreLocation

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var selectedID: UUID?
    var onPositionChanged: (() -> Void)?

    var body: some View {
        HSplitView {
            entryList
                .frame(minWidth: 160, maxWidth: 200)
            detailPanel
                .frame(minWidth: 380)
        }
        .frame(minWidth: 580, minHeight: 460)
    }

    private var entryList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedID) {
                ForEach(appState.entries) { entry in
                    Text(entry.label.isEmpty ? "(unnamed)" : entry.label)
                        .tag(entry.id)
                }
                .onDelete { appState.removeEntries(at: $0) }
            }
            .listStyle(.sidebar)

            Divider()
            HStack(spacing: 4) {
                Button { appState.addEntry() } label: { Image(systemName: "plus") }
                    .buttonStyle(.plain)
                    .padding(6)
                if let id = selectedID, let idx = appState.entries.firstIndex(where: { $0.id == id }) {
                    Button {
                        appState.entries.remove(at: idx)
                        selectedID = nil
                    } label: { Image(systemName: "minus") }
                        .buttonStyle(.plain)
                        .padding(6)
                }
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }

    private var detailPanel: some View {
        Group {
            if let id = selectedID, let idx = appState.entries.firstIndex(where: { $0.id == id }) {
                EntryEditView(entry: $appState.entries[idx])
            } else {
                positionPanel
            }
        }
    }

    private var positionPanel: some View {
        Form {
            Section("Widget Position") {
                HStack {
                    Text("X")
                    TextField("X", value: $appState.widgetX, formatter: NumberFormatter())
                        .onChange(of: appState.widgetX) { _ in onPositionChanged?() }
                }
                HStack {
                    Text("Y")
                    TextField("Y", value: $appState.widgetY, formatter: NumberFormatter())
                        .onChange(of: appState.widgetY) { _ in onPositionChanged?() }
                }
                Text("(0, 0) = screen bottom-left. Decrease Y to move down.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Section("Appearance") {
                HStack {
                    Text("Text Color (hex)")
                    TextField("#RRGGBB", text: $appState.textColor)
                        .frame(width: 100)
                }
                Toggle("Text Shadow", isOn: $appState.shadowEnabled)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        case idle
        case searching
        case found(String)
        case notFound
        case error(String)
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

                // ── City lookup ──────────────────────────────────────────────
                LabeledContent("Find Time Zone") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            TextField("", text: $cityQuery, prompt: Text("Paris, France  •  Austin, Texas"))
                                .frame(maxWidth: 260)
                                .onSubmit { findTimeZone() }
                            Button(isSearching ? "Searching…" : "Find") { findTimeZone() }
                                .disabled(cityQuery.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                        }
                        geoStatusView
                    }
                }

                // ── Manual override ──────────────────────────────────────────
                LabeledContent("Time Zone") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Filter…", text: $tzSearch)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                        Picker("", selection: $entry.timeZoneIdentifier) {
                            ForEach(filteredTZs, id: \.self) { tz in
                                Text(tz).tag(tz)
                            }
                        }
                        .frame(maxWidth: 260, maxHeight: 110)
                        Text("Current: \(entry.timeZoneIdentifier)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // ── Format ───────────────────────────────────────────────────
                LabeledContent("Format") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("HH:mm", text: $entry.formatString)
                            .font(.system(.body, design: .monospaced))
                        Text("yyyy yy  MMM MM M  dd d  HH H  hh h  mm ss  a  EEE EEEE  zzz")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                .font(.caption)
                .foregroundColor(.secondary)
        case .searching:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.6)
                Text("Looking up…").font(.caption).foregroundColor(.secondary)
            }
        case .found(let tz):
            Label("Set to \(tz)", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
        case .notFound:
            VStack(alignment: .leading, spacing: 2) {
                Label("Location not found.", systemImage: "xmark.circle")
                    .font(.caption).foregroundColor(.orange)
                Text("Try: \"Paris, France\"  •  \"Boston, Massachusetts\"  •  \"Tokyo, Japan\"")
                    .font(.caption).foregroundColor(.secondary)
            }
        case .error(let msg):
            Label(msg, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundColor(.red)
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
                    // Pre-fill label if still empty
                    if entry.label.isEmpty, let city = placemarks?.first?.locality {
                        entry.label = city
                    }
                } else if let error = error as? CLError, error.code == .geocodeFoundNoResult {
                    geoStatus = .notFound
                } else if let error = error {
                    geoStatus = .error(error.localizedDescription)
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
