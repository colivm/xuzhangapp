import CoreLocation
import Foundation

struct WeatherSnapshot: Equatable {
    var temp: Double?
    var weatherCode: Int?
    var ts: Date
}

@MainActor
final class WeatherCompanionService: NSObject, CLLocationManagerDelegate {
    static let shared = WeatherCompanionService()

    private let manager = CLLocationManager()
    private let cacheDuration: TimeInterval = 30 * 60
    private var cachedCoordinate: CLLocationCoordinate2D?
    private var cachedCoordinateAt: Date?
    private var cachedSnapshotValue: WeatherSnapshot?
    private var refreshTimer: Timer?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    var cachedSnapshot: WeatherSnapshot? {
        guard let snapshot = cachedSnapshotValue,
              Date().timeIntervalSince(snapshot.ts) < cacheDuration else {
            return nil
        }
        return snapshot
    }

    var hasLocationPermissionReady: Bool {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return cachedCoordinate != nil
        default:
            return false
        }
    }

    func requestWhenInUseAndRefresh() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            requestLocationIfNeeded(force: true)
            Task { _ = await fetchWeatherSnapshot() }
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func startBackgroundRefresh() {
        stopBackgroundRefresh()
        requestWhenInUseAndRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: cacheDuration, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.requestLocationIfNeeded(force: true)
                _ = await self?.fetchWeatherSnapshot()
            }
        }
    }

    func stopBackgroundRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refreshWeatherInBackground(refreshGeo: Bool = false) {
        requestLocationIfNeeded(force: refreshGeo)
        Task { _ = await fetchWeatherSnapshot() }
    }

    func fetchWeatherSnapshot() async -> WeatherSnapshot? {
        if let cachedSnapshot {
            return cachedSnapshot
        }
        guard let coordinate = cachedCoordinate else {
            requestLocationIfNeeded(force: false)
            return nil
        }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
        ]
        guard let url = components?.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let payload = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let snapshot = WeatherSnapshot(
                temp: payload.current.temperature2m,
                weatherCode: payload.current.weatherCode,
                ts: Date()
            )
            cachedSnapshotValue = snapshot
            return snapshot
        } catch {
            return nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            requestLocationIfNeeded(force: true)
            Task { _ = await fetchWeatherSnapshot() }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        cachedCoordinate = location.coordinate
        cachedCoordinateAt = Date()
        Task { _ = await fetchWeatherSnapshot() }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Weather companion is best-effort and must never block recording.
    }

    private func requestLocationIfNeeded(force: Bool) {
        guard CLLocationManager.locationServicesEnabled() else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            let coordinateFresh = cachedCoordinateAt.map { Date().timeIntervalSince($0) < cacheDuration } ?? false
            if force || cachedCoordinate == nil || !coordinateFresh {
                manager.requestLocation()
            }
        default:
            break
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        var temperature2m: Double?
        var weatherCode: Int?

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
        }
    }

    var current: Current
}
