import CoreLocation
import Combine
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
final class WeatherCompanionService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    static let shared = WeatherCompanionService()

    @Published private(set) var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var locationServicesAvailable = true

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let weatherService = WeatherService.shared
    private let cacheDuration: TimeInterval = 30 * 60
    private let homeCityKey = "weather_companion_home_city_v1"
    private var cachedCoordinate: CLLocationCoordinate2D?
    private var cachedCoordinateAt: Date?
    private var cachedSnapshotValue: WeatherSnapshot?
    private var cachedCitySemanticValue: CitySemanticSnapshot?
    private var citySemanticRequestID: UUID?
    private var accessRevision = 0
    private var pendingLocationRevision: Int?
    private var refreshTimer: Timer?
    // Cached getters are used during rendering; decode settings only at lifecycle
    // and explicit setting changes, not on every preview read.
    private var weatherFeatureEnabled = LocalStore.loadSettings().weatherCompanionEnabled

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        refreshLocationAuthorizationState()
    }

    var cachedSnapshot: WeatherSnapshot? {
        guard let snapshot = cachedSnapshotValue,
              weatherAccessAllowed,
              Date().timeIntervalSince(snapshot.ts) < cacheDuration else {
            return nil
        }
        return snapshot
    }

    var cachedCitySemanticSnapshot: CitySemanticSnapshot? {
        guard let snapshot = cachedCitySemanticValue,
              weatherAccessAllowed,
              Date().timeIntervalSince(snapshot.ts) < cacheDuration * 2 else {
            return nil
        }
        return snapshot
    }

    var hasLocationPermissionReady: Bool {
        cachedCoordinate != nil && weatherAccessAllowed
    }

    var locationAccessState: WeatherLocationAccessState {
        WeatherLocationAccessPolicy.accessState(
            locationServicesEnabled: locationServicesAvailable,
            authorizationStatus: locationAuthorizationStatus
        )
    }

    /// Refreshes the settings presentation without ever requesting permission.
    func refreshLocationAuthorizationState() {
        weatherFeatureEnabled = LocalStore.loadSettings().weatherCompanionEnabled
        let status = manager.authorizationStatus
        let servicesAvailable = CLLocationManager.locationServicesEnabled()
        if locationAuthorizationStatus != status || locationServicesAvailable != servicesAvailable {
            invalidateCachedContext()
        }
        locationAuthorizationStatus = status
        locationServicesAvailable = servicesAvailable
        if !weatherAccessAllowed { stopBackgroundRefresh() }
    }

    /// Only an explicit weather-enable or permission action may call this method.
    func requestWhenInUseAndRefresh() {
        refreshLocationAuthorizationState()
        guard weatherFeatureEnabled,
              locationServicesAvailable else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            startBackgroundRefresh()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func startBackgroundRefresh() {
        weatherFeatureEnabled = LocalStore.loadSettings().weatherCompanionEnabled
        refreshTimer?.invalidate()
        refreshTimer = nil
        guard weatherAccessAllowed else {
            invalidateCachedContext()
            return
        }
        refreshWeatherInBackground(refreshGeo: true)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: cacheDuration, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshWeatherInBackground(refreshGeo: true)
            }
        }
    }

    func stopBackgroundRefresh() {
        weatherFeatureEnabled = LocalStore.loadSettings().weatherCompanionEnabled
        refreshTimer?.invalidate()
        refreshTimer = nil
        invalidateCachedContext()
    }

    func refreshWeatherInBackground(refreshGeo: Bool = false, forceWeather: Bool = false) {
        guard weatherAccessAllowed else {
            stopBackgroundRefresh()
            return
        }
        requestLocationIfNeeded(force: refreshGeo)
        Task { _ = await fetchWeatherSnapshot(forceRefresh: forceWeather) }
    }

    func fetchWeatherSnapshot(forceRefresh: Bool = false) async -> WeatherSnapshot? {
        guard weatherAccessAllowed else { return nil }
        if !forceRefresh, let cachedSnapshot {
            return cachedSnapshot
        }
        guard let coordinate = cachedCoordinate else {
            requestLocationIfNeeded(force: false)
            return nil
        }

        let requestRevision = accessRevision
        do {
            let current = try await weatherService.weather(
                for: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                including: .current
            )
            guard canAcceptResult(for: requestRevision) else { return nil }
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
        refreshLocationAuthorizationState()
        guard weatherAccessAllowed else { return }
        startBackgroundRefresh()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard weatherAccessAllowed,
              pendingLocationRevision == accessRevision,
              let location = locations.last else { return }
        pendingLocationRevision = nil
        cachedCoordinate = location.coordinate
        cachedCoordinateAt = Date()
        refreshCitySemantic(for: location)
        Task { _ = await fetchWeatherSnapshot() }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        pendingLocationRevision = nil
        // Weather companion is best-effort and must never block recording.
    }

    private func requestLocationIfNeeded(force: Bool) {
        guard weatherAccessAllowed, pendingLocationRevision == nil else { return }
        let coordinateFresh = cachedCoordinateAt.map { Date().timeIntervalSince($0) < cacheDuration } ?? false
        if force || cachedCoordinate == nil || !coordinateFresh {
            pendingLocationRevision = accessRevision
            manager.requestLocation()
        }
    }

    private func refreshCitySemantic(for location: CLLocation) {
        guard weatherAccessAllowed, citySemanticRequestID == nil else { return }
        let requestID = UUID()
        let requestRevision = accessRevision
        citySemanticRequestID = requestID
        Task { @MainActor in
            defer {
                if citySemanticRequestID == requestID { citySemanticRequestID = nil }
            }
            guard canAcceptResult(for: requestRevision), citySemanticRequestID == requestID else { return }
            let placemarks = try? await geocoder.reverseGeocodeLocation(location)
            guard canAcceptResult(for: requestRevision),
                  citySemanticRequestID == requestID,
                  let placemark = placemarks?.first else { return }
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

    private var weatherAccessAllowed: Bool {
        WeatherLocationAccessPolicy.canUseWeather(
            weatherEnabled: weatherFeatureEnabled,
            locationServicesEnabled: locationServicesAvailable,
            authorizationStatus: manager.authorizationStatus
        )
    }

    private func canAcceptResult(for requestRevision: Int) -> Bool {
        WeatherLocationAccessPolicy.canAcceptResult(
            requestRevision: requestRevision,
            currentRevision: accessRevision,
            weatherEnabled: weatherFeatureEnabled,
            locationServicesEnabled: locationServicesAvailable,
            authorizationStatus: manager.authorizationStatus
        )
    }

    private func invalidateCachedContext() {
        accessRevision &+= 1
        pendingLocationRevision = nil
        citySemanticRequestID = nil
        manager.stopUpdatingLocation()
        geocoder.cancelGeocode()
        cachedCoordinate = nil
        cachedCoordinateAt = nil
        cachedSnapshotValue = nil
        cachedCitySemanticValue = nil
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

enum WeatherLocationAccessState: Equatable {
    case notRequested, allowed, denied, restricted, unavailable
}

enum WeatherLocationAccessPolicy {
    static func accessState(
        locationServicesEnabled: Bool,
        authorizationStatus: CLAuthorizationStatus
    ) -> WeatherLocationAccessState {
        guard locationServicesEnabled else { return .unavailable }
        switch authorizationStatus {
        case .notDetermined: return .notRequested
        case .authorizedAlways, .authorizedWhenInUse: return .allowed
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .restricted
        }
    }

    static func canUseWeather(
        weatherEnabled: Bool,
        locationServicesEnabled: Bool,
        authorizationStatus: CLAuthorizationStatus
    ) -> Bool {
        weatherEnabled && accessState(
            locationServicesEnabled: locationServicesEnabled,
            authorizationStatus: authorizationStatus
        ) == .allowed
    }

    static func canAcceptResult(
        requestRevision: Int,
        currentRevision: Int,
        weatherEnabled: Bool,
        locationServicesEnabled: Bool,
        authorizationStatus: CLAuthorizationStatus
    ) -> Bool {
        requestRevision == currentRevision && canUseWeather(
            weatherEnabled: weatherEnabled,
            locationServicesEnabled: locationServicesEnabled,
            authorizationStatus: authorizationStatus
        )
    }
}
