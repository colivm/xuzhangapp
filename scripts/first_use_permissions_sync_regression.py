#!/usr/bin/env python3
"""Source wiring guards; these do not execute Swift or simulate iOS permissions."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(name):
    return (ROOT / name).read_text(encoding="utf-8")


def section(source, start, end):
    return source.split(start, 1)[1].split(end, 1)[0]


weather = read("NativeDemoApp/Services/WeatherCompanionService.swift")
pet = read("NativeDemoApp/Services/PetCompanionService.swift")
settings = read("NativeDemoApp/Models/AppSettings.swift")
settings_vm = read("NativeDemoApp/ViewModels/SettingsViewModel.swift")
view = read("NativeDemoApp/Views/SettingsView.swift")
vm = read("NativeDemoApp/ViewModels/HomeViewModel.swift")
sync = read("NativeDemoApp/Services/LedgerSyncService.swift")

assert "weatherCompanionEnabled: false" in settings
assert "forKey: .weatherCompanionEnabled) ?? false" in settings
assert "requestWhenInUseAndRefresh" not in pet
automatic = section(weather, "func startBackgroundRefresh()", "func stopBackgroundRefresh()")
assert "requestWhenInUse" not in automatic
assert "guard weatherAccessAllowed" in automatic
request = section(weather, "func requestWhenInUseAndRefresh()", "func startBackgroundRefresh()")
assert "case .notDetermined:" in request and "manager.requestWhenInUseAuthorization()" in request
assert "guard weatherFeatureEnabled" in request
assert weather.count("manager.requestWhenInUseAuthorization()") == 1
for path in (ROOT / "NativeDemoApp").rglob("*.swift"):
    if "requestWhenInUseAndRefresh()" in path.read_text(encoding="utf-8"):
        assert path.name in {"WeatherCompanionService.swift", "SettingsViewModel.swift", "SettingsView.swift"}, path
assert "requestWhenInUse" not in section(settings_vm, "var petCompanionEnabled:", "var petNickname:")
assert "weatherService.refreshLocationAuthorizationState()" in view
assert "switch weatherService.locationAccessState" in view
assert "case .notRequested:" in view and "case .denied:" in view
for signature in ("var cachedSnapshot:", "var cachedCitySemanticSnapshot:",
                  "func refreshWeatherInBackground(", "func fetchWeatherSnapshot("):
    assert "weatherAccessAllowed" in weather.split(signature, 1)[1][:450], signature
assert "guard canAcceptResult(for: requestRevision)" in weather
assert "requestRevision == currentRevision" in weather
assert "cachedSnapshotValue = nil" in weather and "geocoder.cancelGeocode()" in weather
cached_getters = section(weather, "var cachedSnapshot:", "var locationAccessState:")
assert "LocalStore.loadSettings()" not in cached_getters

# Every operation requires fresh transport plus the server's success envelope.
assert "cachePolicy: .reloadIgnoringLocalCacheData" in sync
assert 'request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")' in sync
transport = section(sync, "private func data(for request:", "return (data, body)")
assert transport.index("urlSession.data(for: request)") < transport.index("(200..<300).contains")
assert "JSONDecoder().decode(LedgerAcknowledgement.self" in transport
assert "acknowledgement.ok else" in transport
assert "throw LedgerSyncError.invalidAcknowledgement" in transport

batch = section(vm, "func syncCloudLedgerNow()", "func restoreLocalBackup(")
assert "outcome.recordDeletionFailure(error)" in batch
assert "outcome.recordUploadFailure(error)" in batch
assert batch.index("outcome.recordUploadFailure(error)") < batch.index("syncStatusMessage = outcome.message")
assert "if !outcome.isComplete" in batch and "else if syncHasPendingFailures" in batch
assert "自动备份已完成" not in batch
assert "CloudSessionFailurePolicy.shouldInvalidateSession" in batch
assert batch.index("try await service.delete(id: intent.id") < batch.index("LocalStore.removeCloudLedgerDeletion")
for signature, end in (("private func syncUpsertToCloud(", "private func syncDeleteFromCloud("),
                       ("private func syncDeleteFromCloud(", "private func formatCurrency(")):
    single = section(vm, signature, end)
    assert "!isSyncingCloudLedger && !syncHasPendingFailures" in single
    assert "syncHasPendingFailures = true" in single
    assert "自动备份已完成" not in single
assert 'Button("重试备份")' in view
assert "UIApplication.openSettingsURLString" in view
assert "CloudNetworkFailureGuidance.message(for: error)" in settings_vm
print("first_use_permissions_sync_regression: OK (explicit weather permission, no implicit prompts, acknowledged requests, incomplete batch reporting, recovery actions; source checks only)")
