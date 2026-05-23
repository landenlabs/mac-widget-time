import Foundation
import CoreLocation

/// Fetches sunrise/sunset times for a (lat, lon, date) from api.sunrise-sunset.org.
/// Results are cached in memory and on disk; the same day/location combo only hits the network once.
final class SunTimesService: ObservableObject {
    static let shared = SunTimesService()

    struct SunTimes: Codable, Equatable {
        let sunrise: Date
        let sunset: Date
    }

    private struct CacheEntry: Codable {
        let key: String
        let times: SunTimes
    }

    @Published private(set) var cache: [String: SunTimes] = [:]

    private var inFlight: Set<String> = []
    private let session: URLSession = .shared

    private static var cacheFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent(Bundle.main.bundleIdentifier ?? "MacTimeWidget")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("sun_cache.json")
    }

    init() {
        if let data = try? Data(contentsOf: Self.cacheFileURL),
           let entries = try? JSONDecoder().decode([CacheEntry].self, from: data) {
            cache = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.times) })
        }
    }

    /// Returns cached times if present. If missing, kicks off a network request and the result
    /// arrives via `@Published cache`. `key` is `lat,lon,yyyy-MM-dd`.
    func times(latitude: Double, longitude: Double, on date: Date) -> SunTimes? {
        let key = Self.cacheKey(lat: latitude, lon: longitude, date: date)
        if let hit = cache[key] { return hit }
        fetch(latitude: latitude, longitude: longitude, date: date, key: key)
        return nil
    }

    /// Geocode a city label into coordinates, then resolve sun times.
    func times(label: String, on date: Date, completion: @escaping (SunTimes?) -> Void) {
        CLGeocoder().geocodeAddressString(label) { [weak self] placemarks, _ in
            guard let self,
                  let loc = placemarks?.first?.location else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let lat = loc.coordinate.latitude
            let lon = loc.coordinate.longitude
            if let cached = self.times(latitude: lat, longitude: lon, on: date) {
                DispatchQueue.main.async { completion(cached) }
            } else {
                // Network result will land in `cache` and trigger Combine re-renders;
                // for one-shot callers, poll the cache shortly after.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    let key = Self.cacheKey(lat: lat, lon: lon, date: date)
                    completion(self.cache[key])
                }
            }
        }
    }

    private func fetch(latitude: Double, longitude: Double, date: Date, key: String) {
        guard !inFlight.contains(key) else { return }
        inFlight.insert(key)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")
        let dateStr = df.string(from: date)

        var components = URLComponents(string: "https://api.sunrise-sunset.org/json")!
        components.queryItems = [
            URLQueryItem(name: "lat",       value: String(latitude)),
            URLQueryItem(name: "lng",       value: String(longitude)),
            URLQueryItem(name: "date",      value: dateStr),
            URLQueryItem(name: "formatted", value: "0"),
        ]
        guard let url = components.url else { inFlight.remove(key); return }

        let task = session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self else { return }
            defer { DispatchQueue.main.async { self.inFlight.remove(key) } }
            guard let data,
                  let parsed = Self.parse(data) else { return }
            DispatchQueue.main.async {
                self.cache[key] = parsed
                self.persist()
            }
        }
        task.resume()
    }

    private static func parse(_ data: Data) -> SunTimes? {
        struct Response: Decodable {
            struct Results: Decodable { let sunrise: String; let sunset: String }
            let results: Results
            let status: String
        }
        guard let resp = try? JSONDecoder().decode(Response.self, from: data),
              resp.status == "OK" else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sunrise = iso.date(from: resp.results.sunrise)
            ?? ISO8601DateFormatter().date(from: resp.results.sunrise)
        let sunset = iso.date(from: resp.results.sunset)
            ?? ISO8601DateFormatter().date(from: resp.results.sunset)
        guard let sunrise, let sunset else { return nil }
        return SunTimes(sunrise: sunrise, sunset: sunset)
    }

    private func persist() {
        // Drop entries older than ~3 days so the file doesn't grow unbounded.
        let cutoff = Calendar(identifier: .gregorian).date(byAdding: .day, value: -3, to: Date()) ?? Date()
        let cutoffStr: String = {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.timeZone = TimeZone(identifier: "UTC")
            return df.string(from: cutoff)
        }()
        let trimmed = cache.filter { key, _ in
            // key format: "lat,lon,yyyy-MM-dd"
            guard let datePart = key.split(separator: ",").last else { return true }
            return String(datePart) >= cutoffStr
        }
        let entries = trimmed.map { CacheEntry(key: $0.key, times: $0.value) }
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: Self.cacheFileURL, options: .atomic)
        }
    }

    private static func cacheKey(lat: Double, lon: Double, date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")
        return String(format: "%.3f,%.3f,\(df.string(from: date))", lat, lon)
    }
}
