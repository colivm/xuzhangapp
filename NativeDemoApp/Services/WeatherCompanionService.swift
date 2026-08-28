import CoreLocation
import Foundation
import WeatherKit

struct WeatherSnapshot: Equatable {
    var temp: Double?
    var weatherCode: Int?
    var ts: Date
}

struct CitySemanticSnapshot: Equatable {
    var cityName: String?
    var semanticPlace: String?
    var ts: Date
}

@MainActor
final class WeatherCompanionService: NSObject, @preconcurrency CLLocationManagerDelegate {
    static let shared = WeatherCompanionService()

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let weatherService = WeatherService.shared
    private let cacheDuration: TimeInterval = 30 * 60
    private let homeCityKey = "weather_companion_home_city_v1"
    private var cachedCoordinate: CLLocationCoordinate2D?
    private var cachedCoordinateAt: Date?
    private var cachedSnapshotValue: WeatherSnapshot?
    private var cachedCitySemanticValue: CitySemanticSnapshot?
    private var isRefreshingCitySemantic = false
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

    var cachedCitySemanticSnapshot: CitySemanticSnapshot? {
        guard let snapshot = cachedCitySemanticValue,
              Date().timeIntervalSince(snapshot.ts) < cacheDuration * 2 else {
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

    func refreshWeatherInBackground(refreshGeo: Bool = false, forceWeather: Bool = false) {
        requestLocationIfNeeded(force: refreshGeo)
        Task { _ = await fetchWeatherSnapshot(forceRefresh: forceWeather) }
    }

    func fetchWeatherSnapshot(forceRefresh: Bool = false) async -> WeatherSnapshot? {
        if !forceRefresh, let cachedSnapshot {
            return cachedSnapshot
        }
        guard let coordinate = cachedCoordinate else {
            requestLocationIfNeeded(force: false)
            return nil
        }

        do {
            let current = try await weatherService.weather(
                for: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                including: .current
            )
            let snapshot = WeatherSnapshot(
                temp: current.temperature.converted(to: .celsius).value,
                weatherCode: Self.legacyWeatherCode(for: current.condition),
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
        refreshCitySemantic(for: location)
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

    private func refreshCitySemantic(for location: CLLocation) {
        guard !isRefreshingCitySemantic else { return }
        isRefreshingCitySemantic = true
        Task { @MainActor in
            defer { isRefreshingCitySemantic = false }
            let placemarks = try? await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks?.first else { return }
            let city = [
                placemark.locality,
                placemark.subAdministrativeArea,
                placemark.administrativeArea
            ]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
            let normalizedCity = city.map(Self.normalizedCityName)
            let storedHomeCity = UserDefaults.standard.string(forKey: homeCityKey).map(Self.normalizedCityName)
            let semanticPlace: String?
            if let normalizedCity {
                if let storedHomeCity, !storedHomeCity.isEmpty {
                    semanticPlace = storedHomeCity == normalizedCity ? "本城" : "外地"
                } else {
                    UserDefaults.standard.set(normalizedCity, forKey: homeCityKey)
                    semanticPlace = "本城"
                }
            } else {
                semanticPlace = nil
            }
            cachedCitySemanticValue = CitySemanticSnapshot(
                cityName: normalizedCity,
                semanticPlace: semanticPlace,
                ts: Date()
            )
        }
    }

    private static func normalizedCityName(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "市", with: "")
            .replacingOccurrences(of: "地区", with: "")
            .replacingOccurrences(of: "自治州", with: "")
    }

    /// Keeps the existing downstream rain/snow grouping stable while WeatherKit
    /// becomes the source of truth. Temperature still determines hot/cold.
    static func legacyWeatherCode(for condition: WeatherCondition) -> Int? {
        switch condition {
        case .drizzle, .freezingDrizzle, .freezingRain, .heavyRain, .rain, .sunShowers:
            return 61
        case .blizzard, .blowingSnow, .flurries, .heavySnow, .sleet, .snow, .sunFlurries, .wintryMix:
            return 71
        default:
            return nil
        }
    }
}
