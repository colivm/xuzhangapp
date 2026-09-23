import Foundation
import CoreLocation
import Observation
import XCTest
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WeatherKit)
import WeatherKit
#endif
@testable import NativeDemoApp

/// Each fixture owns a distinct host and a locked response queue. Tests never use live networking.
private final class LedgerSyncTestURLProtocol: URLProtocol {
    enum Response {
        case http(Int, String)
        case failure(URLError.Code)
    }

    private final class Registry: @unchecked Sendable {
        private struct Entry {
            var responses: [Response]
            var requests: [URLRequest] = []
        }

        private let lock = NSLock()
        private var entries: [String: Entry] = [:]

        func register(host: String, responses: [Response]) {
            lock.lock()
            defer { lock.unlock() }
            entries[host] = Entry(responses: responses)
        }

        func consume(_ request: URLRequest) -> Response {
            lock.lock()
            defer { lock.unlock() }
            guard let host = request.url?.host, var entry = entries[host] else {
                return .failure(.unsupportedURL)
            }
            entry.requests.append(request)
            let response: Response = entry.responses.isEmpty
                ? .failure(.badServerResponse) : entry.responses.removeFirst()
            entries[host] = entry
            return response
        }

        func requests(host: String) -> [URLRequest] {
            lock.lock()
            defer { lock.unlock() }
            return entries[host]?.requests ?? []
        }

        func remove(host: String) {
            lock.lock()
            defer { lock.unlock() }
            entries.removeValue(forKey: host)
        }
    }

    private static let registry = Registry()

    static func register(host: String, responses: [Response]) {
        registry.register(host: host, responses: responses)
    }

    static func requests(host: String) -> [URLRequest] { registry.requests(host: host) }
    static func remove(host: String) { registry.remove(host: host) }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        switch Self.registry.consume(request) {
        case let .failure(code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case let .http(status, body):
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url, statusCode: status, httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                  ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

private final class LedgerSyncTransportFixture {
    let host: String
    let cache: URLCache
    let session: URLSession
    let service: LedgerSyncService

    var baseURL: String { "https://" + host }
    var requests: [URLRequest] { LedgerSyncTestURLProtocol.requests(host: host) }

    init(_ responses: [LedgerSyncTestURLProtocol.Response]) {
        let host = UUID().uuidString.lowercased() + "-ledger-sync-test.invalid"
        let cache = URLCache(memoryCapacity: 1_048_576, diskCapacity: 0, diskPath: nil)
        self.host = host
        self.cache = cache
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LedgerSyncTestURLProtocol.self]
        configuration.urlCache = cache
        configuration.requestCachePolicy = .useProtocolCachePolicy
        let session = URLSession(configuration: configuration)
        self.session = session
        service = LedgerSyncService(baseURL: "https://" + host, accessToken: "test-token", urlSession: session)
        LedgerSyncTestURLProtocol.register(host: host, responses: responses)
    }

    func close() {
        session.invalidateAndCancel()
        cache.removeAllCachedResponses()
        LedgerSyncTestURLProtocol.remove(host: host)
    }
}

final class LedgerSyncPermissionRegressionTests: XCTestCase {
    private let item = HomeItem(title: "本机夜宵", amount: 32, category: .dining)
    private let emptySnapshot = #"{"ok":true,"items":[],"tombstones":[]}"#

    func testFreshAcknowledgedFetchUploadAndDeletionSucceedWithoutCache() async throws {
        let fixture = LedgerSyncTransportFixture([
            .http(200, emptySnapshot), .http(201, #"{"ok":true}"#), .http(200, #"{"ok":true}"#)
        ])
        defer { fixture.close() }
        let snapshot = try await fixture.service.fetchSnapshot()
        XCTAssertTrue(snapshot.items.isEmpty)
        XCTAssertTrue(snapshot.tombstones.isEmpty)
        try await fixture.service.upload(item)
        try await fixture.service.delete(id: item.id)
        let requests = fixture.requests
        XCTAssertEqual(requests.map(\.httpMethod), ["GET", "POST", "DELETE"])
        XCTAssertEqual(requests.map { $0.url?.path }, ["/v1/ledger", "/v1/ledger", "/v1/ledger/\(item.id.uuidString)"])
        for request in requests {
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            XCTAssertEqual(request.timeoutInterval, 30)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-cache")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        }
    }

    func testOfflineFetchCannotUsePreviouslyCachedSuccess() async throws {
        let fixture = LedgerSyncTransportFixture([.failure(.notConnectedToInternet)])
        defer { fixture.close() }
        let url = try XCTUnwrap(URL(string: fixture.baseURL + "/v1/ledger"))
        var cachedRequest = URLRequest(url: url)
        cachedRequest.setValue("Bearer test-token", forHTTPHeaderField: "Authorization")
        cachedRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let response = try XCTUnwrap(HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json", "Cache-Control": "max-age=3600"]
        ))
        fixture.cache.storeCachedResponse(
            CachedURLResponse(response: response, data: Data(emptySnapshot.utf8)), for: cachedRequest
        )
        XCTAssertNotNil(fixture.cache.cachedResponse(for: cachedRequest))
        do {
            _ = try await fixture.service.fetchSnapshot()
            XCTFail("A cached acknowledgement must not prove that an offline attempt succeeded")
        } catch {
            XCTAssertEqual((error as NSError).domain, NSURLErrorDomain)
            XCTAssertEqual((error as NSError).code, URLError.notConnectedToInternet.rawValue)
        }
        XCTAssertEqual(fixture.requests.count, 1)
        XCTAssertEqual(fixture.requests.first?.cachePolicy, .reloadIgnoringLocalCacheData)
    }

    func testCellularDataDeniedAndLostConnectionPropagateForMutations() async {
        let fixture = LedgerSyncTransportFixture([.failure(.dataNotAllowed), .failure(.networkConnectionLost)])
        defer { fixture.close() }
        do {
            try await fixture.service.upload(item)
            XCTFail("A denied upload must remain pending")
        } catch {
            XCTAssertEqual((error as NSError).domain, NSURLErrorDomain)
            XCTAssertEqual((error as NSError).code, URLError.dataNotAllowed.rawValue)
        }
        do {
            try await fixture.service.delete(id: item.id)
            XCTFail("An unacknowledged deletion must remain pending")
        } catch {
            XCTAssertEqual((error as NSError).domain, NSURLErrorDomain)
            XCTAssertEqual((error as NSError).code, URLError.networkConnectionLost.rawValue)
        }
        XCTAssertEqual(fixture.requests.count, 2)
    }

    func testFalseAcknowledgementRejectsFetchUploadAndDeletion() async {
        await assertInvalidAcknowledgement(body: #"{"ok":false,"items":[],"tombstones":[]}"#)
    }

    func testMalformedOrMissingAcknowledgementRejectsEveryOperation() async {
        for body in ["", "not JSON", "{}", #"{"ok":"true"}"#] {
            await assertInvalidAcknowledgement(body: body)
        }
        await assertInvalidAcknowledgement(body: "", status: 204)
    }

    func testAcknowledgedButMalformedSnapshotCannotBecomeEmptySuccess() async {
        let fixture = LedgerSyncTransportFixture([.http(200, #"{"ok":true}"#)])
        defer { fixture.close() }
        do {
            _ = try await fixture.service.fetchSnapshot()
            XCTFail("Missing records are not an acknowledged empty snapshot")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testUnauthorizedResponsePreservesStatusForLoginHandling() async {
        let body = #"{"error":"token_expired"}"#
        let fixture = LedgerSyncTransportFixture(Array(repeating: .http(401, body), count: 3))
        defer { fixture.close() }
        for operation in 0..<3 {
            do {
                try await perform(operation, service: fixture.service)
                XCTFail("HTTP 401 must not report success")
            } catch LedgerSyncError.badStatus(let status, let receivedBody) {
                XCTAssertEqual(status, 401)
                XCTAssertEqual(receivedBody, body)
            } catch {
                XCTFail("Unauthorized status was lost: \(error)")
            }
        }
    }

    func testMixedBatchFailuresRemainVisibleAndFreshSuccessfulRetryClearsOutcome() async {
        let fixture = LedgerSyncTransportFixture([
            .http(200, #"{"ok":true}"#), .failure(.dataNotAllowed),
            .http(200, #"{"ok":false}"#), .http(200, #"{"ok":true}"#),
            .http(200, #"{"ok":true}"#), .http(200, #"{"ok":true}"#),
            .http(200, #"{"ok":true}"#), .http(200, #"{"ok":true}"#)
        ])
        defer { fixture.close() }
        var attempt = LedgerSyncAttemptOutcome()
        for _ in 0..<2 {
            do { try await fixture.service.upload(item) }
            catch { attempt.recordUploadFailure(error) }
        }
        for _ in 0..<2 {
            do { try await fixture.service.delete(id: item.id) }
            catch { attempt.recordDeletionFailure(error) }
        }
        XCTAssertFalse(attempt.isComplete)
        XCTAssertEqual(attempt.failedUploads, 1)
        XCTAssertEqual(attempt.failedDeletions, 1)
        XCTAssertTrue(attempt.needsNetworkHelp)
        XCTAssertTrue(attempt.message.contains("尚未完成"))
        XCTAssertTrue(attempt.message.contains("本机记录已保留"))

        var retry = LedgerSyncAttemptOutcome()
        for _ in 0..<2 {
            do { try await fixture.service.upload(item) }
            catch { retry.recordUploadFailure(error) }
        }
        for _ in 0..<2 {
            do { try await fixture.service.delete(id: item.id) }
            catch { retry.recordDeletionFailure(error) }
        }
        XCTAssertTrue(retry.isComplete)
        XCTAssertEqual(retry.failedUploads, 0)
        XCTAssertEqual(retry.failedDeletions, 0)
        XCTAssertFalse(retry.needsNetworkHelp)
        XCTAssertTrue(retry.message.contains("已完成"))
        XCTAssertEqual(fixture.requests.count, 8)
    }

    func testNetworkGuidanceIsConditionalAndCoversCellularFailure() throws {
        let codes: [URLError.Code] = [
            .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff,
            .networkConnectionLost, .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed
        ]
        for code in codes {
            let message = try XCTUnwrap(CloudNetworkFailureGuidance.message(for: URLError(code)))
            XCTAssertTrue(message.contains("请检查网络"))
            XCTAssertTrue(message.contains("若已禁止"), "An error alone cannot establish denied permission")
            XCTAssertTrue(message.contains("无线局域网与蜂窝网络"))
        }
    }

    func testCancellationAndNonNetworkFailuresDoNotAccuseNetworkPermission() {
        let errors: [Error] = [
            URLError(.cancelled), URLError(.badURL), CancellationError(),
            LedgerSyncError.invalidAcknowledgement, LedgerSyncError.badStatus(401, "expired"),
            NSError(domain: "ServerValidation", code: URLError.dataNotAllowed.rawValue)
        ]
        for error in errors {
            XCTAssertNil(CloudNetworkFailureGuidance.message(for: error))
        }
        var attempt = LedgerSyncAttemptOutcome()
        attempt.recordUploadFailure(LedgerSyncError.invalidAcknowledgement)
        attempt.recordDeletionFailure(LedgerSyncError.badStatus(503, "unavailable"))
        XCTAssertFalse(attempt.isComplete)
        XCTAssertFalse(attempt.needsNetworkHelp)
        XCTAssertFalse(attempt.message.contains("联网权限"))
    }

    private func perform(_ operation: Int, service: LedgerSyncService) async throws {
        switch operation {
        case 0: _ = try await service.fetchSnapshot()
        case 1: try await service.upload(item)
        default: try await service.delete(id: item.id)
        }
    }

    private func assertInvalidAcknowledgement(body: String, status: Int = 200) async {
        let fixture = LedgerSyncTransportFixture(Array(repeating: .http(status, body), count: 3))
        defer { fixture.close() }
        for operation in 0..<3 {
            do {
                try await perform(operation, service: fixture.service)
                XCTFail("An unacknowledged response must not report success: \(body)")
            } catch LedgerSyncError.invalidAcknowledgement {
                // Expected for all operations, including otherwise successful HTTP statuses.
            } catch {
                XCTFail("Unexpected acknowledgement error: \(error)")
            }
        }
        XCTAssertEqual(fixture.requests.count, 3)
    }
}

final class WeatherPermissionRegressionTests: XCTestCase {
    func testNewSettingsDoNotEnableOptionalWeatherLocation() {
        XCTAssertFalse(AppSettings.default.weatherCompanionEnabled)
    }

    func testOldSettingsWithoutWeatherKeyDoNotOptInToLocation() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"displayName":"旧用户"}"#.utf8))
        XCTAssertFalse(settings.weatherCompanionEnabled)
        XCTAssertEqual(settings.displayName, "旧用户")
    }

    func testExplicitExistingWeatherChoiceSurvivesDecoding() throws {
        for enabled in [true, false] {
            var settings = AppSettings.default
            settings.weatherCompanionEnabled = enabled
            let reopened = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
            XCTAssertEqual(reopened.weatherCompanionEnabled, enabled)
        }
    }

    func testWeatherAccessDistinguishesUndecidedDeniedRestrictedAndDisabledServices() {
        let cases: [(CLAuthorizationStatus, WeatherLocationAccessState)] = [
            (.notDetermined, .notRequested), (.denied, .denied), (.restricted, .restricted),
            (.authorizedWhenInUse, .allowed), (.authorizedAlways, .allowed)
        ]
        for (status, expected) in cases {
            XCTAssertEqual(WeatherLocationAccessPolicy.accessState(
                locationServicesEnabled: true, authorizationStatus: status
            ), expected)
            XCTAssertEqual(WeatherLocationAccessPolicy.accessState(
                locationServicesEnabled: false, authorizationStatus: status
            ), .unavailable)
        }
    }

    func testWeatherRequiresBothExplicitFeatureChoiceAndCurrentLocationAccess() {
        let statuses: [CLAuthorizationStatus] = [
            .notDetermined, .denied, .restricted, .authorizedWhenInUse, .authorizedAlways
        ]
        for enabled in [false, true] {
            for servicesEnabled in [false, true] {
                for status in statuses {
                    XCTAssertEqual(WeatherLocationAccessPolicy.canUseWeather(
                        weatherEnabled: enabled, locationServicesEnabled: servicesEnabled,
                        authorizationStatus: status
                    ), enabled && servicesEnabled && (status == .authorizedWhenInUse || status == .authorizedAlways))
                }
            }
        }
    }

    func testLateWeatherResultsCannotReappearAfterDisablingOrRevokingAccess() {
        XCTAssertTrue(WeatherLocationAccessPolicy.canAcceptResult(
            requestRevision: 4, currentRevision: 4, weatherEnabled: true,
            locationServicesEnabled: true, authorizationStatus: .authorizedWhenInUse
        ))
        XCTAssertFalse(WeatherLocationAccessPolicy.canAcceptResult(
            requestRevision: 3, currentRevision: 4, weatherEnabled: true,
            locationServicesEnabled: true, authorizationStatus: .authorizedWhenInUse
        ))
        XCTAssertFalse(WeatherLocationAccessPolicy.canAcceptResult(
            requestRevision: 4, currentRevision: 4, weatherEnabled: false,
            locationServicesEnabled: true, authorizationStatus: .authorizedWhenInUse
        ))
        XCTAssertFalse(WeatherLocationAccessPolicy.canAcceptResult(
            requestRevision: 4, currentRevision: 4, weatherEnabled: true,
            locationServicesEnabled: true, authorizationStatus: .denied
        ))
        XCTAssertFalse(WeatherLocationAccessPolicy.canAcceptResult(
            requestRevision: 4, currentRevision: 4, weatherEnabled: true,
            locationServicesEnabled: false, authorizationStatus: .authorizedAlways
        ))
    }
}

final class RecordContinuousIntentTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_800_000_000.125)

    private func resolution(_ state: RecordExplicitIntentState, note: String, generated: Bool = false) -> RecordDraftResolution {
        RecordDraftResolutionService.resolve(.init(
            rawTitle: note, fallbackCategory: state.category, amount: 32, date: date,
            merchantBrandId: nil, categoryLockedByUser: state.categoryWasSelectedByUser,
            userEditedTitle: !generated, source: "continuous_regression",
            generatedNoteContext: generated ? .init(title: note, category: state.category) : nil,
            categoryIsSettled: state.preventsAutomaticCategoryChanges,
            preserveConfirmedTitle: true, manualNoteAnchor: generated ? nil : note
        ))
    }

    private func edited(
        _ baseline: HomeItem, state: RecordExplicitIntentState,
        note: String? = nil, amount: String? = nil, changedDate: Date? = nil,
        current: HomeItem? = nil
    ) -> HomeItem {
        let text = note ?? baseline.title
        let amountText = amount ?? String(format: "%.2f", baseline.amount)
        let date = changedDate ?? baseline.createdAt
        let intent = RecordEditPolicy.intent(
            baseline: baseline, amountText: amountText, noteText: text,
            initialNoteText: baseline.title, date: date, categoryIntent: state
        )
        let proposed = RecordEditPolicy.proposedItem(
            intent: intent, amountText: amountText, noteText: text, date: date
        )
        return RecordEditPolicy.applying(proposed, intent: intent, to: current ?? baseline)
    }

    func testShoppingThenNightSnackWinsBeforeSaveAndSurvivesDecodedEdits() throws {
        var state = RecordExplicitIntentState(category: .other)
        state.selectCategory(.shopping)
        state.writeNote("夜宵")
        XCTAssertEqual(state.category, .dining)
        XCTAssertFalse(state.categoryWasSelectedByUser)
        let result = resolution(state, note: "夜宵")
        XCTAssertEqual(result.category, .dining)
        XCTAssertEqual(result.title, "夜宵")
        let saved = HomeItem(
            title: result.title, amount: 32, category: result.category,
            createdAt: date, updatedAt: date, emotionTag: "夜宵这顿记下", userEditedTitle: true
        )
        let reopened = try JSONDecoder().decode(HomeItem.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(reopened.category, .dining)
        for _ in 0..<2 {
            let entryState = RecordExplicitIntentState(
                category: reopened.category, userSelectedCategory: reopened.userEditedCategory == true
            )
            XCTAssertEqual(edited(reopened, state: entryState), reopened)
        }
    }

    func testNightSnackThenShoppingAndRepeatedReversalKeepLastSelection() throws {
        var state = RecordExplicitIntentState(category: .other)
        state.writeNote("夜宵")
        state.selectCategory(.shopping)
        var result = resolution(state, note: "夜宵")
        XCTAssertEqual(result.category, .shopping)
        XCTAssertEqual(result.title, "夜宵")
        XCTAssertEqual(result.emotionTag, "")
        state.writeNote("牛肉面")
        XCTAssertEqual(state.category, .dining)
        state.selectCategory(.shopping)
        result = resolution(state, note: "牛肉面")
        let saved = HomeItem(
            title: result.title, amount: 32, category: result.category,
            createdAt: date, emotionTag: result.emotionTag,
            userEditedTitle: true, userEditedCategory: true
        )
        let reopened = try JSONDecoder().decode(HomeItem.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(edited(reopened, state: .init(category: .shopping, userSelectedCategory: true)), reopened)
        XCTAssertEqual(reopened.category, .shopping)
    }

    func testAutomaticResultsNeverOverrideEitherExplicitSource() {
        var state = RecordExplicitIntentState(category: .other)
        state.adoptAutomaticCategory(.daily)
        XCTAssertEqual(state.category, .daily)
        state.selectCategory(.shopping)
        let revision = state.revision
        state.adoptAutomaticCategory(.dining)
        XCTAssertEqual(state.category, .shopping)
        XCTAssertEqual(state.revision, revision)
        state.writeNote("夜宵")
        state.adoptAutomaticCategory(.shopping)
        XCTAssertEqual(state.category, .dining)
        XCTAssertFalse(state.categoryWasSelectedByUser)
    }

    func testGeneratedSocialAndConvenienceSentencesRetainChosenCategory() {
        for (category, text) in [(HomeItem.Category.social, "一起吃顿饭"), (.daily, "便利店补一袋日常")] {
            var state = RecordExplicitIntentState(category: category)
            state.selectCategory(category)
            let before = state
            let generated = resolution(state, note: text, generated: true)
            XCTAssertEqual(generated.category, category)
            XCTAssertEqual(state, before)
        }
    }

    func testExplicitEvidenceUsesSpecificWordsAndRejectsMixedCategories() {
        let expected: [(String, HomeItem.Category)] = [
            ("夜宵", .dining), ("宵夜", .dining), ("午饭", .dining), ("瑞幸", .dining),
            ("手机话费", .daily), ("咖啡器具", .shopping), ("手机充电器", .shopping),
            ("罗森买纸巾", .daily), ("请客朋友", .social), ("电影", .entertainment)
        ]
        for (note, category) in expected {
            XCTAssertEqual(RecordExplicitIntentPolicy.category(for: note), category, note)
        }
        for note in ["", "记一下", "夜宵和地铁", "咖啡和咖啡器具"] {
            var state = RecordExplicitIntentState(category: .shopping, userSelectedCategory: true)
            XCTAssertNil(state.writeNote(note), note)
            XCTAssertEqual(state.category, .shopping, note)
            XCTAssertTrue(state.categoryWasSelectedByUser, note)
        }
    }

    func testExistingManualChoiceCanBeSupersededByNewNoteWithoutFakeCorrection() {
        let original = HomeItem(
            title: "旧备注", amount: 32, category: .shopping, createdAt: date,
            userEditedCategory: true, categoryCorrectionFrom: .daily
        )
        var state = RecordExplicitIntentState(category: .shopping, userSelectedCategory: true)
        state.writeNote("夜宵")
        let result = edited(original, state: state, note: "夜宵")
        XCTAssertEqual(result.category, .dining)
        XCTAssertEqual(result.title, "夜宵")
        XCTAssertNil(result.userEditedCategory)
        XCTAssertNil(result.categoryCorrectionFrom)
        XCTAssertEqual(result.userEditedTitle, true)
        state.selectCategory(.shopping)
        let reversed = edited(original, state: state, note: "夜宵")
        XCTAssertEqual(reversed.category, .shopping)
        XCTAssertEqual(reversed.userEditedCategory, true)
        XCTAssertEqual(reversed.title, "夜宵")
    }

    func testNewBrandIntentAndOldBrandUnbinding() throws {
        let original = HomeItem(title: "原备注", amount: 32, category: .shopping, createdAt: date, userEditedCategory: true)
        var state = RecordExplicitIntentState(category: .shopping, userSelectedCategory: true)
        state.writeNote("瑞幸")
        let coffee = edited(original, state: state, note: "瑞幸")
        XCTAssertEqual(coffee.category, .dining)
        XCTAssertEqual(coffee.merchantBrandId, try XCTUnwrap(MerchantBrandCatalog.matchBrand(in: "瑞幸")).id)
        state.selectCategory(.shopping)
        XCTAssertNil(edited(original, state: state, note: "瑞幸").merchantBrandId)
        var next = RecordExplicitIntentState(category: coffee.category)
        next.writeNote("手机充电器")
        let charger = edited(coffee, state: next, note: "手机充电器")
        XCTAssertEqual(charger.category, .shopping)
        XCTAssertNil(charger.merchantBrandId)
    }

    func testOriginalUpdateKeepsPrecisionEmotionAndAllMetadata() throws {
        let original = HomeItem(
            title: "夜宵", amount: 32.123456, category: .shopping, source: .ocr,
            createdAt: date, updatedAt: date.addingTimeInterval(0.125), emotionTag: "自己选的表达",
            userEditedTitle: true, userEditedCategory: true, categoryCorrectionFrom: .daily,
            memoryContext: .init(weatherKind: "rain", temperatureCelsius: 18, cityName: "苏州", semanticPlace: nil),
            memoryImageDatas: [Data([1, 2, 3])]
        )
        let reopened = try JSONDecoder().decode(HomeItem.self, from: JSONEncoder().encode(original))
        let state = RecordExplicitIntentState(category: reopened.category, userSelectedCategory: true)
        let result = edited(reopened, state: state)
        XCTAssertEqual(result, reopened)
        XCTAssertEqual(result.amount, 32.123456)
        XCTAssertEqual(result.updatedAt, original.updatedAt)
        XCTAssertEqual(result.emotionTag, "自己选的表达")
    }

    func testAmountAndDateOnlyKeepSavedCategoryWithoutNewManualProvenance() {
        let original = HomeItem(title: "夜宵", amount: 32, category: .shopping, createdAt: date)
        let state = RecordExplicitIntentState(category: original.category)
        let changed = edited(original, state: state, amount: "35", changedDate: date.addingTimeInterval(0.25))
        XCTAssertEqual(changed.category, .shopping)
        XCTAssertEqual(changed.amount, 35)
        XCTAssertEqual(changed.createdAt, date.addingTimeInterval(0.25))
        XCTAssertNil(changed.userEditedCategory)
    }

    func testSameCategoryClickChangesOnlyProvenance() {
        let original = HomeItem(title: "夜宵", amount: 32, category: .shopping, createdAt: date, emotionTag: "自选表达")
        var state = RecordExplicitIntentState(category: original.category)
        XCTAssertEqual(edited(original, state: state), original)
        state.selectCategory(.shopping)
        let selected = edited(original, state: state)
        var expected = original
        expected.userEditedCategory = true
        XCTAssertEqual(selected, expected)
    }

    func testEditorMergesOnlyChangedFieldsIntoLatestLedgerRow() {
        let original = HomeItem(title: "夜宵", amount: 32, category: .dining, createdAt: date)
        var latest = original
        latest.appendMemoryImages([Data([4, 5, 6])])
        latest.category = .social
        latest.title = "同步后的新备注"
        latest.amount = 45
        latest.userEditedCategory = true
        let state = RecordExplicitIntentState(category: original.category)
        XCTAssertEqual(edited(original, state: state, current: latest), latest)
        let result = edited(original, state: state, amount: "36", current: latest)
        XCTAssertEqual(result.amount, 36)
        XCTAssertEqual(result.category, .social)
        XCTAssertEqual(result.memoryImageDatas, latest.memoryImageDatas)
        XCTAssertEqual(result.userEditedCategory, true)
    }

    func testPolishCandidatesPreserveFactsAndLength() {
        for anchor in ["夜宵", "徐记花甲鸡爪｜宿豫店", "路亚", "请客朋友"] {
            let candidates = RecordHandwrittenNotePolishPolicy.candidates(anchor: anchor)
            XCTAssertFalse(candidates.isEmpty)
            for text in candidates {
                XCTAssertTrue(text.contains(anchor))
                XCTAssertLessThanOrEqual(text.count, 32)
                for invented in ["加班", "晚归", "热乎", "便利店", "早餐"] where !anchor.contains(invented) {
                    XCTAssertFalse(text.contains(invented))
                }
            }
        }
        XCTAssertTrue(RecordHandwrittenNotePolishPolicy.candidates(anchor: String(repeating: "字", count: 32)).isEmpty)
    }

    func testHandwrittenQuickNotesCannotAddMealOrSpecificFacts() {
        XCTAssertFalse(RecordQuickNotePolicy.respectsHandwrittenAnchor("早餐记一笔", anchor: "夜宵"))
        XCTAssertFalse(RecordQuickNotePolicy.respectsHandwrittenAnchor("瑞幸咖啡", anchor: "夜宵"))
        XCTAssertFalse(RecordQuickNotePolicy.respectsHandwrittenAnchor("加班吃夜宵", anchor: "夜宵"))
        XCTAssertTrue(RecordQuickNotePolicy.respectsHandwrittenAnchor("夜宵记一笔", anchor: "夜宵"))
    }

    func testPolishCandidateIdentityChangesWithFactsButNotCandidateBrowsing() {
        let baseline = RecordNotePolishContext(
            amount: "32", title: "夜宵", category: .dining, date: date,
            anchor: "夜宵", scenePackID: nil, categoryExplicit: true
        )
        let candidate = RecordNotePolishCandidate(context: baseline, title: "夜宵，记一笔")
        XCTAssertEqual(candidate.context, baseline)
        XCTAssertNotEqual(candidate.context, RecordNotePolishContext(
            amount: "32", title: "夜宵", category: .shopping, date: date,
            anchor: "夜宵", scenePackID: nil, categoryExplicit: true
        ))
        XCTAssertNotEqual(candidate.context, RecordNotePolishContext(
            amount: "32", title: "午饭", category: .dining, date: date,
            anchor: "午饭", scenePackID: nil, categoryExplicit: true
        ))
        XCTAssertEqual(baseline.title, "夜宵")
    }
}

#if canImport(UIKit)
@MainActor
final class CommittedRecordNoteFieldTests: XCTestCase {
    private final class Position: UITextPosition {}
    private final class Range: UITextRange {
        override var start: UITextPosition { Position() }
        override var end: UITextPosition { Position() }
        override var isEmpty: Bool { false }
    }
    private final class ComposingField: UITextField {
        var composing = false
        override var markedTextRange: UITextRange? { composing ? Range() : nil }
    }

    func testIMEPublishesOnlyTheCommittedNoteOnce() {
        var committed: [String] = []
        let control = CommittedRecordNoteField(
            text: "", placeholder: "备注", isFocused: .constant(true),
            onCommittedChange: { committed.append($0) }
        )
        let coordinator = control.makeCoordinator()
        let field = ComposingField()
        field.composing = true
        field.text = "ye xiao"
        coordinator.textChanged(field)
        XCTAssertTrue(committed.isEmpty)
        field.composing = false
        field.text = "夜宵"
        coordinator.textChanged(field)
        coordinator.textFieldDidEndEditing(field)
        XCTAssertEqual(committed, ["夜宵"])
    }

    func testOpeningAndClosingOldLongNoteDoesNotTruncateOrCreateIntent() {
        let original = String(repeating: "旧备注", count: 20)
        var committed: [String] = []
        let control = CommittedRecordNoteField(
            text: original, placeholder: "备注", isFocused: .constant(true),
            onCommittedChange: { committed.append($0) }
        )
        let field = UITextField()
        field.text = original
        control.makeCoordinator().textFieldDidEndEditing(field)
        XCTAssertEqual(field.text, original)
        XCTAssertTrue(committed.isEmpty)
    }

    func testKeyboardAvoidanceUsesOnlyTheCoveredPartOfTheLocalViewport() {
        let viewport = CGRect(x: 0, y: 0, width: 390, height: 640)
        let keyboard = CGRect(x: 0, y: 420, width: 390, height: 330)

        XCTAssertEqual(
            RecordKeyboardViewportReader.bottomOverlap(viewport: viewport, keyboard: keyboard),
            220
        )
    }

    func testKeyboardAvoidanceDoesNotAddAnInsetWithoutAnIntersection() {
        let keyboard = CGRect(x: 0, y: 420, width: 390, height: 330)
        let visibleViewport = CGRect(x: 0, y: 0, width: 390, height: 420)
        XCTAssertEqual(
            RecordKeyboardViewportReader.bottomOverlap(viewport: visibleViewport, keyboard: keyboard),
            0
        )

        let viewport = CGRect(x: 0, y: 0, width: 390, height: 640)
        let hiddenKeyboard = CGRect(x: 0, y: 750, width: 390, height: 330)
        XCTAssertEqual(
            RecordKeyboardViewportReader.bottomOverlap(viewport: viewport, keyboard: hiddenKeyboard),
            0
        )

        let adjacentKeyboard = CGRect(x: 410, y: 420, width: 320, height: 230)
        XCTAssertEqual(
            RecordKeyboardViewportReader.bottomOverlap(viewport: viewport, keyboard: adjacentKeyboard),
            0
        )
    }

    func testKeyboardAvoidanceKeepsTheViewportAboveFloatingOrOversizedKeyboards() {
        let viewport = CGRect(x: 20, y: 40, width: 700, height: 640)
        let floatingKeyboard = CGRect(x: 210, y: 380, width: 320, height: 220)
        XCTAssertEqual(
            RecordKeyboardViewportReader.bottomOverlap(viewport: viewport, keyboard: floatingKeyboard),
            300
        )

        let oversizedKeyboard = CGRect(x: 0, y: 0, width: 800, height: 900)
        XCTAssertEqual(
            RecordKeyboardViewportReader.bottomOverlap(viewport: viewport, keyboard: oversizedKeyboard),
            viewport.height
        )
    }

    private final class EditorDriver: ObservableObject {
        @Published var saveRequestID: UUID?
        var savedItem: HomeItem?
    }

    private struct HostedEditor: View {
        @ObservedObject var driver: EditorDriver
        let item: HomeItem

        var body: some View {
            FocusedRecordEditor(
                item: item,
                autoCommitRequestID: driver.saveRequestID,
                onSave: { item, _ in
                    driver.savedItem = item
                    return true
                },
                onCancel: {},
                onDelete: {}
            )
        }
    }

    func testHostedEditorKeepsNoteFocusAcrossDeletionAndInsertionUntilSave() throws {
        try withHostedEditor { host, driver in
            let note = try XCTUnwrap(textFields(in: host.view).first { $0.accessibilityLabel == "备注" })
            XCTAssertTrue(note.becomeFirstResponder())
            settleUI(host)
            note.selectedTextRange = note.textRange(from: note.endOfDocument, to: note.endOfDocument)

            for expected in ["午饭备", "午饭"] {
                note.deleteBackward()
                settleUI(host)
                XCTAssertEqual(note.text, expected)
                XCTAssertTrue(note.isFirstResponder)
                XCTAssertTrue(textFields(in: host.view).contains { $0 === note })
            }

            note.insertText("加菜")
            settleUI(host)
            XCTAssertEqual(note.text, "午饭加菜")
            XCTAssertTrue(note.isFirstResponder)

            driver.saveRequestID = UUID()
            settleUI(host)
            XCTAssertEqual(driver.savedItem?.title, "午饭加菜")
            XCTAssertFalse(note.isFirstResponder)
            settleUI(host)
            XCTAssertFalse(note.isFirstResponder)
        }
    }

    func testHostedEditorTransfersFocusBetweenAmountAndNote() throws {
        try withHostedEditor { host, _ in
            let fields = textFields(in: host.view)
            let note = try XCTUnwrap(fields.first { $0.accessibilityLabel == "备注" })
            let amount = try XCTUnwrap(fields.first { $0.keyboardType == .decimalPad })

            for _ in 0..<2 {
                XCTAssertTrue(note.becomeFirstResponder())
                settleUI(host)
                XCTAssertTrue(note.isFirstResponder)
                XCTAssertFalse(amount.isFirstResponder)
                note.selectedTextRange = note.textRange(from: note.endOfDocument, to: note.endOfDocument)
                note.insertText("字")
                settleUI(host)
                XCTAssertTrue(note.isFirstResponder)

                XCTAssertTrue(amount.becomeFirstResponder())
                settleUI(host)
                XCTAssertTrue(amount.isFirstResponder)
                XCTAssertFalse(note.isFirstResponder)
                amount.selectedTextRange = amount.textRange(from: amount.endOfDocument, to: amount.endOfDocument)
                amount.deleteBackward()
                settleUI(host)
                XCTAssertTrue(amount.isFirstResponder)
                XCTAssertFalse(note.isFirstResponder)
            }
        }
    }

    private func withHostedEditor(
        _ body: (UIHostingController<HostedEditor>, EditorDriver) throws -> Void
    ) throws {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            throw XCTSkip("A foreground iOS app scene is required for responder integration tests.")
        }
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let driver = EditorDriver()
        let item = HomeItem(title: "午饭备注", amount: 32, category: .dining, createdAt: Date())
        let host = UIHostingController(rootView: HostedEditor(driver: driver, item: item))
        let window = UIWindow(windowScene: scene)
        window.frame = scene.screen.bounds
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            host.view.endEditing(true)
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
        settleUI(host)
        try body(host, driver)
    }

    private func settleUI(_ host: UIHostingController<HostedEditor>) {
        // A real SwiftUI render must consume the text/focus changes before assertions.
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        host.view.layoutIfNeeded()
    }

    private func textFields(in view: UIView) -> [UITextField] {
        (view as? UITextField).map { [$0] } ?? view.subviews.flatMap { textFields(in: $0) }
    }
}
#endif


#if canImport(WeatherKit)
final class WeatherKitConditionBridgeTests: XCTestCase {
    @MainActor
    func testPrecipitationConditionsKeepExistingRainAndSnowGroups() {
        XCTAssertEqual(WeatherCompanionService.legacyWeatherCode(for: .rain), 61)
        XCTAssertEqual(WeatherCompanionService.legacyWeatherCode(for: .freezingRain), 61)
        XCTAssertEqual(WeatherCompanionService.legacyWeatherCode(for: .snow), 71)
        XCTAssertEqual(WeatherCompanionService.legacyWeatherCode(for: .wintryMix), 71)
        XCTAssertNil(WeatherCompanionService.legacyWeatherCode(for: .clear))
        XCTAssertNil(WeatherCompanionService.legacyWeatherCode(for: .thunderstorms))
    }
}
#endif

final class LegalConsentStoreTests: XCTestCase {
    private func withIsolatedDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "LegalConsentStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }

    func testNewInstallRequiresExplicitConsentAndAcceptancePersistsVersionAndTime() {
        withIsolatedDefaults { defaults in
            let acceptedAt = Date(timeIntervalSince1970: 1_787_875_200)
            let store = LegalConsentStore(defaults: defaults)

            XCTAssertFalse(store.hasAcceptedCurrentPolicies)
            XCTAssertNil(store.currentRecord)

            let record = store.acceptCurrentPolicies(now: acceptedAt)

            XCTAssertEqual(record?.termsVersion, LoginLegalPolicy.termsVersion)
            XCTAssertEqual(record?.privacyVersion, LoginLegalPolicy.privacyVersion)
            XCTAssertEqual(record?.acceptedAt, acceptedAt)
            XCTAssertTrue(store.hasAcceptedCurrentPolicies)

            let storeAfterRestart = LegalConsentStore(defaults: defaults)
            XCTAssertTrue(storeAfterRestart.hasAcceptedCurrentPolicies)
            XCTAssertEqual(storeAfterRestart.currentRecord, record)
        }
    }

    func testPolicyVersionChangeRequiresFreshConsentWithoutDeletingTheOldRecord() {
        withIsolatedDefaults { defaults in
            let original = LegalConsentStore(
                defaults: defaults,
                termsVersion: "1.0",
                privacyVersion: "1.0"
            )
            let acceptedAt = Date(timeIntervalSince1970: 1_787_875_200)
            original.acceptCurrentPolicies(now: acceptedAt)

            let updated = LegalConsentStore(
                defaults: defaults,
                termsVersion: "2.0",
                privacyVersion: "1.1"
            )

            XCTAssertFalse(updated.hasAcceptedCurrentPolicies)
            XCTAssertEqual(updated.currentRecord?.termsVersion, "1.0")
            XCTAssertEqual(updated.currentRecord?.privacyVersion, "1.0")
            XCTAssertEqual(updated.currentRecord?.acceptedAt, acceptedAt)
        }
    }

    func testRevokingConsentRemovesTheStoredRecord() {
        withIsolatedDefaults { defaults in
            let store = LegalConsentStore(defaults: defaults)
            store.acceptCurrentPolicies()
            XCTAssertTrue(store.hasAcceptedCurrentPolicies)

            store.revokeCurrentPolicies()

            XCTAssertFalse(store.hasAcceptedCurrentPolicies)
            XCTAssertNil(store.currentRecord)
        }
    }
}

final class OCRDateEvidencePolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 27,
            hour: 14,
            minute: 30
        ))!
    }

    func testPaymentAmountCannotBecomeADateWhenTheScreenshotHasNoDateEvidence() {
        let resolved = OCRDateEvidencePolicy.resolvedDate(
            in: "支付成功\nLAWSON\n¥4.20",
            excludingLines: ["¥4.20"],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(resolved, now)
    }

    func testCurrencyAndAmountLabelsAreRejectedAsDateCandidates() {
        XCTAssertNil(OCRDateEvidencePolicy.firstDate(
            in: "￥4.20",
            now: now,
            calendar: calendar
        ))
        XCTAssertNil(OCRDateEvidencePolicy.firstDate(
            in: "支付金额 4.20",
            now: now,
            calendar: calendar
        ))
    }

    func testExplicitAndDateLabeledDatesRemainSupported() throws {
        let chinese = try XCTUnwrap(OCRDateEvidencePolicy.firstDate(
            in: "4月20日",
            now: now,
            calendar: calendar
        ))
        let full = try XCTUnwrap(OCRDateEvidencePolicy.firstDate(
            in: "交易时间 2026-04-21 08:35",
            now: now,
            calendar: calendar
        ))
        let labeledBare = try XCTUnwrap(OCRDateEvidencePolicy.firstDate(
            in: "日期\n4.22",
            now: now,
            calendar: calendar
        ))

        XCTAssertEqual(calendar.component(.month, from: chinese), 4)
        XCTAssertEqual(calendar.component(.day, from: chinese), 20)
        XCTAssertEqual(calendar.component(.day, from: full), 21)
        XCTAssertEqual(calendar.component(.hour, from: full), 8)
        XCTAssertEqual(calendar.component(.day, from: labeledBare), 22)
    }
}

final class OCRCategoryEvidencePolicyTests: XCTestCase {
    private let productTitle = "巧婆红汤馄饨（云密城店）"
    private let paymentScreenshot = """
    支付成功
    商品 巧婆红汤馄饨（云密城店）
    商户全称 南京市雨花台区红汤淮味馄饨店（个体工商户）
    收单机构 拉卡拉支付股份有限公司
    支付方式 零钱
    交易单号 4200003226202609039675284401
    """

    func testProductAndMerchantEvidenceWinsOverPaymentProcessorMetadata() {
        let semanticText = OCRCategoryEvidencePolicy.semanticText(
            title: productTitle,
            rawText: paymentScreenshot
        )

        XCTAssertTrue(semanticText.contains("馄饨"))
        XCTAssertFalse(semanticText.contains("拉卡拉"))
        XCTAssertFalse(semanticText.contains("收单机构"))
        XCTAssertFalse(semanticText.contains("支付方式"))
        XCTAssertFalse(semanticText.contains("4200003226202609039675284401"))
        XCTAssertEqual(
            OCRCategoryEvidencePolicy.resolve(
                title: productTitle,
                rawText: paymentScreenshot,
                fallback: .transport
            ),
            .dining
        )
    }

    func testLineSeparatedTrustedValuesStayAndMetadataRowsStayOut() {
        let lineSeparated = """
        当前状态
        支付成功
        商品
        巧婆红汤馄饨（云密城店）
        商户全称
        南京市雨花台区红汤淮味馄饨店（个体工商户）
        收单机构
        拉卡拉支付股份有限公司
        支付方式
        零钱
        交易单号
        4200003226202609039675284401
        """

        let semanticText = OCRCategoryEvidencePolicy.semanticText(
            title: "",
            rawText: lineSeparated
        )

        XCTAssertTrue(semanticText.contains("馄饨"))
        XCTAssertFalse(semanticText.contains("拉卡拉"))
        XCTAssertFalse(semanticText.contains("4200003226202609039675284401"))
        XCTAssertEqual(
            OCRCategoryEvidencePolicy.resolve(
                title: "",
                rawText: lineSeparated,
                fallback: .transport
            ),
            .dining
        )
    }

    func testLegalEntitySuffixDoesNotCreateCommuteSceneButRealCompanyContextDoes() {
        let processor = HomeItem(
            title: "拉卡拉支付股份有限公司",
            amount: 10,
            category: .dining,
            createdAt: Date()
        )
        XCTAssertNotEqual(LifeSceneSemanticService.classify(processor).kind, .commute)

        let companyCommute = HomeItem(
            title: "公司楼下打车",
            amount: 18,
            category: .transport,
            createdAt: Date()
        )
        XCTAssertEqual(LifeSceneSemanticService.classify(companyCommute).kind, .commute)
    }
}

final class SummaryPlaybackSceneLifecyclePolicyTests: XCTestCase {
    func testPlaybackResumesOnlyWhenTheActiveSessionWasInterrupted() {
        XCTAssertTrue(
            SummaryPlaybackSceneLifecyclePolicy.shouldResumePlayback(
                wasPlayingBeforeInterruption: true,
                playbackDone: false,
                chapterCount: 5
            )
        )
        XCTAssertFalse(
            SummaryPlaybackSceneLifecyclePolicy.shouldResumePlayback(
                wasPlayingBeforeInterruption: false,
                playbackDone: false,
                chapterCount: 5
            )
        )
        XCTAssertFalse(
            SummaryPlaybackSceneLifecyclePolicy.shouldResumePlayback(
                wasPlayingBeforeInterruption: true,
                playbackDone: true,
                chapterCount: 5
            )
        )
        XCTAssertFalse(
            SummaryPlaybackSceneLifecyclePolicy.shouldResumePlayback(
                wasPlayingBeforeInterruption: true,
                playbackDone: false,
                chapterCount: 0
            )
        )
    }

    func testCoverPrewarmRequiresAnActiveSceneAndAnEnabledGeneration() {
        let active = SummaryPlaybackSceneLifecyclePolicy.shouldPrewarmCover(
            isSceneActive: true,
            sceneAllowsCoverWork: true,
            hasSharePayload: true,
            chapterCount: 5,
            playbackDone: true,
            activeIndex: 4,
            showsSharePrivacy: false
        )
        XCTAssertTrue(active)

        for (sceneActive, generationEnabled) in [(false, true), (true, false)] {
            XCTAssertFalse(
                SummaryPlaybackSceneLifecyclePolicy.shouldPrewarmCover(
                    isSceneActive: sceneActive,
                    sceneAllowsCoverWork: generationEnabled,
                    hasSharePayload: true,
                    chapterCount: 5,
                    playbackDone: true,
                    activeIndex: 4,
                    showsSharePrivacy: false
                )
            )
        }
    }

    func testCoverPrewarmStaysDeferredBeforeTheLastChapter() {
        XCTAssertFalse(
            SummaryPlaybackSceneLifecyclePolicy.shouldPrewarmCover(
                isSceneActive: true,
                sceneAllowsCoverWork: true,
                hasSharePayload: true,
                chapterCount: 5,
                playbackDone: false,
                activeIndex: 2,
                showsSharePrivacy: false
            )
        )
        XCTAssertTrue(
            SummaryPlaybackSceneLifecyclePolicy.shouldPrewarmCover(
                isSceneActive: true,
                sceneAllowsCoverWork: true,
                hasSharePayload: true,
                chapterCount: 5,
                playbackDone: false,
                activeIndex: 2,
                showsSharePrivacy: true
            )
        )
    }
}

final class LifeNarrativeSignalPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!
        return calendar
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
    }

    private func item(
        _ title: String,
        category: HomeItem.Category,
        day: Int,
        userEdited: Bool = false,
        source: HomeItem.Source = .manual,
        userEditedCategory: Bool = false,
        hasPhoto: Bool = false,
        photoRole: PhotoMemoryAssetRole? = nil
    ) -> HomeItem {
        HomeItem(
            title: title,
            amount: 12,
            category: category,
            source: source,
            createdAt: date(day),
            userEditedTitle: userEdited,
            userEditedCategory: userEditedCategory,
            memoryImageData: hasPhoto ? Data([0x01]) : nil,
            memoryAnchorRole: photoRole
        )
    }

    func testStableCoffeeRemainsAMarkWithoutRepeatingAsLead() {
        let rows = [
            item("午后咖啡", category: .dining, day: 20),
            item("一杯拿铁", category: .dining, day: 20),
            item("美式咖啡", category: .dining, day: 21),
            item("咖啡饮品", category: .dining, day: 21),
        ]
        let previous = [
            item("上周午后咖啡", category: .dining, day: 13),
            item("上周拿铁", category: .dining, day: 13),
            item("上周美式", category: .dining, day: 14),
            item("上周咖啡饮品", category: .dining, day: 14),
        ]

        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 4,
                items: rows,
                previousItems: previous,
                now: date(21),
                recentLeadSignalIDs: ["scene:coffee"]
            )
        )

        XCTAssertNotEqual(plan.leadSignalID, "scene:coffee")
        XCTAssertFalse(plan.hasNarrativeLead)
        XCTAssertTrue(plan.markLabels.contains("咖啡饮品"))
        XCTAssertTrue(plan.summary.contains("4 笔记录"))
        XCTAssertEqual(plan.headline, "本周记录")
    }

    func testCoffeeCanLeadAgainWhenTheCountReallyChanges() {
        let current = [
            item("咖啡 1", category: .dining, day: 20),
            item("咖啡 2", category: .dining, day: 20),
            item("咖啡 3", category: .dining, day: 21),
            item("咖啡 4", category: .dining, day: 21),
        ]
        let previous = [item("上周咖啡", category: .dining, day: 14)]

        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 5,
                items: current,
                previousItems: previous,
                now: date(21),
                recentLeadSignalIDs: ["scene:coffee"]
            )
        )

        XCTAssertEqual(plan.leadSignalID, "change:coffee:up")
        XCTAssertTrue(plan.headline.contains("多了 3 笔"))
        XCTAssertTrue(plan.summary.contains("4 笔记录"))
        XCTAssertTrue(plan.markLabels.contains("咖啡饮品"))
    }

    func testPhotoBecomesConcreteLeadWhileCoffeeStaysInTheMarkLayer() {
        let rows = [
            item("午后咖啡", category: .dining, day: 20),
            item(
                "红汤馄饨",
                category: .dining,
                day: 21,
                userEdited: true,
                hasPhoto: true,
                photoRole: .moment
            ),
        ]

        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 2,
                items: rows,
                previousItems: [item("上周咖啡", category: .dining, day: 14)],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertEqual(plan.leadSignalID, "photo:\(rows[1].id.uuidString)")
        XCTAssertTrue(plan.headline.contains("红汤馄饨"))
        XCTAssertTrue(plan.markLabels.contains("咖啡饮品"))
    }

    func testAdministrativeBillsStayInEvidenceWithoutBecomingLeadOrMark() {
        let rows = [
            item("手机话费", category: .daily, day: 18),
            item("手机话费充值", category: .daily, day: 19),
            item("下班通勤", category: .transport, day: 20),
        ]
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 3,
                items: rows,
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertFalse(plan.leadSignalID?.contains("telecomBill") == true)
        XCTAssertFalse(plan.markLabels.contains("话费账单"))
        let administrativeEvidence = plan.signalsByRole[.evidence, default: []]
            .filter(\.isAdministrative)
        XCTAssertFalse(administrativeEvidence.isEmpty)
        XCTAssertTrue(administrativeEvidence.allSatisfy { $0.narrativeValue < 55 })
    }

    func testAdministrativeChangeRemainsANeutralDataObservation() {
        let current = [
            item("手机话费", category: .daily, day: 18),
            item("电费缴费", category: .home, day: 19),
            item("停车费", category: .transport, day: 20),
        ]
        let previous = [item("上周手机话费", category: .daily, day: 10)]
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 4,
                items: current,
                previousItems: previous,
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertNil(plan.leadSignalID)
        XCTAssertFalse(plan.hasNarrativeLead)
        XCTAssertFalse(plan.headline.contains("明显变化"))
        let observation = plan.signalsByRole[.evidence, default: []].first {
            $0.id == "administrative:change:up"
        }
        XCTAssertEqual(observation?.kind, .change)
        XCTAssertEqual(observation?.isAdministrative, true)
        XCTAssertLessThan(observation?.narrativeValue ?? Int.max, 55)
    }

    func testReceiptPhotoCannotBecomeAStoryLead() {
        let receipt = item(
            "超市小票",
            category: .daily,
            day: 21,
            hasPhoto: true,
            photoRole: .receipt
        )
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 1,
                items: [receipt],
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertFalse(plan.leadSignalID?.hasPrefix("photo:") == true)
        XCTAssertFalse(plan.signalsByRole[.lead, default: []].contains { $0.kind == .photo })
    }

    func testQualifiedMomentPhotoCanBecomeAConcreteLead() {
        let moment = item(
            "红汤馄饨",
            category: .dining,
            day: 21,
            hasPhoto: true,
            photoRole: .moment
        )
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 1,
                items: [moment],
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertEqual(plan.leadSignalID, "photo:\(moment.id.uuidString)")
        XCTAssertTrue(plan.headline.contains("红汤馄饨"))
        XCTAssertTrue(plan.headline.contains("还留着一张照片"))
        XCTAssertTrue(plan.summary.contains("只记下一笔"))
    }

    func testPhotoWithoutAQualifiedRoleStaysOutOfTheLead() {
        let attachment = item(
            "普通附件",
            category: .other,
            day: 21,
            hasPhoto: true
        )
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 1,
                items: [attachment],
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertFalse(plan.leadSignalID?.hasPrefix("photo:") == true)
        XCTAssertEqual(plan.maturity, .factual)
    }

    func testEditedTitleMetadataDoesNotBecomeAVisibleNarrativeCount() {
        let rows = [
            item("上班通勤", category: .transport, day: 20, userEdited: true),
            item("巧婆红汤馄饨", category: .dining, day: 21, userEdited: true),
        ]
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 2,
                items: rows,
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertNil(plan.leadSignalID)
        XCTAssertFalse(plan.hasNarrativeLead)
        XCTAssertEqual(plan.headline, "本周记录")
        XCTAssertFalse("\(plan.headline) \(plan.summary)".contains("主动记录"))
        XCTAssertFalse("\(plan.headline) \(plan.summary)".contains("用户主动写下"))
    }

    func testImportedTitlesCannotBecomeUserExpressionLeads() {
        let rows = [
            item(
                "终于到家",
                category: .transport,
                day: 20,
                userEdited: true,
                source: .ocr
            ),
            item(
                "终于回家",
                category: .transport,
                day: 21,
                userEdited: true,
                userEditedCategory: true
            ),
        ]
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 21,
                items: rows,
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertNil(plan.leadSignalID)
        XCTAssertFalse(plan.hasNarrativeLead)
        XCTAssertEqual(plan.headline, "本周记录")
    }

    func testSpecificUserExpressionCanLeadWithoutTurningIntoMetadataCopy() {
        let expression = item("终于到家", category: .transport, day: 21, userEdited: true)
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 3,
                items: [item("普通餐饮", category: .dining, day: 20), expression],
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertEqual(plan.leadSignalID, "user:\(expression.id.uuidString)")
        XCTAssertTrue(plan.headline.contains("终于到家"))
        XCTAssertTrue(plan.summary.contains("2 笔记录"))
        XCTAssertFalse("\(plan.headline) \(plan.summary)".contains("主动记录"))
    }

    func testNestedWeekAndMonthUseTheSameUniqueExpressionEvidence() {
        let expression = item("终于到家", category: .transport, day: 21, userEdited: true)
        let monthRows = [
            item("月初日用", category: .daily, day: 2),
            expression,
        ]
        let weekPlan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 4,
                items: [expression],
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )
        let monthPlan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .month,
                sourceRevision: 4,
                items: monthRows,
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertEqual(weekPlan.leadSignalID, monthPlan.leadSignalID)
        XCTAssertEqual(weekPlan.signalsByRole[.lead]?.first?.evidenceItemIDs, [expression.id])
        XCTAssertEqual(monthPlan.signalsByRole[.lead]?.first?.evidenceItemIDs, [expression.id])
    }

    func testWeekLifeCardClueAndPlaybackShareTheSameLeadIdentity() {
        let previous = [
            item("上周咖啡 1", category: .dining, day: 13),
            item("上周咖啡 2", category: .dining, day: 14),
        ]
        let current = [
            item("本周咖啡", category: .dining, day: 20),
            item(
                "红汤馄饨",
                category: .dining,
                day: 21,
                hasPhoto: true,
                photoRole: .moment
            ),
        ]
        let allItems = previous + current
        let chapter = TraceSnapshotComputation.buildChapter(
            TraceChapterComputationInput(
                range: .week,
                items: current,
                allItems: allItems,
                isMember: true,
                prioritizeRecurringMarks: false,
                periodKey: "2026-W30",
                usesEchoAnchor: false,
                sourceRevision: 42,
                now: date(21)
            )
        )
        let clue = TraceSnapshotComputation.buildClue(
            TraceClueComputationInput(
                items: current,
                allItems: allItems,
                period: .week,
                periodLabel: "这一周",
                isMember: true,
                freeRemaining: 5,
                storedUnlock: true,
                sourceRevision: 42,
                narrativeScope: .week,
                allowsNarrativeRewrite: true,
                now: date(21)
            )
        )
        let playbackPlan = PlaybackService().buildWeeklyShareCardPayload(
            from: allItems,
            now: date(21),
            sourceRevision: 42
        )?.narrativePlan

        XCTAssertEqual(chapter.narrativePlan.leadSignalID, clue.narrativePlan?.leadSignalID)
        XCTAssertEqual(chapter.narrativePlan.leadSignalID, playbackPlan?.leadSignalID)
        XCTAssertEqual(chapter.narrativePlan.sourceRevision, 42)
        XCTAssertTrue(chapter.narrativePlan.markLabels.contains("咖啡饮品"))
        XCTAssertTrue(clue.narrativePlan?.markLabels.contains("咖啡饮品") == true)
    }

    func testTraceChapterCarriesReusableFactsWithoutChangingFreeLifeMarks() {
        let previous = [
            item("上周咖啡", category: .dining, day: 13),
            item("上周地铁", category: .transport, day: 14),
        ]
        let current = [
            item("本周咖啡", category: .dining, day: 20),
            item("本周拿铁", category: .dining, day: 21),
            item("本周地铁", category: .transport, day: 21),
        ]
        let allItems = previous + current
        let snapshot = TraceSnapshotComputation.buildChapter(
            TraceChapterComputationInput(
                range: .week,
                items: current,
                allItems: allItems,
                isMember: false,
                prioritizeRecurringMarks: false,
                periodKey: "2026-W30",
                usesEchoAnchor: false,
                sourceRevision: 46,
                now: date(21)
            )
        )
        let expectedFreeMarks = LifeMarkService.aggregates(
            for: current,
            allItems: allItems,
            isMember: false,
            now: date(21),
            limit: 8
        )
        let preparedContext = LifeMarkService.prepareAggregationContext(
            allItems: allItems,
            periodItems: current
        )
        let preparedMarkSets = LifeMarkService.preparedAggregateSets(
            for: current,
            preparedContext: preparedContext,
            visibleIsMember: false,
            visibleLimit: 8,
            memberLimit: 24
        )
        let expectedMemberMarks = LifeMarkService.aggregates(
            for: current,
            allItems: allItems,
            isMember: true,
            now: date(21),
            limit: 24
        )

        XCTAssertEqual(snapshot.periodFacts.narrativePlan, snapshot.narrativePlan)
        XCTAssertEqual(snapshot.periodFacts.lifeMarks, expectedFreeMarks)
        XCTAssertEqual(preparedMarkSets.visible, expectedFreeMarks)
        XCTAssertEqual(preparedMarkSets.member, expectedMemberMarks)
        XCTAssertEqual(Set(snapshot.periodFacts.periodItems.map(\.id)), Set(current.map(\.id)))
        XCTAssertTrue(snapshot.periodFacts.matches(
            range: .week,
            sourceRevision: 46,
            isMember: false,
            now: date(21)
        ))
        XCTAssertFalse(snapshot.periodFacts.matches(
            range: .week,
            sourceRevision: 46,
            isMember: true,
            now: date(21)
        ))
    }

    func testNarrativePhotoLeadIsAlsoThePrimaryVisibleAnchor() {
        let earlier = HomeItem(
            title: "月初聚餐",
            amount: 80,
            category: .dining,
            createdAt: date(2),
            memoryImageData: Data([0x01]),
            memoryAnchorRole: .moment,
            memoryAnchorSceneHint: .gathering
        )
        let later = HomeItem(
            title: "红汤馄饨",
            amount: 20,
            category: .dining,
            createdAt: date(21),
            memoryImageData: Data([0x02]),
            memoryAnchorRole: .moment,
            memoryAnchorSceneHint: .experience
        )
        let snapshot = TraceSnapshotComputation.buildChapter(
            TraceChapterComputationInput(
                range: .month,
                items: [earlier, later],
                allItems: [earlier, later],
                isMember: true,
                prioritizeRecurringMarks: true,
                periodKey: "2026-07",
                usesEchoAnchor: false,
                sourceRevision: 43,
                now: date(21)
            )
        )

        XCTAssertEqual(snapshot.narrativePlan.leadSignalID, "photo:\(later.id.uuidString)")
        XCTAssertEqual(snapshot.memoryAnchors.first?.itemID, later.id)
        XCTAssertEqual(snapshot.coverFacts.coverItemID, later.id)
    }

    func testWeekClueKeepsAdministrativeBillsOutOfTheLifeMarkList() {
        let rows = [
            item("手机话费", category: .daily, day: 18),
            item("电费缴费", category: .home, day: 19),
            item("上午咖啡", category: .dining, day: 20),
            item("下午拿铁", category: .dining, day: 21),
        ]
        let snapshot = TraceSnapshotComputation.buildClue(
            TraceClueComputationInput(
                items: rows,
                allItems: rows,
                period: .week,
                periodLabel: "这一周",
                isMember: true,
                freeRemaining: 5,
                storedUnlock: true,
                sourceRevision: 5,
                narrativeScope: .week,
                allowsNarrativeRewrite: false,
                now: date(21)
            )
        )

        XCTAssertTrue(snapshot.narrativePlan?.markLabels.contains("咖啡饮品") == true)
        XCTAssertFalse(snapshot.marks.contains { mark in
            let evidence = rows.filter { mark.itemIDs.contains($0.id) }
            return !evidence.isEmpty && evidence.allSatisfy {
                LifeNarrativeSignalPolicy.isAdministrativeRecord($0)
            }
        })
    }

    func testTraceSurfacesConsumeCachedRewriteWithoutChangingTheSelectedFacts() {
        LifeNarrativeAIRewriteStore.shared.removeAllForTesting()
        defer { LifeNarrativeAIRewriteStore.shared.removeAllForTesting() }

        let rows = [
            item("一杯咖啡", category: .dining, day: 20),
            item(
                "红汤馄饨",
                category: .dining,
                day: 21,
                hasPhoto: true,
                photoRole: .moment
            ),
        ]
        let key = LifeNarrativeAIPreparationPolicy.key(
            scope: .week,
            sourceRevision: 77,
            now: date(21),
            calendar: PlaybackService.isoCalendar
        )
        let rewrite = LifeNarrativeAIRewrite(
            key: key,
            headline: "这周先说一件具体的事",
            summary: "7月21日那笔记录，还留着一张照片。",
            supportingLine: nil,
            evidenceIDs: ["F1"],
            evidenceItemIDs: [rows[1].id]
        )
        LifeNarrativeAIRewriteStore.shared.publish([rewrite], expectedSourceRevision: 77)

        let chapter = TraceSnapshotComputation.buildChapter(
            TraceChapterComputationInput(
                range: .week,
                items: rows,
                allItems: rows,
                isMember: true,
                prioritizeRecurringMarks: false,
                periodKey: "2026-W30",
                usesEchoAnchor: false,
                sourceRevision: 77,
                now: date(21)
            )
        )
        let snapshot = TraceSnapshotComputation.buildClue(
            TraceClueComputationInput(
                items: rows,
                allItems: rows,
                period: .week,
                periodLabel: "这一周",
                isMember: true,
                freeRemaining: 5,
                storedUnlock: true,
                sourceRevision: 77,
                narrativeScope: .week,
                allowsNarrativeRewrite: true,
                now: date(21)
            )
        )

        XCTAssertEqual(chapter.narrativeRewrite, rewrite)
        XCTAssertEqual(chapter.narrative, rewrite.headline)
        XCTAssertEqual(chapter.chapterSummary, rewrite.summary)
        XCTAssertEqual(chapter.narrativePlan.leadSignalID, "photo:\(rows[1].id.uuidString)")
        XCTAssertEqual(snapshot.narrativeRewrite, rewrite)
        XCTAssertEqual(snapshot.narrativeHeadline, snapshot.insight.leadQuestion)
        XCTAssertEqual(snapshot.narrativeSummary, snapshot.insight.previewLine)
        XCTAssertNotEqual(snapshot.narrativeHeadline, rewrite.headline)
        XCTAssertNotEqual(snapshot.narrativeSummary, rewrite.summary)
        XCTAssertTrue(snapshot.insight.fullLines.contains { $0.contains("直接依据") })
        XCTAssertEqual(snapshot.narrativePlan?.leadSignalID, "photo:\(rows[1].id.uuidString)")
        XCTAssertEqual(snapshot.narrativeRewrite?.evidenceItemIDs, [rows[1].id])

        let newerRevision = TraceSnapshotComputation.buildChapter(
            TraceChapterComputationInput(
                range: .week,
                items: rows,
                allItems: rows,
                isMember: true,
                prioritizeRecurringMarks: false,
                periodKey: "2026-W30",
                usesEchoAnchor: false,
                sourceRevision: 78,
                now: date(21)
            )
        )
        XCTAssertNil(newerRevision.narrativeRewrite)
        XCTAssertNotEqual(newerRevision.narrative, rewrite.headline)
    }

    func testSensitiveRecordNeverBecomesNarrativeLeadOrMark() {
        let rows = [
            item("医院复诊", category: .health, day: 20, userEdited: true, hasPhoto: true),
            item("下班通勤", category: .transport, day: 21),
        ]

        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 2,
                items: rows,
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        let published = plan.signalsByRole.values.flatMap { $0 }
        XCTAssertFalse(published.flatMap(\.evidenceItemIDs).contains(rows[0].id))
        XCTAssertFalse(plan.summary.contains("医院"))
    }

    func testSensitiveRecordCannotLeakThroughAMixedSceneEvidenceGroup() {
        let safe = item("午后咖啡", category: .dining, day: 20)
        let privateRow = item("医院旁买咖啡", category: .dining, day: 21, userEdited: true, hasPhoto: true)

        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 2,
                items: [safe, privateRow],
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        let publishedEvidenceIDs = plan.signalsByRole.values
            .flatMap { $0 }
            .flatMap(\.evidenceItemIDs)
        XCTAssertTrue(publishedEvidenceIDs.contains(safe.id))
        XCTAssertFalse(publishedEvidenceIDs.contains(privateRow.id))
        XCTAssertFalse(plan.summary.contains("医院"))
    }

    func testOnlySensitiveRecordsUsePrivateFallbackWithoutPublishingEvidence() {
        let privateRow = item("医院复诊", category: .health, day: 21, userEdited: true, hasPhoto: true)
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .day,
                sourceRevision: 1,
                items: [privateRow],
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertEqual(plan.maturity, .factual)
        XCTAssertNil(plan.leadSignalID)
        XCTAssertTrue(plan.signalsByRole.isEmpty)
        XCTAssertFalse(plan.summary.contains("医院"))
    }

    func testMaturitySeparatesWeakFactsFromContextAndEchoQualification() {
        XCTAssertEqual(LifeNarrativeSignalPolicy.maturity(recordCount: 0, activeDays: 0, hasPhoto: false), .empty)
        XCTAssertEqual(LifeNarrativeSignalPolicy.maturity(recordCount: 2, activeDays: 2, hasPhoto: false), .factual)
        XCTAssertEqual(LifeNarrativeSignalPolicy.maturity(recordCount: 2, activeDays: 2, hasPhoto: true), .contextual)
        XCTAssertEqual(LifeNarrativeSignalPolicy.maturity(recordCount: 5, activeDays: 3, hasPhoto: false), .echoEligible)
    }

    func testWeeklySharePayloadPreparesNarrativeOnceAndCoolsRepeatedCoffeeLead() {
        let previous = [
            item("上周咖啡 1", category: .dining, day: 13),
            item("上周咖啡 2", category: .dining, day: 14),
        ]
        let current = [
            item("本周咖啡 1", category: .dining, day: 20),
            item("本周咖啡 2", category: .dining, day: 21),
        ]

        let payload = PlaybackService().buildWeeklyShareCardPayload(
            from: previous + current,
            now: date(21),
            sourceRevision: 42
        )

        XCTAssertEqual(payload?.narrativePlan?.sourceRevision, 42)
        XCTAssertNotEqual(payload?.narrativePlan?.leadSignalID, "scene:coffee")
        XCTAssertTrue(payload?.narrativePlan?.markLabels.contains("咖啡饮品") == true)
    }
}

final class LifeNarrativeEchoPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int = 12, month: Int = 7) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func item(
        _ title: String,
        category: HomeItem.Category,
        month: Int = 7,
        day: Int,
        hour: Int = 12
    ) -> HomeItem {
        HomeItem(title: title, amount: 12, category: category, createdAt: date(day, hour, month: month))
    }

    func testContinuousCoffeeAloneDoesNotCreateAWeeklyEcho() {
        let rows = [6, 7, 13, 14, 20, 21].map {
            item("咖啡", category: .dining, day: $0, hour: 14)
        }
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 1,
                items: rows,
                now: date(21, 20),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertNil(echo)
    }

    func testEchoIgnoresRowsOutsideTwelvePeriodWindowAtReleaseScale() {
        let historical = [6, 7].map {
            item("看电影", category: .entertainment, day: $0, hour: 19)
        }
        let current = [20, 21].map {
            item("看电影", category: .entertainment, day: $0, hour: 19)
        }
        let relevantRows = historical + current
        let ancientRows = (0..<5_000).map { index in
            item(
                "很早的记录 \(index)",
                category: index.isMultiple(of: 2) ? .dining : .shopping,
                month: 1,
                day: (index % 28) + 1,
                hour: index % 24
            )
        }
        let baseline = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 5_000,
                items: relevantRows,
                now: date(21, 20),
                recentEchoIDs: []
            ),
            calendar: calendar
        )
        let withAncientHistory = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 5_000,
                items: ancientRows + relevantRows,
                now: date(21, 20),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertEqual(baseline?.kind, .returnAfterGap)
        XCTAssertEqual(withAncientHistory, baseline)
    }

    func testCoffeeCanCreateAnEchoForAComparableRealChange() {
        let previous = [13, 14].map { item("咖啡", category: .dining, day: $0, hour: 14) }
        let current = [20, 20, 21, 21].enumerated().map { index, day in
            item("咖啡 \(index)", category: .dining, day: day, hour: 9 + index)
        }
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 9,
                items: previous + current,
                now: date(21, 20),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertEqual(echo?.kind, .comparableChange)
        XCTAssertEqual(echo?.currentCount, 4)
        XCTAssertEqual(echo?.baselineCount, 2)
        XCTAssertTrue(echo?.line.contains("多了 2 笔") == true)
    }

    func testReturnRequiresARealGapAndCanBeCooledByStableEchoID() {
        let historical = [6, 7].map { item("看电影", category: .entertainment, day: $0, hour: 19) }
        let current = [20, 21].map { item("看电影", category: .entertainment, day: $0, hour: 19) }
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 4,
                items: historical + current,
                now: date(21, 20),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertEqual(echo?.kind, .returnAfterGap)
        XCTAssertEqual(echo?.periodGap, 1)
        XCTAssertTrue(echo?.line.contains("再次出现") == true)

        let cooled = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 4,
                items: historical + current,
                now: date(21, 20),
                recentEchoIDs: [echo?.id ?? ""]
            ),
            calendar: calendar
        )
        XCTAssertNil(cooled)
    }

    func testRepeatRhythmNeedsThreeMatchingWeekdaysAndRejectsOldRevision() {
        let rows = [
            item("上班地铁", category: .transport, day: 6, hour: 8),
            item("上班地铁", category: .transport, day: 13, hour: 8),
            item("上班地铁", category: .transport, day: 20, hour: 8),
            item("下班地铁", category: .transport, day: 21, hour: 18),
        ]
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 18,
                items: rows,
                now: date(21, 20),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertEqual(echo?.kind, .repeatRhythm)
        XCTAssertTrue(echo?.line.contains("周一") == true)
        XCTAssertTrue(LifeNarrativeEchoPublicationPolicy.accepts(echo, expectedSourceRevision: 18))
        XCTAssertFalse(LifeNarrativeEchoPublicationPolicy.accepts(echo, expectedSourceRevision: 19))
    }

    func testMonthChangeUsesTheSameElapsedMonthDays() {
        let current = [2, 4, 6].map { item("买相机配件", category: .shopping, day: $0) }
        var previous = [item("买相机配件", category: .shopping, month: 6, day: 3)]
        previous += [20, 21, 22, 23].map {
            item("买相机配件", category: .shopping, month: 6, day: $0)
        }
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .month,
                sourceRevision: 6,
                items: previous + current,
                now: date(10, 20),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertEqual(echo?.kind, .comparableChange)
        XCTAssertEqual(echo?.currentCount, 3)
        XCTAssertEqual(echo?.baselineCount, 1)
    }

    func testEchoPublishesOnlyOneDeterministicCandidateAndExcludesSensitiveEvidence() {
        let previous = [
            item("咖啡", category: .dining, day: 13),
            item("咖啡", category: .dining, day: 14),
            item("上班地铁", category: .transport, day: 13, hour: 8),
            item("下班地铁", category: .transport, day: 14, hour: 18),
        ]
        let currentCoffee = [20, 20, 21, 21].enumerated().map { index, day in
            item("咖啡 \(index)", category: .dining, day: day, hour: 9 + index)
        }
        let currentCommute = [20, 20, 21, 21].enumerated().map { index, day in
            item(index.isMultiple(of: 2) ? "上班地铁" : "下班地铁", category: .transport, day: day, hour: 8 + index)
        }
        let sensitive = item("医院旁买咖啡", category: .dining, day: 21, hour: 16)
        let input = LifeNarrativeEchoInput(
            scope: .week,
            sourceRevision: 30,
            items: previous + currentCoffee + currentCommute + [sensitive],
            now: date(21, 20),
            recentEchoIDs: []
        )

        let first = LifeNarrativeEchoPolicy.makeEcho(input, calendar: calendar)
        let second = LifeNarrativeEchoPolicy.makeEcho(input, calendar: calendar)

        XCTAssertEqual(first, second)
        XCTAssertNotNil(first)
        XCTAssertFalse(first?.currentEvidenceItemIDs.contains(sensitive.id) == true)
        XCTAssertFalse(first?.historicalEvidenceItemIDs.contains(sensitive.id) == true)
    }

    func testLateCommuteReturnsOnlyWithTwoCurrentAndHistoricalDays() {
        let historical = [1, 2].map {
            item("下班地铁", category: .transport, day: $0, hour: 22)
        }
        let current = [20, 21].map {
            item("晚高峰通勤", category: .transport, day: $0, hour: 22)
        }
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 51,
                items: historical + current,
                now: date(21, 23),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertEqual(echo?.kind, .contextReturn)
        XCTAssertEqual(echo?.periodGap, 3)
        XCTAssertEqual(echo?.currentDistinctDayCount, 2)
        XCTAssertEqual(echo?.historicalDistinctDayCount, 2)
        XCTAssertTrue(echo?.line.contains("重新出现") == true)
        XCTAssertTrue(echo?.line.contains("3 周前") == true)
    }

    func testLateCommuteReturnAbstainsWhenEitherSideHasOnlyOneDay() {
        let historicalTwoDays = [1, 2].map {
            item("下班地铁", category: .transport, day: $0, hour: 22)
        }
        let currentOneDay = [
            item("晚高峰通勤", category: .transport, day: 20, hour: 22),
            item("普通午餐", category: .dining, day: 21, hour: 12),
        ]
        let currentSparse = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 52,
                items: historicalTwoDays + currentOneDay,
                now: date(21, 23),
                recentEchoIDs: []
            ),
            calendar: calendar
        )
        XCTAssertNotEqual(currentSparse?.kind, .contextReturn)

        let historicalOneDay = [item("下班地铁", category: .transport, day: 1, hour: 22)]
        let currentTwoDays = [20, 21].map {
            item("晚高峰通勤", category: .transport, day: $0, hour: 22)
        }
        let historySparse = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 53,
                items: historicalOneDay + currentTwoDays,
                now: date(21, 23),
                recentEchoIDs: []
            ),
            calendar: calendar
        )
        XCTAssertNotEqual(historySparse?.kind, .contextReturn)
    }

    func testParkingAndTravelDoNotBecomeLateCommuteContext() {
        let historical = [1, 2].flatMap { day in
            [
                item("停车费", category: .transport, day: day, hour: 22),
                item("机场打车", category: .transport, day: day, hour: 23),
            ]
        }
        let current = [20, 21].flatMap { day in
            [
                item("停车费", category: .transport, day: day, hour: 22),
                item("旅行返程打车", category: .transport, day: day, hour: 23),
            ]
        }
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 54,
                items: historical + current,
                now: date(21, 23),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertNotEqual(echo?.kind, .contextReturn)
        XCTAssertFalse(echo?.label.contains("晚间通勤") == true)
    }

    func testNewCoffeeLateCommutePairNeedsTwoDaysAndFourActiveHistoryWeeks() {
        let baseline = [22, 29].map {
            item("普通午餐", category: .dining, month: 6, day: $0, hour: 12)
        } + [6, 13].map {
            item("普通午餐", category: .dining, day: $0, hour: 12)
        }
        let current = [20, 21].flatMap { day in
            [
                item("下班通勤", category: .transport, day: day, hour: 22),
                item("夜间咖啡", category: .dining, day: day, hour: 23),
            ]
        }
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 55,
                items: baseline + current,
                now: date(21, 23),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertEqual(echo?.kind, .newContextPair)
        XCTAssertEqual(echo?.currentDistinctDayCount, 2)
        XCTAssertEqual(echo?.baselinePeriodCount, 4)
        XCTAssertTrue(echo?.line.contains("晚间通勤之后") == true)
        XCTAssertTrue(echo?.line.contains("近 4 个有记录的周里") == true)
    }

    func testNewPairAbstainsForOneDayOrWhenHistoryAlreadyContainsThePair() {
        let baseline = [22, 29].map {
            item("普通午餐", category: .dining, month: 6, day: $0, hour: 12)
        } + [6, 13].map {
            item("普通午餐", category: .dining, day: $0, hour: 12)
        }
        let oneDayPair = [
            item("下班通勤", category: .transport, day: 20, hour: 22),
            item("夜间咖啡", category: .dining, day: 20, hour: 23),
            item("普通午餐", category: .dining, day: 21, hour: 12),
        ]
        let sparse = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 56,
                items: baseline + oneDayPair,
                now: date(21, 23),
                recentEchoIDs: []
            ),
            calendar: calendar
        )
        XCTAssertNotEqual(sparse?.kind, .newContextPair)

        let historicalPair = [
            item("下班通勤", category: .transport, day: 13, hour: 22),
            item("夜间咖啡", category: .dining, day: 13, hour: 23),
        ]
        let currentTwoDays = [20, 21].flatMap { day in
            [
                item("下班通勤", category: .transport, day: day, hour: 22),
                item("夜间咖啡", category: .dining, day: day, hour: 23),
            ]
        }
        let repeated = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 57,
                items: baseline + historicalPair + currentTwoDays,
                now: date(21, 23),
                recentEchoIDs: []
            ),
            calendar: calendar
        )
        XCTAssertNotEqual(repeated?.kind, .newContextPair)
        XCTAssertFalse(repeated?.line.contains("首次") == true)
    }

    func testMixedPairOrderNeverClaimsAfter() {
        let baseline = [22, 29].map {
            item("普通午餐", category: .dining, month: 6, day: $0, hour: 12)
        } + [6, 13].map {
            item("普通午餐", category: .dining, day: $0, hour: 12)
        }
        let current = [
            item("下班通勤", category: .transport, day: 20, hour: 22),
            item("夜间咖啡", category: .dining, day: 20, hour: 23),
            item("夜间咖啡", category: .dining, day: 21, hour: 21),
            item("下班通勤", category: .transport, day: 21, hour: 22),
        ]
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 58,
                items: baseline + current,
                now: date(21, 23),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertEqual(echo?.kind, .newContextPair)
        XCTAssertTrue(echo?.line.contains("一起出现") == true)
        XCTAssertFalse(echo?.line.contains("之后") == true)
    }

    func testRelationshipIdentityIsSharedByLifeCardClueAndShareProjection() {
        let baseline = [22, 29].map {
            item("普通午餐", category: .dining, month: 6, day: $0, hour: 12)
        } + [6, 13].map {
            item("普通午餐", category: .dining, day: $0, hour: 12)
        }
        let current = [20, 21].flatMap { day in
            [
                item("下班通勤", category: .transport, day: day, hour: 22),
                item("夜间咖啡", category: .dining, day: day, hour: 23),
            ]
        }
        let allItems = baseline + current
        let chapter = TraceSnapshotComputation.buildChapter(
            TraceChapterComputationInput(
                range: .week,
                items: current,
                allItems: allItems,
                isMember: true,
                prioritizeRecurringMarks: false,
                periodKey: "2026-W30",
                usesEchoAnchor: false,
                sourceRevision: 59,
                now: date(21, 23)
            )
        )
        let clue = TraceSnapshotComputation.buildClue(
            TraceClueComputationInput(
                items: current,
                allItems: allItems,
                period: .week,
                periodLabel: "这一周",
                isMember: true,
                freeRemaining: 5,
                storedUnlock: true,
                sourceRevision: 59,
                narrativeScope: .week,
                allowsNarrativeRewrite: false,
                now: date(21, 23)
            )
        )
        let sharePlan = PlaybackService().buildWeeklyShareCardPayload(
            from: allItems,
            now: date(21, 23),
            sourceRevision: 59
        )?.narrativePlan

        XCTAssertEqual(chapter.narrativePlan.leadSignalID, clue.narrativePlan?.leadSignalID)
        XCTAssertEqual(chapter.narrativePlan.leadSignalID, sharePlan?.leadSignalID)
        XCTAssertTrue(chapter.narrativePlan.leadSignalID?.contains(":new-pair:") == true)
        XCTAssertTrue(chapter.narrativePlan.hasNarrativeLead)
        XCTAssertTrue(chapter.narrativePlan.markLabels.contains("咖啡饮品"))
        XCTAssertTrue(chapter.chapterSummary?.contains("近 4 个有记录的周里") == true)
        XCTAssertTrue(clue.insight.fullLines.contains { $0.contains("历史基线覆盖 4 个有记录的周") })
    }
}

final class LifeJourneyFactRegressionTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 8,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func item(
        id: String,
        title: String,
        category: HomeItem.Category,
        day: Int,
        hour: Int,
        minute: Int = 0,
        city: String,
        semanticPlace: String
    ) -> HomeItem {
        HomeItem(
            id: UUID(uuidString: id)!,
            title: title,
            amount: 28,
            category: category,
            createdAt: date(day, hour, minute: minute),
            memoryContext: HomeItem.MemoryContext(
                weatherKind: nil,
                temperatureCelsius: nil,
                cityName: city,
                semanticPlace: semanticPlace
            )
        )
    }

    private func journeyRows() -> [HomeItem] {
        [
            item(
                id: "A1000000-0000-0000-0000-000000000001",
                title: "南京电车充电",
                category: .transport,
                day: 20,
                hour: 8,
                city: "南京",
                semanticPlace: "本城"
            ),
            item(
                id: "A1000000-0000-0000-0000-000000000002",
                title: "到宿迁的过路费",
                category: .transport,
                day: 20,
                hour: 11,
                city: "宿迁",
                semanticPlace: "外地"
            ),
            item(
                id: "A1000000-0000-0000-0000-000000000003",
                title: "宿迁电车充电",
                category: .transport,
                day: 21,
                hour: 9,
                city: "宿迁",
                semanticPlace: "外地"
            ),
            item(
                id: "A1000000-0000-0000-0000-000000000004",
                title: "到连云港的过路费",
                category: .transport,
                day: 22,
                hour: 11,
                city: "连云港",
                semanticPlace: "外地"
            ),
            item(
                id: "A1000000-0000-0000-0000-000000000005",
                title: "连云港吃海鲜",
                category: .dining,
                day: 22,
                hour: 13,
                city: "连云港",
                semanticPlace: "外地"
            ),
            item(
                id: "A1000000-0000-0000-0000-000000000006",
                title: "徐记花甲鸡爪｜宿豫店",
                category: .dining,
                day: 22,
                hour: 22,
                city: "宿迁",
                semanticPlace: "外地"
            ),
            item(
                id: "A1000000-0000-0000-0000-000000000007",
                title: "周日返南京过路费",
                category: .transport,
                day: 23,
                hour: 17,
                city: "南京",
                semanticPlace: "本城"
            ),
        ]
    }

    private func delayedReturnRows(
        returnTitle: String = "过路费回南京",
        returnHour: Int = 18,
        returnMinute: Int = 26
    ) -> [HomeItem] {
        [
            item(
                id: "A3000000-0000-0000-0000-000000000001",
                title: "南京电车充电",
                category: .transport,
                day: 20,
                hour: 8,
                city: "南京",
                semanticPlace: "本城"
            ),
            item(
                id: "A3000000-0000-0000-0000-000000000002",
                title: "到宿迁的过路费",
                category: .transport,
                day: 20,
                hour: 11,
                city: "宿迁",
                semanticPlace: "外地"
            ),
            item(
                id: "A3000000-0000-0000-0000-000000000003",
                title: "连云港吃海鲜",
                category: .dining,
                day: 22,
                hour: 13,
                city: "连云港",
                semanticPlace: "外地"
            ),
            item(
                id: "A3000000-0000-0000-0000-000000000004",
                title: "宿迁夜宵",
                category: .dining,
                day: 22,
                hour: 22,
                city: "宿迁",
                semanticPlace: "外地"
            ),
            item(
                id: "A3000000-0000-0000-0000-000000000005",
                title: "卤味",
                category: .dining,
                day: 23,
                hour: 18,
                minute: 25,
                city: "南京",
                semanticPlace: "本城"
            ),
            item(
                id: "A3000000-0000-0000-0000-000000000006",
                title: "修电瓶车",
                category: .other,
                day: 23,
                hour: 18,
                minute: 25,
                city: "南京",
                semanticPlace: "本城"
            ),
            item(
                id: "A3000000-0000-0000-0000-000000000007",
                title: returnTitle,
                category: .transport,
                day: 23,
                hour: returnHour,
                minute: returnMinute,
                city: "南京",
                semanticPlace: "本城"
            ),
            item(
                id: "A3000000-0000-0000-0000-000000000008",
                title: "手机话费",
                category: .daily,
                day: 23,
                hour: 19,
                city: "南京",
                semanticPlace: "本城"
            ),
            item(
                id: "A3000000-0000-0000-0000-000000000009",
                title: "次日咖啡",
                category: .dining,
                day: 24,
                hour: 9,
                city: "南京",
                semanticPlace: "本城"
            ),
        ]
    }

    func testClosedWeekendRoadTripIsOneCertifiedFactAcrossClueChapterAndPlayback() {
        let rows = journeyRows()
        let now = date(23, 20)
        guard let fact = LifeJourneyFactService.primaryFact(in: rows, calendar: calendar) else {
            XCTFail("expected a closed road-trip fact")
            return
        }

        XCTAssertEqual(fact.routeCities, ["南京", "宿迁", "连云港", "宿迁", "南京"])
        XCTAssertTrue(fact.isRoadTrip)
        XCTAssertTrue(fact.isClosedLoop)
        XCTAssertEqual(fact.label, "周末跨城自驾")
        XCTAssertTrue(fact.line.contains("最后回到南京"))
        XCTAssertFalse(fact.line.contains("老家"))

        let chapter = TraceSnapshotComputation.buildChapter(
            TraceChapterComputationInput(
                range: .week,
                items: rows,
                allItems: rows,
                isMember: true,
                prioritizeRecurringMarks: false,
                periodKey: "2026-W34",
                usesEchoAnchor: false,
                sourceRevision: 91,
                now: now
            )
        )
        let clue = TraceSnapshotComputation.buildClue(
            TraceClueComputationInput(
                items: rows,
                allItems: rows,
                period: .week,
                periodLabel: "这一周",
                isMember: true,
                freeRemaining: 5,
                storedUnlock: true,
                sourceRevision: 91,
                narrativeScope: .week,
                allowsNarrativeRewrite: true,
                now: now
            )
        )
        let service = PlaybackService()
        let playback = service.buildWeekSummary(from: chapter.periodFacts, copySeed: "journey")
        let sharePlan = service.buildWeeklyShareCardPayload(
            from: rows,
            now: now,
            sourceRevision: 91
        )?.narrativePlan
        let outroSupport = playback.chapters.first { $0.id == "week-outro" }?.metrics["supportLine"]

        XCTAssertEqual(chapter.periodFacts.journeyFact, Optional(fact))
        XCTAssertEqual(clue.journeyFact, Optional(fact))
        XCTAssertEqual(chapter.narrativePlan.leadSignalID, Optional(fact.id))
        XCTAssertEqual(clue.narrativePlan?.leadSignalID, Optional(fact.id))
        XCTAssertEqual(sharePlan?.leadSignalID, Optional(fact.id))
        XCTAssertEqual(
            sharePlan?.signalsByRole[.lead]?.first?.evidenceItemIDs,
            Optional(fact.evidenceItemIDs)
        )
        XCTAssertEqual(outroSupport, Optional(fact.line))
        XCTAssertEqual(clue.insight.theme, .relation)
        XCTAssertEqual(clue.insight.previewLine, fact.line)
        XCTAssertTrue(clue.insight.fullLines.contains { line in
            line.contains("共 \(fact.evidenceItemIDs.count) 笔记录")
                && line.contains("道路")
                && line.contains("异地活动")
        })
        XCTAssertFalse(clue.insight.leadQuestion.contains("变化来自哪些记录"))
        XCTAssertNil(clue.narrativeRewrite)
    }

    func testExplicitReturnRoadAnchorAfterOrdinaryHomeRowsCompletesTheJourney() {
        let rows = delayedReturnRows()
        let returnID = rows[6].id
        let firstHomeID = rows[4].id
        let excludedIDs = Set([rows[5].id, rows[7].id, rows[8].id])
        guard let fact = LifeJourneyFactService.primaryFact(in: rows, calendar: calendar) else {
            XCTFail("expected a delayed explicit return anchor")
            return
        }

        XCTAssertEqual(fact.routeCities, ["南京", "宿迁", "连云港", "宿迁", "南京"])
        XCTAssertTrue(fact.isClosedLoop)
        XCTAssertEqual(fact.endDate, rows[6].createdAt)
        XCTAssertTrue(fact.roadEvidenceItemIDs.contains(returnID))
        XCTAssertTrue(fact.evidenceItemIDs.contains(returnID))
        XCTAssertTrue(fact.boundaryEvidenceItemIDs.contains(firstHomeID))
        XCTAssertTrue(excludedIDs.isDisjoint(with: fact.evidenceItemIDs))
        XCTAssertEqual(
            LifeJourneyFactService.primaryFact(in: Array(rows.reversed()), calendar: calendar),
            Optional(fact)
        )

        let discover = TraceSnapshotComputation.buildDiscoverSnapshot(
            items: rows,
            sourceRevision: 93,
            now: date(24, 12),
            calendar: calendar,
            journeyFact: fact
        )
        let card = try! XCTUnwrap(
            discover.recentDiscoveries.first { $0.title == "周末跨城自驾" }
        )
        XCTAssertTrue(card.coreEvidenceItemIDs?.contains(returnID) == true)
        XCTAssertFalse(card.boundaryEvidenceItemIDs?.contains(returnID) == true)
        XCTAssertEqual(
            Set((card.coreEvidenceItemIDs ?? []) + (card.boundaryEvidenceItemIDs ?? [])),
            Set(card.evidenceItemIDs)
        )
    }

    func testExplicitReturnDestinationSupportsArrivalWording() {
        let rows = delayedReturnRows(returnTitle: "到南京的过路费")
        let fact = try! XCTUnwrap(LifeJourneyFactService.primaryFact(in: rows, calendar: calendar))

        XCTAssertEqual(fact.endDate, rows[6].createdAt)
        XCTAssertTrue(fact.roadEvidenceItemIDs.contains(rows[6].id))
    }

    func testReturnCompletionRejectsWrongDirectionAndLateAnchors() {
        for rows in [
            delayedReturnRows(returnTitle: "从南京回宿迁的过路费"),
            delayedReturnRows(returnTitle: "未到南京的过路费"),
            delayedReturnRows(returnTitle: "到南京后继续去宿迁的过路费"),
            delayedReturnRows(returnTitle: "到南京后去宿迁的过路费"),
            delayedReturnRows(returnTitle: "到南京后开往宿迁的过路费"),
            delayedReturnRows(returnHour: 22, returnMinute: 0),
        ] {
            let fact = try! XCTUnwrap(LifeJourneyFactService.primaryFact(in: rows, calendar: calendar))
            XCTAssertTrue(fact.isClosedLoop)
            XCTAssertEqual(fact.endDate, rows[4].createdAt)
            XCTAssertFalse(fact.evidenceItemIDs.contains(rows[6].id))
            XCTAssertFalse(fact.roadEvidenceItemIDs.contains(rows[6].id))
            XCTAssertFalse(fact.evidenceItemIDs.contains(rows[8].id))
        }
    }

    func testReturnCompletionStopsBeforeTheNextDeparture() {
        for departureID in [
            "A3000000-0000-0000-0000-000000000000",
            "A3000000-0000-0000-0000-000000000010",
        ] {
            var rows = delayedReturnRows(returnMinute: 26)
            let returnID = rows[6].id
            let departure = item(
                id: departureID,
                title: "再次离城",
                category: .other,
                day: 23,
                hour: 18,
                minute: 26,
                city: "宿迁",
                semanticPlace: "外地"
            )
            rows.append(departure)
            let fact = try! XCTUnwrap(
                LifeJourneyFactService.primaryFact(in: rows, calendar: calendar)
            )

            XCTAssertEqual(fact.routeCities, ["南京", "宿迁", "连云港", "宿迁", "南京"])
            XCTAssertEqual(fact.endDate, rows[4].createdAt)
            XCTAssertFalse(fact.evidenceItemIDs.contains(returnID))
            XCTAssertFalse(fact.evidenceItemIDs.contains(departure.id))
        }
    }

    func testReturnCompletionCannotInvalidateAJourneyAtTheMaximumDurationBoundary() {
        var rows = delayedReturnRows(returnHour: 20, returnMinute: 30)
        rows[0].createdAt = date(18, 19, minute: 30)
        rows[1].createdAt = date(19, 11)
        rows[2].createdAt = date(21, 13)
        rows[3].createdAt = date(22, 13)
        let fact = try! XCTUnwrap(LifeJourneyFactService.primaryFact(in: rows, calendar: calendar))

        XCTAssertTrue(fact.isClosedLoop)
        XCTAssertEqual(fact.endDate, rows[4].createdAt)
        XCTAssertFalse(fact.evidenceItemIDs.contains(rows[6].id))
    }

    func testReturnCompletionRejectsAnExplicitTitleWithoutAHomeCityArrival() {
        var rows = Array(journeyRows().dropLast())
        var titleOnlyReturn = delayedReturnRows()[6]
        titleOnlyReturn.memoryContext = nil
        rows.append(titleOnlyReturn)
        let fact = try! XCTUnwrap(LifeJourneyFactService.primaryFact(in: rows, calendar: calendar))

        XCTAssertFalse(fact.isClosedLoop)
        XCTAssertFalse(fact.evidenceItemIDs.contains(titleOnlyReturn.id))
    }

    func testReturnCompletionDoesNotCrossTheCalendarDayBoundary() {
        var rows = Array(delayedReturnRows().prefix(7))
        rows[4].createdAt = date(23, 23, minute: 58)
        rows[5].createdAt = date(23, 23, minute: 58)
        rows[6].createdAt = date(24, 0, minute: 1)
        let fact = try! XCTUnwrap(LifeJourneyFactService.primaryFact(in: rows, calendar: calendar))

        XCTAssertEqual(fact.endDate, rows[4].createdAt)
        XCTAssertFalse(fact.evidenceItemIDs.contains(rows[6].id))
    }

    func testDelayedRailReturnCompletesWithoutInventingARoadTrip() {
        let rows = [
            item(
                id: "A4000000-0000-0000-0000-000000000001",
                title: "南京高铁出发",
                category: .transport,
                day: 22,
                hour: 8,
                city: "南京",
                semanticPlace: "本城"
            ),
            item(
                id: "A4000000-0000-0000-0000-000000000002",
                title: "连云港吃海鲜",
                category: .dining,
                day: 22,
                hour: 12,
                city: "连云港",
                semanticPlace: "外地"
            ),
            item(
                id: "A4000000-0000-0000-0000-000000000003",
                title: "南京便利店",
                category: .daily,
                day: 22,
                hour: 19,
                city: "南京",
                semanticPlace: "本城"
            ),
            item(
                id: "A4000000-0000-0000-0000-000000000004",
                title: "高铁返南京",
                category: .transport,
                day: 22,
                hour: 19,
                minute: 5,
                city: "南京",
                semanticPlace: "本城"
            ),
        ]
        let fact = try! XCTUnwrap(LifeJourneyFactService.primaryFact(in: rows, calendar: calendar))

        XCTAssertTrue(fact.isClosedLoop)
        XCTAssertFalse(fact.isRoadTrip)
        XCTAssertEqual(fact.endDate, rows[3].createdAt)
        XCTAssertTrue(fact.evidenceItemIDs.contains(rows[3].id))
        XCTAssertFalse(fact.roadEvidenceItemIDs.contains(rows[3].id))
    }

    func testRemovingDelayedReturnAnchorRestoresTheCityBoundaryWithoutStaleEvidence() {
        let rows = delayedReturnRows()
        let returnID = rows[6].id
        let remaining = rows.filter { $0.id != returnID }
        let fact = try! XCTUnwrap(
            LifeJourneyFactService.primaryFact(in: remaining, calendar: calendar)
        )

        XCTAssertTrue(fact.isClosedLoop)
        XCTAssertEqual(fact.endDate, rows[4].createdAt)
        XCTAssertFalse(fact.evidenceItemIDs.contains(returnID))
        XCTAssertFalse(fact.roadEvidenceItemIDs.contains(returnID))
    }

    func testAICommandOutgoingTripQueryReusesCertifiedJourneyEvidence() {
        let rows = journeyRows()
        let now = date(23, 20)
        let recognition = InsightWebView.aiCommandRecognitionDigestForTesting(
            command: "出去玩",
            now: now
        )
        let result = InsightWebView.aiCommandComputationDigestForTesting(
            command: "出去玩",
            items: rows,
            hasMemberAccess: true,
            now: now
        )

        XCTAssertTrue(recognition.hasPrefix("query#"))
        XCTAssertTrue(recognition.contains("#travel#"))
        XCTAssertTrue(result.hasPrefix("query#过去 31 天的出去玩记录#"))
        for row in rows {
            XCTAssertTrue(result.contains(row.id.uuidString), row.title)
        }

        var uncertified = rows
        for index in uncertified.indices {
            uncertified[index].memoryContext = nil
            uncertified[index].title = "普通记录 \(index)"
        }
        let abstained = InsightWebView.aiCommandComputationDigestForTesting(
            command: "出去玩",
            items: uncertified,
            hasMemberAccess: true,
            now: now
        )
        XCTAssertTrue(abstained.hasPrefix("query#过去 31 天的出去玩记录#"))
        for row in uncertified {
            XCTAssertFalse(abstained.contains(row.id.uuidString), row.title)
        }

        let generatedHint = "这段跨城路线是怎样连起来的？"
        let routeRecognition = InsightWebView.aiCommandRecognitionDigestForTesting(
            command: generatedHint,
            now: now
        )
        let routeResult = InsightWebView.aiCommandComputationDigestForTesting(
            command: generatedHint,
            items: rows,
            hasMemberAccess: true,
            now: now
        )

        XCTAssertEqual(LifeMarkService.queryIntent(from: generatedHint)?.id, "travel")
        XCTAssertTrue(routeRecognition.hasPrefix("query#"))
        XCTAssertTrue(routeRecognition.contains("#travel#"))
        XCTAssertTrue(routeResult.hasPrefix("query#过去 31 天的跨城路线记录#"))
        for row in rows {
            XCTAssertTrue(routeResult.contains(row.id.uuidString), row.title)
        }

        uncertified[0].title = "旅行酒店"
        let outgoingFallback = InsightWebView.aiCommandComputationDigestForTesting(
            command: "出去玩",
            items: uncertified,
            hasMemberAccess: true,
            now: now
        )
        let routeAbstained = InsightWebView.aiCommandComputationDigestForTesting(
            command: generatedHint,
            items: uncertified,
            hasMemberAccess: true,
            now: now
        )
        XCTAssertTrue(outgoingFallback.contains(uncertified[0].id.uuidString))
        XCTAssertTrue(routeAbstained.hasPrefix("query#过去 31 天的跨城路线记录#"))
        for row in uncertified {
            XCTAssertFalse(routeAbstained.contains(row.id.uuidString), row.title)
        }
    }

    func testJourneyLanguageRequiresRoadReturnAndAwayActivityEvidence() {
        let railRows = [
            item(
                id: "A2000000-0000-0000-0000-000000000001",
                title: "南京高铁出发",
                category: .transport,
                day: 22,
                hour: 8,
                city: "南京",
                semanticPlace: "本城"
            ),
            item(
                id: "A2000000-0000-0000-0000-000000000002",
                title: "连云港海鲜",
                category: .dining,
                day: 22,
                hour: 12,
                city: "连云港",
                semanticPlace: "外地"
            ),
            item(
                id: "A2000000-0000-0000-0000-000000000003",
                title: "高铁返南京",
                category: .transport,
                day: 22,
                hour: 20,
                city: "南京",
                semanticPlace: "本城"
            ),
        ]
        guard let railFact = LifeJourneyFactService.primaryFact(in: railRows, calendar: calendar) else {
            XCTFail("expected a rail journey fact")
            return
        }
        XCTAssertFalse(railFact.isRoadTrip)
        XCTAssertTrue(railFact.isClosedLoop)
        XCTAssertFalse(railFact.label.contains("自驾"))
        XCTAssertFalse(railFact.line.contains("自驾"))

        guard let openFact = LifeJourneyFactService.primaryFact(
            in: Array(journeyRows().dropLast()),
            calendar: calendar
        ) else {
            XCTFail("expected an open journey fact")
            return
        }
        XCTAssertFalse(openFact.isClosedLoop)
        XCTAssertFalse(openFact.line.contains("最后回到"))
        XCTAssertFalse(openFact.line.contains("完成"))

        var noActivity = journeyRows()
        for index in noActivity.indices {
            noActivity[index].category = .transport
        }
        XCTAssertNil(LifeJourneyFactService.primaryFact(in: noActivity, calendar: calendar))

        let noRoadOrTransit = journeyRows().enumerated().map { index, row -> HomeItem in
            var value = row
            value.title = index == 4 ? "连云港吃海鲜" : "跨城记录 \(index)"
            return value
        }
        XCTAssertNil(LifeJourneyFactService.primaryFact(in: noRoadOrTransit, calendar: calendar))
    }

    func testJourneyFactsStayLocalAndDeterministicAtReleaseScales() {
        let base = journeyRows()
        let delayedBase = delayedReturnRows()
        let now = date(23, 20)
        guard let expected = LifeJourneyFactService.primaryFact(in: base, calendar: calendar) else {
            XCTFail("expected a deterministic journey fact")
            return
        }
        XCTAssertEqual(LifeJourneyFactService.allFacts(in: base, calendar: calendar).first, expected)
        guard let delayedExpected = LifeJourneyFactService.primaryFact(
            in: delayedBase,
            calendar: calendar
        ) else {
            XCTFail("expected a deterministic delayed-return journey fact")
            return
        }

        for count in [100, 1_000, 5_000] {
            let unrelated = ReleaseFixtureFactory.makeItems(count: count).map { row -> HomeItem in
                var value = row
                value.memoryContext = nil
                return value
            }
            let first = LifeJourneyFactService.primaryFact(in: unrelated + base, calendar: calendar)
            let second = LifeJourneyFactService.primaryFact(in: base + unrelated, calendar: calendar)
            XCTAssertEqual(first, Optional(expected), "count=\(count)")
            XCTAssertEqual(second, Optional(expected), "count=\(count)")
            let delayedFirst = LifeJourneyFactService.primaryFact(
                in: unrelated + delayedBase,
                calendar: calendar
            )
            let delayedSecond = LifeJourneyFactService.primaryFact(
                in: delayedBase + unrelated,
                calendar: calendar
            )
            XCTAssertEqual(delayedFirst, Optional(delayedExpected), "delayed count=\(count)")
            XCTAssertEqual(delayedSecond, Optional(delayedExpected), "delayed count=\(count)")
        }

        let packs = LifeNarrativeAIPreparationPolicy.prepareFactPacks(
            items: base,
            sourceRevision: 92,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(LifeNarrativeAIPreparationPolicy.ruleVersion, 5)
        XCTAssertNil(packs.first { $0.key.scope == LifeNarrativeScope.week.rawValue })
        XCTAssertNil(packs.first { $0.key.scope == LifeNarrativeScope.month.rawValue })
    }
}

final class LifeNarrativeAIRewritePolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 20))!
    }

    private func preparedWeekPack(sourceRevision: Int = 12) -> PreparedLifeNarrativeAIFactPack {
        let rows = [
            HomeItem(
                title: "和小王吃了红汤馄饨",
                amount: 28,
                category: .dining,
                createdAt: calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 18))!,
                userEditedTitle: true,
                memoryImageData: Data([0x01]),
                memoryAnchorRole: .moment
            ),
            HomeItem(
                title: "下班地铁",
                amount: 4,
                category: .transport,
                createdAt: calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 18))!
            ),
            HomeItem(
                title: "医院复诊",
                amount: 120,
                category: .health,
                createdAt: calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 10))!,
                userEditedTitle: true,
                memoryImageData: Data([0x02])
            ),
        ]
        return LifeNarrativeAIPreparationPolicy.prepareFactPacks(
            items: rows,
            sourceRevision: sourceRevision,
            now: now,
            calendar: calendar
        ).first { $0.key.scope == LifeNarrativeScope.week.rawValue }!
    }

    private func preparedRelationshipPack(sourceRevision: Int = 72) -> PreparedLifeNarrativeAIFactPack {
        func row(_ title: String, category: HomeItem.Category, month: Int = 7, day: Int, hour: Int) -> HomeItem {
            HomeItem(
                title: title,
                amount: 12,
                category: category,
                createdAt: calendar.date(
                    from: DateComponents(year: 2026, month: month, day: day, hour: hour)
                )!
            )
        }
        let baseline = [22, 29].map {
            row("普通午餐", category: .dining, month: 6, day: $0, hour: 12)
        } + [6, 13].map {
            row("普通午餐", category: .dining, day: $0, hour: 12)
        }
        let current = [20, 21].flatMap { day in
            [
                row("下班通勤", category: .transport, day: day, hour: 22),
                row("夜间咖啡", category: .dining, day: day, hour: 23),
            ]
        }
        return LifeNarrativeAIPreparationPolicy.prepareFactPacks(
            items: baseline + current,
            sourceRevision: sourceRevision,
            now: calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 23))!,
            calendar: calendar
        ).first { $0.key.scope == LifeNarrativeScope.week.rawValue }!
    }

    func testFactPackRedactsUserTextSensitiveRowsPhotosAndLedgerIDs() throws {
        let pack = preparedWeekPack()
        let data = try JSONEncoder().encode(pack.request)
        let text = String(data: data, encoding: .utf8) ?? ""

        XCTAssertFalse(text.contains("用户自写记录"))
        XCTAssertFalse(text.contains("主动记录"))
        XCTAssertFalse(text.contains("用户主动写下"))
        XCTAssertTrue(text.contains("有真实照片的记录"))
        XCTAssertFalse(text.contains("小王"))
        XCTAssertFalse(text.contains("红汤馄饨"))
        XCTAssertFalse(text.contains("医院"))
        XCTAssertFalse(text.contains("memoryImage"))
        XCTAssertFalse(pack.itemIDsByFactID.values.flatMap { $0 }.contains { text.contains($0.uuidString) })
    }

    func testUserExpressionLeadStaysLocalInsteadOfBecomingAnAICountFact() {
        let expression = HomeItem(
            title: "终于到家",
            amount: 4,
            category: .transport,
            createdAt: calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 19))!,
            userEditedTitle: true
        )
        let packs = LifeNarrativeAIPreparationPolicy.prepareFactPacks(
            items: [expression],
            sourceRevision: 18,
            now: now,
            calendar: calendar
        )

        XCTAssertNil(packs.first { $0.key.scope == LifeNarrativeScope.week.rawValue })
        XCTAssertNil(packs.first { $0.key.scope == LifeNarrativeScope.month.rawValue })
    }

    func testWeakCompositionAndRhythmDoNotStartRemoteNarrativeRewrite() {
        let rows = [
            HomeItem(title: "普通午餐", amount: 18, category: .dining, createdAt: now),
            HomeItem(
                title: "普通日用",
                amount: 12,
                category: .daily,
                createdAt: calendar.date(byAdding: .hour, value: -2, to: now)!
            ),
        ]
        let packs = LifeNarrativeAIPreparationPolicy.prepareFactPacks(
            items: rows,
            sourceRevision: 70,
            now: now,
            calendar: calendar
        )

        XCTAssertNil(packs.first { $0.key.scope == LifeNarrativeScope.week.rawValue })
        XCTAssertNil(packs.first { $0.key.scope == LifeNarrativeScope.month.rawValue })
    }

    func testRelationshipFactPackUsesCertifiedModeAndKeepsBoundedClaims() {
        let pack = preparedRelationshipPack()
        XCTAssertEqual(pack.request.mode, "relationship")
        XCTAssertEqual(pack.request.facts.first?.role, "lead")
        XCTAssertEqual(pack.request.facts.first?.kind, LifeNarrativeEchoKind.newContextPair.rawValue)
        XCTAssertEqual(pack.localPlan.leadSignalID, pack.echo?.id)

        let valid = LifeNarrativeAIRewriteCandidate(
            scope: pack.key.scope,
            periodKey: pack.key.periodKey,
            headline: "这周有一组新关联",
            summary: "咖啡连续 2 天出现在晚间通勤之后，是近 4 个有记录周里的首次。",
            supportingLine: nil,
            evidenceIDs: ["F1"]
        )
        XCTAssertNotNil(LifeNarrativeAIRewriteValidationPolicy.validate(valid, against: pack))

        let unbounded = LifeNarrativeAIRewriteCandidate(
            scope: valid.scope,
            periodKey: valid.periodKey,
            headline: valid.headline,
            summary: "咖啡连续 2 天出现在晚间通勤之后，这是第一次。",
            supportingLine: nil,
            evidenceIDs: ["F1"]
        )
        XCTAssertNil(LifeNarrativeAIRewriteValidationPolicy.validate(unbounded, against: pack))

        let inventedReturn = LifeNarrativeAIRewriteCandidate(
            scope: valid.scope,
            periodKey: valid.periodKey,
            headline: valid.headline,
            summary: "咖啡和晚间通勤重新出现，是近 4 个有记录周里的首次。",
            supportingLine: nil,
            evidenceIDs: ["F1"]
        )
        XCTAssertNil(LifeNarrativeAIRewriteValidationPolicy.validate(inventedReturn, against: pack))
    }

    func testRewriteValidationRequiresLeadEvidenceAndRejectsNewFacts() {
        let pack = preparedWeekPack()
        let valid = LifeNarrativeAIRewriteCandidate(
            scope: pack.key.scope,
            periodKey: pack.key.periodKey,
            headline: "这周有一句自己的记录",
            summary: "一条具体记录和一段出行，按发生顺序放在这里。",
            supportingLine: nil,
            evidenceIDs: ["F1"]
        )
        XCTAssertNotNil(LifeNarrativeAIRewriteValidationPolicy.validate(valid, against: pack))

        let unknownEvidence = LifeNarrativeAIRewriteCandidate(
            scope: valid.scope,
            periodKey: valid.periodKey,
            headline: valid.headline,
            summary: valid.summary,
            supportingLine: nil,
            evidenceIDs: ["F9"]
        )
        XCTAssertNil(LifeNarrativeAIRewriteValidationPolicy.validate(unknownEvidence, against: pack))

        let inventedNumber = LifeNarrativeAIRewriteCandidate(
            scope: valid.scope,
            periodKey: valid.periodKey,
            headline: valid.headline,
            summary: "这周突然多了 99 笔新故事。",
            supportingLine: nil,
            evidenceIDs: ["F1"]
        )
        XCTAssertNil(LifeNarrativeAIRewriteValidationPolicy.validate(inventedNumber, against: pack))

        let inferredEmotion = LifeNarrativeAIRewriteCandidate(
            scope: valid.scope,
            periodKey: valid.periodKey,
            headline: valid.headline,
            summary: "这些记录终于治愈了这一周。",
            supportingLine: nil,
            evidenceIDs: ["F1"]
        )
        XCTAssertNil(LifeNarrativeAIRewriteValidationPolicy.validate(inferredEmotion, against: pack))
    }

    func testRewriteStoreRejectsOldRevisionAndPublishesCurrentResult() {
        let pack = preparedWeekPack(sourceRevision: 20)
        let candidate = LifeNarrativeAIRewriteCandidate(
            scope: pack.key.scope,
            periodKey: pack.key.periodKey,
            headline: "这周有一句自己的记录",
            summary: "一条具体记录和一段出行，按发生顺序放在这里。",
            supportingLine: nil,
            evidenceIDs: ["F1"]
        )
        let rewrite = LifeNarrativeAIRewriteValidationPolicy.validate(candidate, against: pack)!
        let store = LifeNarrativeAIRewriteStore.shared
        store.removeAllForTesting()
        defer { store.removeAllForTesting() }

        store.publish([rewrite], expectedSourceRevision: 19)
        XCTAssertNil(store.rewrite(for: pack.key))
        store.publish([rewrite], expectedSourceRevision: 20)
        XCTAssertEqual(store.rewrite(for: pack.key), rewrite)
        store.removeAll()
        XCTAssertNil(store.rewrite(for: pack.key))
    }
}

final class PlaybackLivingVoiceCopyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private func date(
        _ month: Int,
        _ day: Int,
        _ hour: Int = 12,
        _ minute: Int = 0,
        year: Int = 2026
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func item(
        _ title: String,
        amount: Double,
        category: HomeItem.Category,
        at createdAt: Date,
        emotion: String = "系统暖标签",
        memoryContext: HomeItem.MemoryContext? = nil
    ) -> HomeItem {
        HomeItem(
            title: title,
            amount: amount,
            category: category,
            createdAt: createdAt,
            emotionTag: emotion,
            userEditedTitle: true,
            memoryContext: memoryContext
        )
    }

    private func allNarration(_ playback: SummaryPlayback) -> String {
        playback.chapters
            .flatMap { [$0.narration.warm, $0.narration.plain] }
            .joined(separator: "\n")
    }

    func testPreparedWeekFactsReusePreservesPlaybackOutputAndIdentity() {
        let now = date(7, 15, 20)
        let rows = [
            item("上周早餐", amount: 13, category: .dining, at: date(7, 8, 8)),
            item("下班地铁", amount: 4.75, category: .transport, at: date(7, 13, 19, 20)),
            item("午饭", amount: 28, category: .dining, at: date(7, 15, 12, 20)),
            item("买纸巾", amount: 18, category: .daily, at: date(7, 15, 18, 10))
        ]
        let service = PlaybackService()
        let facts = service.preparePeriodExperienceFacts(
            from: rows,
            range: .week,
            now: now,
            sourceRevision: 44,
            isMember: false
        )
        let direct = service.buildWeekSummary(
            from: rows,
            now: now,
            copySeed: "reuse",
            sourceRevision: 44
        )
        let reused = service.buildWeekSummary(from: facts, copySeed: "reuse")

        XCTAssertEqual(reused, direct)
        XCTAssertTrue(facts.matches(range: .week, sourceRevision: 44, isMember: false, now: now))
        XCTAssertFalse(facts.matches(range: .week, sourceRevision: 44, isMember: true, now: now))
        XCTAssertFalse(facts.matches(range: .month, sourceRevision: 44, isMember: false, now: now))
        XCTAssertFalse(facts.matches(range: .week, sourceRevision: 45, isMember: false, now: now))
    }

    func testPreparedWeeklyShareSnapshotStaysBoundToPlaybackRevision() throws {
        let now = date(7, 15, 20)
        let rows = [
            item("上周早餐", amount: 13, category: .dining, at: date(7, 8, 8)),
            item("下班地铁", amount: 4.75, category: .transport, at: date(7, 13, 19, 20)),
            item("午饭", amount: 28, category: .dining, at: date(7, 15, 12, 20)),
            item("买纸巾", amount: 18, category: .daily, at: date(7, 15, 18, 10)),
        ]
        let service = PlaybackService()
        let facts = service.preparePeriodExperienceFacts(
            from: rows,
            range: .week,
            now: now,
            sourceRevision: 72,
            isMember: false
        )
        let playback = service.buildWeekSummary(from: facts, copySeed: "shared-result")
        let evidenceIDs = PlaybackService.weeklyShareEvidenceItemIDs(from: rows, now: now)
        let reused = try XCTUnwrap(
            service.prepareWeeklyShareCardSnapshot(
                from: facts,
                summary: playback,
                evidenceItemIDs: evidenceIDs
            )
        )
        let fresh = try XCTUnwrap(
            service.prepareWeeklyShareCardSnapshot(
                WeeklyShareCardPreparationInput(
                    items: rows,
                    sourceRevision: 72,
                    now: now
                ),
                summary: playback
            )
        )

        XCTAssertEqual(reused.sourceRevision, 72)
        XCTAssertEqual(reused.evidenceItemIDs, evidenceIDs)
        XCTAssertEqual(reused.payload.weekTotal, fresh.payload.weekTotal, accuracy: 0.001)
        XCTAssertEqual(reused.payload.recordCount, fresh.payload.recordCount)
        XCTAssertEqual(reused.payload.headline, playback.teaserLine)
        XCTAssertEqual(reused.payload.headline, fresh.payload.headline)
        XCTAssertEqual(reused.payload.subtitle, fresh.payload.subtitle)
        XCTAssertEqual(reused.payload.narrativePlan?.leadSignalID, facts.narrativePlan.leadSignalID)
        XCTAssertEqual(reused.payload.narrativePlan?.sourceRevision, 72)

        let presentation = try XCTUnwrap(
            SummaryPlaybackPreparationComputation.build(
                SummaryPlaybackPreparationInput(
                    range: .week,
                    items: rows,
                    preparedFacts: facts,
                    copySeed: "shared-result",
                    sourceRevision: 72,
                    isMember: false,
                    now: now
                )
            )
        )
        XCTAssertEqual(presentation.playback, playback)
        XCTAssertEqual(presentation.sourceRevision, 72)
        XCTAssertEqual(presentation.weeklyShareSnapshot?.sourceRevision, 72)
        XCTAssertEqual(presentation.weeklyShareSnapshot?.payload.headline, playback.teaserLine)
    }

    func testPreparedMonthFactsReusePreservesPlaybackOutputAndRejectsNextMonth() {
        let now = date(7, 20, 20)
        let rows = [
            item("上月早餐", amount: 12, category: .dining, at: date(6, 4, 8)),
            item("上月午饭", amount: 26, category: .dining, at: date(6, 12, 12)),
            item("上月纸巾", amount: 18, category: .daily, at: date(6, 18, 19)),
            item("本月早餐", amount: 14, category: .dining, at: date(7, 4, 8)),
            item("本月地铁", amount: 4.75, category: .transport, at: date(7, 12, 19)),
            item("本月纸巾", amount: 20, category: .daily, at: date(7, 18, 18))
        ]
        let service = PlaybackService()
        let facts = service.preparePeriodExperienceFacts(
            from: rows,
            range: .month,
            now: now,
            sourceRevision: 61
        )
        let direct = service.buildMonthSummary(
            from: rows,
            now: now,
            copySeed: "reuse",
            sourceRevision: 61
        )
        let reused = service.buildMonthSummary(from: facts, copySeed: "reuse")
        let nextMonth = date(8, 2, 10)

        XCTAssertEqual(reused, direct)
        XCTAssertEqual(facts.periodItems.count, 3)
        XCTAssertEqual(facts.previousPeriodItems.count, 3)
        XCTAssertTrue(facts.matches(range: .month, sourceRevision: 61, isMember: true, now: now))
        XCTAssertFalse(facts.matches(range: .month, sourceRevision: 61, isMember: true, now: nextMonth))
    }

    func testWeekKeepsZeroOneTwoAndMatureChapterCounts() {
        let now = date(7, 15, 20)
        let service = PlaybackService()
        let first = item(
            "下班地铁",
            amount: 4.75,
            category: .transport,
            at: date(7, 14, 19, 20),
            emotion: "热天路上辛苦了"
        )
        let second = item("早餐", amount: 12, category: .dining, at: date(7, 15, 8, 10))
        let third = item("午饭", amount: 28, category: .dining, at: date(7, 15, 12, 20))

        XCTAssertEqual(service.buildWeekSummary(from: [], now: now).chapters.count, 0)
        XCTAssertEqual(service.buildWeekSummary(from: [first], now: now).chapters.count, 3)
        XCTAssertEqual(service.buildWeekSummary(from: [first, second], now: now).chapters.count, 3)
        XCTAssertEqual(service.buildWeekSummary(from: [first, second, third], now: now).chapters.count, 5)

        let weak = service.buildWeekSummary(from: [first], now: now)
        XCTAssertEqual(weak.chapters.map(\.title), ["这一周", "这一笔", "这周先到这里"])
        XCTAssertTrue(weak.chapters[0].narration.plain.contains("1 笔"))
        XCTAssertTrue(weak.chapters[1].narration.plain.contains("下班地铁"))
        XCTAssertTrue(weak.chapters[1].metrics["supportLine", default: ""].contains("4.75"))
        XCTAssertFalse(allNarration(weak).contains("热天路上辛苦了"))
    }

    func testMatureWeekSeparatesDistributionRecordAndReliableRepeat() {
        let now = date(7, 16, 20)
        let rows = [
            item("上班地铁", amount: 4, category: .transport, at: date(7, 13, 8, 20)),
            item("下班地铁", amount: 4, category: .transport, at: date(7, 13, 18, 40)),
            item("早餐", amount: 10, category: .dining, at: date(7, 14, 8, 0)),
            item("午饭", amount: 26, category: .dining, at: date(7, 14, 12, 10)),
            item("买纸巾", amount: 18, category: .daily, at: date(7, 16, 19, 0))
        ]

        let summary = PlaybackService().buildWeekSummary(from: rows, now: now)
        XCTAssertEqual(summary.chapters.count, 5)
        XCTAssertEqual(summary.chapters[0].title, "这一周")
        XCTAssertEqual(summary.chapters[1].title, "记录较多的日子")
        XCTAssertEqual(summary.chapters[2].title, "这一笔")
        XCTAssertEqual(summary.chapters[3].title, "这周反复出现")
        XCTAssertEqual(summary.chapters[4].title, "这周先到这里")
        XCTAssertTrue(summary.chapters[0].narration.plain.contains("5 笔"))
        XCTAssertTrue(summary.chapters[1].narration.plain.contains("各记了 2 笔"))
        XCTAssertTrue(summary.chapters[3].narration.plain.contains("各出现了 2 次"))
        XCTAssertEqual(summary.chapters.map(\.durationSec), [6, 7, 7, 7, 7])
    }

    func testPlaybackNarrationDoesNotExposeAbstractOrInternalCopy() {
        let now = date(7, 18, 20)
        let rows = [
            item("晚高峰通勤", amount: 4, category: .transport, at: date(7, 13, 18), emotion: "公共交通一段"),
            item("一杯咖啡", amount: 16, category: .dining, at: date(7, 15, 14), emotion: "咖啡饮品第 30 次"),
            item("停车费", amount: 8, category: .transport, at: date(7, 18, 9), emotion: "车停稳了")
        ]
        let copy = allNarration(PlaybackService().buildWeekSummary(from: rows, now: now))
        let blocked = [
            "胶片", "气味", "有画面", "生活的开头", "这次它又回来了",
            "公共交通一段", "咖啡饮品第 30 次", "车停稳了", "小獭看到"
        ]

        for term in blocked {
            XCTAssertFalse(copy.contains(term), "unexpected playback copy: \(term)")
        }
        XCTAssertFalse(copy.contains("{"))
        XCTAssertFalse(copy.contains("}"))
    }

    func testPlaybackRestoresHighConfidenceAuxiliarySignalsWithoutPuttingThemBackIntoNarration() {
        let now = date(7, 16, 20)
        let rows = [
            item(
                "下班地铁",
                amount: 4.75,
                category: .transport,
                at: date(7, 13, 18, 40),
                emotion: "热天路上辛苦了",
                memoryContext: HomeItem.MemoryContext(
                    weatherKind: "hot",
                    temperatureCelsius: 36,
                    cityName: nil,
                    semanticPlace: nil
                )
            ),
            item("一杯咖啡", amount: 16, category: .dining, at: date(7, 14, 14)),
            item("下午拿铁", amount: 18, category: .dining, at: date(7, 16, 15))
        ]

        let summary = PlaybackService().buildWeekSummary(from: rows, now: now)
        let openingSignals = LifeStorySignalService.playbackAuxiliarySignals(from: summary.chapters[0])

        XCTAssertEqual(
            openingSignals.map(\.label),
            ["生活线索 · 咖啡饮品", "情绪标签 · 热天路上辛苦了"]
        )
        XCTAssertTrue(summary.chapters.dropFirst().allSatisfy {
            LifeStorySignalService.playbackAuxiliarySignals(from: $0).isEmpty
        })
        XCTAssertFalse(allNarration(summary).contains("咖啡饮品"))
        XCTAssertFalse(allNarration(summary).contains("热天路上辛苦了"))
    }

    func testRepeatedCoffeeStaysInTheWeeklyRepeatLayerWithoutTakingOpeningOrClosing() {
        let now = date(7, 16, 20)
        let previous = [6, 7, 8].map { day in
            HomeItem(title: "咖啡", amount: 16, category: .dining, createdAt: date(7, day, 14))
        }
        let current = [13, 14, 15].map { day in
            HomeItem(title: "咖啡", amount: 16, category: .dining, createdAt: date(7, day, 14))
        }

        let summary = PlaybackService().buildWeekSummary(from: previous + current, now: now)
        let openingAndClosing = [summary.chapters.first, summary.chapters.last]
            .compactMap { $0 }
            .flatMap { [$0.narration.plain, $0.narration.warm] }
            .joined(separator: "\n")

        XCTAssertFalse(openingAndClosing.contains("咖啡"))
        XCTAssertEqual(
            LifeStorySignalService.playbackAuxiliarySignals(from: summary.chapters[0]).map(\.label),
            ["生活线索 · 咖啡饮品"]
        )
        XCTAssertEqual(summary.chapters.map(\.durationSec), [6, 7, 7, 7, 7])
    }

    func testPlaybackAuxiliarySignalsRejectWeakAndSensitiveLabels() {
        let now = date(7, 16, 20)
        let rows = [
            item("便利店可乐", amount: 8, category: .dining, at: date(7, 14, 13), emotion: "给今天一点甜"),
            item(
                "医院检查",
                amount: 120,
                category: .health,
                at: date(7, 15, 10),
                emotion: "雨天看病辛苦了",
                memoryContext: HomeItem.MemoryContext(
                    weatherKind: "rain",
                    temperatureCelsius: 24,
                    cityName: nil,
                    semanticPlace: nil
                )
            )
        ]

        let summary = PlaybackService().buildWeekSummary(from: rows, now: now)
        XCTAssertTrue(LifeStorySignalService.playbackAuxiliarySignals(from: summary.chapters[0]).isEmpty)
    }

    func testPlaybackAuxiliarySignalsDeduplicateMainAndSupportCopy() {
        let chapter = SummaryChapter(
            id: "dedup",
            title: "这一周",
            metrics: [
                PlaybackAuxiliarySignalPolicy.lifeMarkMetricKey: "咖啡饮品",
                PlaybackAuxiliarySignalPolicy.emotionMetricKey: "热天路上辛苦了",
                "supportLine": "生活线索：咖啡饮品"
            ],
            narration: SummaryNarration(
                warm: "这周也有一笔热天路上辛苦了。",
                plain: "这周也有一笔热天路上辛苦了。"
            ),
            durationSec: 6
        )

        XCTAssertTrue(LifeStorySignalService.playbackAuxiliarySignals(from: chapter).isEmpty)
    }

    func testStrongLateWorkCommuteBecomesWeeklyRepresentativeAndUsesDedicatedCopy() throws {
        let now = date(7, 16, 20)
        let lateWorkCommute = HomeItem(
            title: "加班打车",
            amount: 50.90,
            category: .transport,
            source: .ocr,
            createdAt: date(7, 14, 0, 8),
            emotionTag: "打车这一程",
            userEditedTitle: false,
            memoryImageData: Data([0x01])
        )
        let rows = [
            item("早餐", amount: 12, category: .dining, at: date(7, 13, 8)),
            lateWorkCommute,
            item("买纸巾", amount: 18, category: .daily, at: date(7, 15, 18))
        ]

        let summary = PlaybackService().buildWeekSummary(from: rows, now: now)
        let voice = try XCTUnwrap(summary.chapters.first(where: { $0.id == "week-voices" }))
        let dedicatedNarrationCount = summary.chapters.filter {
            $0.narration.plain.contains("凌晨零点多还在下班路上")
        }.count

        XCTAssertEqual(voice.metrics["voiceTitle1"], "晚下班路上")
        XCTAssertTrue(voice.narration.plain.contains("今天收得有点晚"))
        XCTAssertTrue(voice.metrics["supportLine", default: ""].contains("50.9"))
        XCTAssertEqual(summary.total, 80.9, accuracy: 0.001)
        XCTAssertEqual(dedicatedNarrationCount, 1)
        XCTAssertTrue(summary.memoryAnchors.contains(where: { $0.itemID == lateWorkCommute.id }))
        XCTAssertFalse(
            LifeStorySignalService.playbackAuxiliarySignals(from: summary.chapters[0])
                .contains(where: { $0.label.contains("晚下班") })
        )
    }

    func testHigherValueLeadKeepsItsWeeklyVoiceAndLateWorkCommuteMovesToOpeningSupport() throws {
        let now = date(7, 16, 20)
        let lead = HomeItem(
            title: "第一次带妈妈去看展",
            amount: 88,
            category: .entertainment,
            createdAt: date(7, 13, 15),
            userEditedTitle: true,
            memoryImageData: Data([0x02]),
            memoryAnchorRole: .moment
        )
        let lateWorkCommute = HomeItem(
            title: "加班打车",
            amount: 50.90,
            category: .transport,
            source: .ocr,
            createdAt: date(7, 14, 0, 8),
            emotionTag: "打车这一程",
            userEditedTitle: false
        )

        let summary = PlaybackService().buildWeekSummary(
            from: [lead, lateWorkCommute, item("早餐", amount: 12, category: .dining, at: date(7, 15, 8))],
            now: now
        )
        let voice = try XCTUnwrap(summary.chapters.first(where: { $0.id == "week-voices" }))

        XCTAssertEqual(voice.metrics["voiceTitle1"], lead.title)
        XCTAssertTrue(summary.chapters[0].metrics["supportLine", default: ""].contains("凌晨零点多还在下班路上"))
        XCTAssertFalse(voice.narration.plain.contains("下班路上"))
    }

    func testOrdinaryLateTransitDoesNotReceiveTheStrongWorkCommuteGuarantee() {
        let ordinaryTransit = HomeItem(
            title: "地铁",
            amount: 4,
            category: .transport,
            source: .ocr,
            createdAt: date(7, 14, 0, 8),
            emotionTag: "日常出行",
            userEditedTitle: false
        )

        XCTAssertNil(PlaybackLateWorkCommutePolicy.preferredStrongItem(in: [ordinaryTransit]))
        XCTAssertEqual(HomeItem.lateWorkCommutePlaybackTitle(for: ordinaryTransit), "晚上通勤路上")
    }

    func testStrongLateWorkCommuteUsesTheMatchingMonthlyHalfChapter() throws {
        let now = date(7, 20, 20)
        let lateWorkCommute = HomeItem(
            title: "加班打车",
            amount: 50.90,
            category: .transport,
            source: .ocr,
            createdAt: date(7, 12, 0, 8),
            emotionTag: "打车这一程",
            userEditedTitle: false
        )
        let summary = PlaybackService().buildMonthSummary(
            from: [
                item("早餐", amount: 12, category: .dining, at: date(7, 4, 8)),
                lateWorkCommute,
                item("买纸巾", amount: 18, category: .daily, at: date(7, 18, 18))
            ],
            now: now
        )
        let lateVoice = try XCTUnwrap(summary.chapters.first(where: { $0.id == "month-late-voice" }))

        XCTAssertEqual(lateVoice.metrics["lateVoiceTitle"], "晚下班路上")
        XCTAssertTrue(lateVoice.narration.plain.contains("凌晨零点多还在下班路上"))
    }

    func testMonthPublishesAuxiliarySignalsOnlyOnOpeningChapter() {
        let now = date(7, 20, 20)
        let rows = [
            item("一杯咖啡", amount: 16, category: .dining, at: date(7, 4, 14)),
            item("下午拿铁", amount: 18, category: .dining, at: date(7, 12, 15)),
            item("早餐", amount: 12, category: .dining, at: date(7, 18, 8))
        ]

        let summary = PlaybackService().buildMonthSummary(from: rows, now: now)
        XCTAssertEqual(
            LifeStorySignalService.playbackAuxiliarySignals(from: summary.chapters[0]).map(\.label),
            ["生活线索 · 咖啡饮品"]
        )
        XCTAssertEqual(summary.chapters.count, 6)
        XCTAssertTrue(summary.chapters.dropFirst().allSatisfy {
            LifeStorySignalService.playbackAuxiliarySignals(from: $0).isEmpty
        })
    }

    func testMonthKeepsSixRolesAndUsesSameDayComparison() {
        let now = date(7, 20, 20)
        let current = [
            item("上班地铁", amount: 100, category: .transport, at: date(7, 4, 8)),
            item("和朋友吃饭", amount: 100, category: .dining, at: date(7, 15, 19)),
            item("午饭", amount: 80, category: .dining, at: date(7, 16, 12)),
            item("买纸巾", amount: 60, category: .daily, at: date(7, 18, 18))
        ]
        let previous = [
            item("交通", amount: 200, category: .transport, at: date(6, 4, 8)),
            item("早餐", amount: 50, category: .dining, at: date(6, 10, 8)),
            item("午饭", amount: 50, category: .dining, at: date(6, 18, 12)),
            item("月末大额", amount: 1_000, category: .shopping, at: date(6, 25, 12))
        ]

        let summary = PlaybackService().buildMonthSummary(from: current + previous, now: now)
        XCTAssertEqual(summary.chapters.count, 6)
        XCTAssertEqual(
            summary.chapters.map(\.title),
            ["7月回看", "月初留下的", "后来留下的", "和上月同期相比", "这个月反复出现", "这个月先到这里"]
        )
        XCTAssertEqual(summary.chapters.map(\.durationSec), [8, 8, 8, 8, 8, 7])
        XCTAssertTrue(summary.chapters[1].narration.plain.contains("7月4日"))
        XCTAssertTrue(summary.chapters[2].narration.plain.contains("7月"))
        XCTAssertTrue(summary.chapters[3].metrics["supportLine", default: ""].contains("1 日—20 日"))
        XCTAssertFalse(summary.chapters[3].narration.plain.contains("1000"))
        XCTAssertNotEqual(summary.chapters[1].narration.plain, summary.chapters[2].narration.plain)
    }

    func testMonthExplicitlyHandlesMissingEarlyLateAndComparisonEvidence() {
        let now = date(7, 20, 20)
        let rows = [
            item("晚饭", amount: 38, category: .dining, at: date(7, 14, 19)),
            item("下班地铁", amount: 4, category: .transport, at: date(7, 15, 21))
        ]
        let summary = PlaybackService().buildMonthSummary(from: rows, now: now)

        XCTAssertTrue(summary.chapters[1].narration.plain.contains("月初十天没有记录"))
        XCTAssertTrue(summary.chapters[1].narration.plain.contains("7月14日"))
        XCTAssertFalse(summary.chapters[2].narration.plain.contains("月初十天"))
        XCTAssertTrue(summary.chapters[3].narration.plain.contains("暂时不做环比"))
        XCTAssertTrue(summary.chapters[4].narration.plain.contains("没有哪一类反复出现"))
        XCTAssertEqual(summary.chapters[5].narration.warm, summary.chapters[5].narration.plain)
    }
}

final class InteractionStateRegressionTests: XCTestCase {
    private struct QueueItem: Identifiable, Equatable {
        let id: Int
        let value: String
    }

    private enum Route: Equatable {
        case member(String)
        case detail(Int)
    }

    func testPostSaveQueueIsFIFOAndRejectsDuplicateIDs() {
        var queue = UniqueFIFOQueue<QueueItem>()

        XCTAssertTrue(queue.enqueue(QueueItem(id: 1, value: "photo")))
        XCTAssertTrue(queue.enqueue(QueueItem(id: 2, value: "reward")))
        XCTAssertFalse(queue.enqueue(QueueItem(id: 1, value: "duplicate")))

        XCTAssertEqual(queue.dequeue(), QueueItem(id: 1, value: "photo"))
        XCTAssertEqual(queue.dequeue(), QueueItem(id: 2, value: "reward"))
        XCTAssertNil(queue.dequeue())
    }

    func testDeferredRouteConsumesOnceAndLatestRepeatedRequestWins() {
        var routes = DeferredRouteQueue<Route>()
        XCTAssertNil(routes.consume())

        routes.request(.detail(1))
        routes.request(.member("playbackQuota"))

        XCTAssertEqual(routes.consume(), .member("playbackQuota"))
        XCTAssertNil(routes.consume())

        routes.request(.detail(2))
        routes.cancel()
        XCTAssertNil(routes.consume())
    }

    func testLatestRequestGateRejectsStaleCompletion() {
        var gate = LatestRequestGate()
        let first = gate.begin()
        let second = gate.begin()

        XCTAssertFalse(gate.accepts(first))
        XCTAssertTrue(gate.accepts(second))

        gate.invalidate()
        XCTAssertFalse(gate.accepts(second))
    }

    func testPostSavePromptBudgetLimitsFrequencyAndResetsNextDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let start = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 9
        ))!
        var state = PostSavePromptBudgetState()

        var result = PostSavePromptBudgetPolicy.reserving(
            .firstPlayback,
            state: state,
            now: start,
            calendar: calendar
        )
        XCTAssertTrue(result.allowed)
        state = result.state

        result = PostSavePromptBudgetPolicy.reserving(
            .sceneReward,
            state: state,
            now: start.addingTimeInterval(5 * 60),
            calendar: calendar
        )
        XCTAssertFalse(result.allowed)

        result = PostSavePromptBudgetPolicy.reserving(
            .sceneReward,
            state: state,
            now: start.addingTimeInterval(21 * 60),
            calendar: calendar
        )
        XCTAssertTrue(result.allowed)
        state = result.state

        result = PostSavePromptBudgetPolicy.reserving(
            .memoryPhoto,
            state: state,
            now: start.addingTimeInterval(60 * 60),
            calendar: calendar
        )
        XCTAssertFalse(result.allowed)

        result = PostSavePromptBudgetPolicy.reserving(
            .memoryPhoto,
            state: state,
            now: start.addingTimeInterval(24 * 60 * 60),
            calendar: calendar
        )
        XCTAssertTrue(result.allowed)
        XCTAssertEqual(result.state.strongPromptCount, 1)
    }

    func testHomeJourneyActionPrioritizesUnfinishedWorkThenPlaybackAndTrace() {
        var snapshot = HomeJourneySnapshot(
            hasOCRDrafts: true,
            hasManualDraft: true,
            todayRecordCount: 2,
            hasUnplayedTodayRecords: true,
            weekTraceReady: true,
            monthTraceReady: true
        )
        XCTAssertEqual(HomeJourneyActionPolicy.primaryAction(for: snapshot), .resumeOCR)

        snapshot.hasOCRDrafts = false
        XCTAssertEqual(HomeJourneyActionPolicy.primaryAction(for: snapshot), .continueManualDraft)

        snapshot.hasManualDraft = false
        XCTAssertEqual(HomeJourneyActionPolicy.primaryAction(for: snapshot), .todayPlayback)

        snapshot.hasUnplayedTodayRecords = false
        XCTAssertEqual(HomeJourneyActionPolicy.primaryAction(for: snapshot), .weekTrace)

        snapshot.weekTraceReady = false
        XCTAssertEqual(HomeJourneyActionPolicy.primaryAction(for: snapshot), .monthTrace)
    }

    func testHomeJourneyActionKeepsRecordingAvailableAsSecondaryAction() {
        XCTAssertEqual(
            HomeJourneyActionPolicy.secondaryAction(for: .todayPlayback, hasTodayRecords: true),
            .continueRecording
        )
        XCTAssertEqual(
            HomeJourneyActionPolicy.secondaryAction(for: .record, hasTodayRecords: false),
            .resumeOCR
        )
    }

    func testNewUserProgressionUnlocksOneNextStageWithoutEmptyReviewSelling() {
        var snapshot = NewUserProgressionSnapshot(
            totalRecordCount: 0,
            hasUnplayedTodayRecords: false,
            weekRecordCount: 0,
            weekActiveDayCount: 0,
            monthRecordCount: 0,
            monthActiveDayCount: 0,
            dayOfMonth: 16,
            canPlayWeek: true,
            canPlayMonth: true,
            hasCompletedCurrentWeekPlayback: false,
            hasCompletedCurrentMonthPlayback: false
        )
        XCTAssertEqual(NewUserProgressionPolicy.stage(for: snapshot), .recordFirstEntry)
        XCTAssertFalse(NewUserProgressionPolicy.allowsReviewTasks(totalRecordCount: 0))

        snapshot.totalRecordCount = 1
        snapshot.hasUnplayedTodayRecords = true
        XCTAssertEqual(NewUserProgressionPolicy.stage(for: snapshot), .todayPlayback)

        snapshot.hasUnplayedTodayRecords = false
        snapshot.totalRecordCount = 3
        snapshot.weekRecordCount = 3
        snapshot.weekActiveDayCount = 2
        XCTAssertEqual(NewUserProgressionPolicy.stage(for: snapshot), .weekTrace)

        snapshot.weekRecordCount = 0
        snapshot.weekActiveDayCount = 0
        snapshot.monthRecordCount = 5
        snapshot.monthActiveDayCount = 3
        snapshot.dayOfMonth = 25
        XCTAssertEqual(NewUserProgressionPolicy.stage(for: snapshot), .monthChapter)

        snapshot.monthRecordCount = 0
        snapshot.monthActiveDayCount = 0
        snapshot.hasCompletedCurrentWeekPlayback = true
        XCTAssertEqual(NewUserProgressionPolicy.stage(for: snapshot), .reviewTasks)
        XCTAssertEqual(
            HomeJourneyActionPolicy.primaryAction(
                for: HomeJourneySnapshot(
                    hasOCRDrafts: false,
                    hasManualDraft: false,
                    todayRecordCount: 0,
                    hasUnplayedTodayRecords: false,
                    weekTraceReady: false,
                    monthTraceReady: false
                ),
                progressionStage: .reviewTasks
            ),
            .review
        )
    }

    func testRecordFlowShowsOCRUntilAnAmountDraftExists() {
        XCTAssertTrue(RecordFlowVisibilityPolicy.showsOCRSideDoor(hasAmountDraft: false))
        XCTAssertFalse(RecordFlowVisibilityPolicy.showsOCRSideDoor(hasAmountDraft: true))
    }

    func testTraceRangeContextUsesOneWeekMonthSource() {
        XCTAssertEqual(TraceRangeContextPolicy.period(for: .week), .week)
        XCTAssertEqual(TraceRangeContextPolicy.period(for: .month), .month)
        XCTAssertEqual(TraceRangeContextPolicy.lifeRange(for: .week), .week)
        XCTAssertEqual(TraceRangeContextPolicy.lifeRange(for: .month), .month)
        XCTAssertNil(TraceRangeContextPolicy.lifeRange(for: .year))
    }

    func testReviewTaskIntentsMapToSupportedExplicitCommands() {
        XCTAssertEqual(ReviewTaskIntent.allCases.count, 3)
        XCTAssertTrue(ReviewTaskIntent.query.presetCommand.contains("最近 7 天"))
        XCTAssertTrue(ReviewTaskIntent.compare.presetCommand.contains("最近 7 天"))
        XCTAssertTrue(ReviewTaskIntent.compare.presetCommand.contains("前 7 天"))
        XCTAssertTrue(ReviewTaskIntent.backfill.presetCommand.isEmpty)
    }

    func testPlaybackMaturityAndCompletionUseOnePrimaryRule() {
        XCTAssertFalse(PlaybackMaturityPolicy.weekIsReady(recordCount: 3, activeDayCount: 1))
        XCTAssertTrue(PlaybackMaturityPolicy.weekIsReady(recordCount: 3, activeDayCount: 2))
        XCTAssertFalse(PlaybackMaturityPolicy.monthIsReady(recordCount: 5, activeDayCount: 3, dayOfMonth: 24))
        XCTAssertFalse(PlaybackMaturityPolicy.monthIsReady(recordCount: 5, activeDayCount: 2, dayOfMonth: 25))
        XCTAssertTrue(PlaybackMaturityPolicy.monthIsReady(recordCount: 5, activeDayCount: 3, dayOfMonth: 25))
        XCTAssertEqual(PlaybackCompletionPolicy.primaryAction(isMember: true), .dismiss)
        XCTAssertEqual(PlaybackCompletionPolicy.primaryAction(isMember: false), .dismiss)
        XCTAssertEqual(PlaybackCompletionPolicy.primaryTitle(isMember: true, memberTitle: nil), "完成")
        XCTAssertEqual(PlaybackCompletionPolicy.primaryTitle(isMember: false, memberTitle: "了解会员"), "完成")
        XCTAssertTrue(PlaybackCompletionPolicy.showsMemberContinuation(isMember: false, hasMemberPitch: true))
        XCTAssertFalse(PlaybackCompletionPolicy.showsMemberContinuation(isMember: false, hasMemberPitch: false))
        XCTAssertFalse(PlaybackCompletionPolicy.showsMemberContinuation(isMember: true, hasMemberPitch: true))
        XCTAssertTrue(
            PlaybackMaturityPolicy.homeRecommendationExplanation(
                weekRecordCount: 3,
                weekActiveDayCount: 1,
                monthRecordCount: 5,
                monthActiveDayCount: 3,
                dayOfMonth: 20
            ).contains("接近月底")
        )
    }

    func testWeekTraceDiscoveryUsesSharedMaturityAndSeparateSeenState() {
        var snapshot = WeekTraceDiscoverySnapshot(
            recordCount: 3,
            activeDayCount: 1,
            canPlay: true,
            hasCompletedPlayback: false,
            hasSeenTrace: false
        )
        XCTAssertFalse(WeekTraceDiscoveryPolicy.shouldShowBadge(for: snapshot))
        XCTAssertFalse(
            WeekTraceDiscoveryPolicy.shouldMarkSeen(
                recordCount: 3,
                activeDayCount: 1,
                hasVisibleCurrentWeekSnapshot: true,
                hasSeenTrace: false
            )
        )

        snapshot.activeDayCount = 2
        XCTAssertTrue(WeekTraceDiscoveryPolicy.shouldShowBadge(for: snapshot))
        XCTAssertFalse(
            WeekTraceDiscoveryPolicy.shouldMarkSeen(
                recordCount: 3,
                activeDayCount: 2,
                hasVisibleCurrentWeekSnapshot: false,
                hasSeenTrace: false
            )
        )
        XCTAssertTrue(
            WeekTraceDiscoveryPolicy.shouldMarkSeen(
                recordCount: 3,
                activeDayCount: 2,
                hasVisibleCurrentWeekSnapshot: true,
                hasSeenTrace: false
            )
        )

        snapshot.hasSeenTrace = true
        XCTAssertFalse(WeekTraceDiscoveryPolicy.shouldShowBadge(for: snapshot))
        snapshot.hasSeenTrace = false
        snapshot.hasCompletedPlayback = true
        XCTAssertFalse(WeekTraceDiscoveryPolicy.shouldShowBadge(for: snapshot))
        snapshot.hasCompletedPlayback = false
        snapshot.canPlay = false
        XCTAssertFalse(WeekTraceDiscoveryPolicy.shouldShowBadge(for: snapshot))
    }

    func testTodayPlaybackStillPrecedesAReadyWeekTrace() {
        let snapshot = NewUserProgressionSnapshot(
            totalRecordCount: 3,
            hasUnplayedTodayRecords: true,
            weekRecordCount: 3,
            weekActiveDayCount: 2,
            monthRecordCount: 3,
            monthActiveDayCount: 2,
            dayOfMonth: 20,
            canPlayWeek: true,
            canPlayMonth: true,
            hasCompletedCurrentWeekPlayback: false,
            hasCompletedCurrentMonthPlayback: false
        )
        XCTAssertEqual(NewUserProgressionPolicy.stage(for: snapshot), .todayPlayback)
        XCTAssertTrue(
            WeekTraceDiscoveryPolicy.shouldShowBadge(
                for: WeekTraceDiscoverySnapshot(
                    recordCount: 3,
                    activeDayCount: 2,
                    canPlay: true,
                    hasCompletedPlayback: false,
                    hasSeenTrace: false
                )
            )
        )
    }

    func testAutomaticMemberNudgesRespectBudgetWhileExplicitEntriesStayImmediate() throws {
        let now = Date(timeIntervalSince1970: 1_752_643_200)
        let policy = MemberNudgePolicy(prodDailyLimit: 1, prodSceneCooldownDays: 7)
        let dailyLimitedState = MemberNudgeState(
            lastShownAt: now,
            dailyDayKey: MemberNudgePolicyService.dayKey(for: now),
            dailyCount: 1,
            sceneCooldownUntil: [:],
            automaticCooldownUntil: nil
        )

        XCTAssertFalse(MemberNudgeEligibilityPolicy.canPresent(
            source: .automatic,
            scene: "share_success",
            policy: policy,
            state: dailyLimitedState,
            now: now
        ))
        XCTAssertTrue(MemberNudgeEligibilityPolicy.canPresent(
            source: .explicitUserAction,
            scene: "locked_month_chapter",
            policy: policy,
            state: dailyLimitedState,
            now: now
        ))

        var dismissedState = MemberNudgeState.empty
        dismissedState.automaticCooldownUntil = now.addingTimeInterval(7 * 24 * 60 * 60)
        XCTAssertFalse(MemberNudgeEligibilityPolicy.canPresent(
            source: .automatic,
            scene: "ai_monthly",
            policy: policy,
            state: dismissedState,
            now: now
        ))

        struct LegacyState: Encodable {
            let lastShownAt: Date?
            let dailyDayKey: String
            let dailyCount: Int
            let sceneCooldownUntil: [String: Date]
        }
        let legacyData = try JSONEncoder().encode(LegacyState(
            lastShownAt: nil,
            dailyDayKey: "",
            dailyCount: 0,
            sceneCooldownUntil: [:]
        ))
        XCTAssertNil(try JSONDecoder().decode(MemberNudgeState.self, from: legacyData).automaticCooldownUntil)
    }

    func testMemberLoginContinuationResumesSelectedPlanExactlyOnce() {
        var state = MemberLoginContinuationState()

        state.beginLogin(for: .purchase(planID: "lifetime"))
        XCTAssertEqual(state.pendingLoginIntent, .purchase(planID: "lifetime"))
        XCTAssertNil(state.resumedIntent)

        state.loginSucceeded()
        state.loginSucceeded()

        XCTAssertNil(state.pendingLoginIntent)
        XCTAssertEqual(state.takeResumedIntent(), .purchase(planID: "lifetime"))
        XCTAssertNil(state.takeResumedIntent())
    }

    func testMemberLoginCancellationClearsIntentWithoutResumingPurchaseOrRestore() {
        var state = MemberLoginContinuationState()
        state.beginLogin(for: .restorePurchases)
        state.loginCancelled()

        XCTAssertNil(state.pendingLoginIntent)
        XCTAssertNil(state.takeResumedIntent())

        state.beginLogin(for: .purchase(planID: "monthly"))
        state.loginSucceeded()
        state.clearResumedIntent()
        XCTAssertNil(state.takeResumedIntent())
    }

    @MainActor
    func testRecordSessionPersistsDraftUIUntilCommittedReset() {
        let session = RecordTabSession()
        session.selectedEntryMode = .ocr
        session.noteEditorExpanded = true
        session.datePanelExpanded = true
        session.previewLineWasRotated = true
        session.userNoteAnchorTitle = "晚饭"

        XCTAssertEqual(session.selectedEntryMode, .ocr)
        XCTAssertTrue(session.noteEditorExpanded)

        session.resetAfterCommittedDraft()

        XCTAssertEqual(session.selectedEntryMode, .manual)
        XCTAssertFalse(session.noteEditorExpanded)
        XCTAssertFalse(session.datePanelExpanded)
        XCTAssertFalse(session.previewLineWasRotated)
        XCTAssertNil(session.userNoteAnchorTitle)
    }

    func testTabStateRetainsTraceAndInsightContext() {
        var stats = StatsTabState()
        stats.selectedPeriod = .month
        stats.selectedCategory = .dining
        stats.useCustomRange = true
        stats.viewMode = .clues
        stats.scrollAnchorID = "trace-clue-board"

        XCTAssertEqual(stats.selectedPeriod, .month)
        XCTAssertEqual(stats.selectedCategory, .dining)
        XCTAssertTrue(stats.useCustomRange)
        XCTAssertEqual(stats.viewMode, .clues)
        XCTAssertEqual(stats.scrollAnchorID, "trace-clue-board")

        stats.openLifeChapter(.month)
        XCTAssertEqual(stats.viewMode, .life)
        XCTAssertEqual(stats.lifeCardRange, .month)
        XCTAssertEqual(stats.selectedPeriod, .month)
        XCTAssertFalse(stats.useCustomRange)
        XCTAssertEqual(stats.scrollAnchorID, "trace-clue-board")
        XCTAssertEqual(stats.pendingLifeChapterScrollRange, .month)

        var insight = InsightTabState()
        insight.showsAdvancedInsight = true
        insight.scrollAnchorID = "insight-next-chapter"
        insight.monthlyInsightGenerated = true

        XCTAssertTrue(insight.showsAdvancedInsight)
        XCTAssertTrue(insight.monthlyInsightGenerated)
        XCTAssertEqual(insight.scrollAnchorID, "insight-next-chapter")
    }

    func testSelectingLifeNormalizesClueOnlyRangesToTheRememberedLifeRange() {
        var customRangeState = StatsTabState()
        customRangeState.viewMode = .clues
        customRangeState.lifeCardRange = .month
        customRangeState.selectedPeriod = .month
        customRangeState.useCustomRange = true
        customRangeState.showsCustomDatePanel = true
        customRangeState.selectedCategory = .dining

        customRangeState.selectViewMode(.life)

        XCTAssertEqual(customRangeState.viewMode, .life)
        XCTAssertEqual(customRangeState.lifeCardRange, .month)
        XCTAssertEqual(customRangeState.selectedPeriod, .month)
        XCTAssertFalse(customRangeState.useCustomRange)
        XCTAssertFalse(customRangeState.showsCustomDatePanel)
        XCTAssertEqual(customRangeState.selectedCategory, .dining)

        var yearState = StatsTabState()
        yearState.viewMode = .clues
        yearState.lifeCardRange = .week
        yearState.selectedPeriod = .year

        yearState.selectViewMode(.life)

        XCTAssertEqual(yearState.viewMode, .life)
        XCTAssertEqual(yearState.lifeCardRange, .week)
        XCTAssertEqual(yearState.selectedPeriod, .week)
        XCTAssertFalse(yearState.useCustomRange)
    }

    func testSelectingCluesDoesNotRewriteTheExistingRangeState() {
        var stats = StatsTabState()
        stats.lifeCardRange = .month
        stats.selectedPeriod = .year
        stats.useCustomRange = true
        stats.showsCustomDatePanel = true

        stats.selectViewMode(.clues)

        XCTAssertEqual(stats.viewMode, .clues)
        XCTAssertEqual(stats.lifeCardRange, .month)
        XCTAssertEqual(stats.selectedPeriod, .year)
        XCTAssertTrue(stats.useCustomRange)
        XCTAssertTrue(stats.showsCustomDatePanel)
    }
}

final class OCRImportSubmissionGateTests: XCTestCase {
    func testOnlyOneOCRImportCanSubmitUntilReset() {
        var gate = OCRImportSubmissionGate()

        XCTAssertTrue(gate.begin(.review))
        XCTAssertFalse(gate.begin(.direct))
        XCTAssertEqual(gate.action, .review)

        gate.reset()
        XCTAssertTrue(gate.begin(.direct))
        XCTAssertEqual(gate.action, .direct)
    }
}

final class SingleRecordEmotionBoundaryTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 18,
            hour: hour,
            minute: minute
        ))!
    }

    func testParkingTagUsesFactCopyForNewAndStoredRecords() {
        let fresh = HomeItem(title: "停车费", amount: 69.8, category: .transport, createdAt: date(7, 47))
        let stored = HomeItem(
            title: "停车费",
            amount: 69.8,
            category: .transport,
            createdAt: date(7, 47),
            emotionTag: "车停稳了"
        )

        XCTAssertEqual(fresh.displayEmotionTag, "停车费记下")
        XCTAssertEqual(stored.displayEmotionTag, "停车费记下")
    }

    func testWeekendDiningDoesNotPersistCrossRecordTransportStory() {
        let result = RecordMemoryContextService.enhancedEmotionTag(input: RecordMemoryContextInput(
            title: "巧婆红汤馄饨",
            category: .dining,
            amount: 16,
            date: date(8, 22),
            baseEmotionTag: "周末早餐",
            weather: nil
        ))

        XCTAssertEqual(result, "周末早餐")
    }

    func testStoredWeekendCombinationTagFallsBackToThisRecordOnly() {
        let breakfast = HomeItem(
            title: "巧婆红汤馄饨",
            amount: 16,
            category: .dining,
            createdAt: date(8, 22),
            emotionTag: "周末路上和饭点都有了"
        )

        XCTAssertEqual(breakfast.displayEmotionTag, "周末早餐")
    }

    @MainActor
    func testFirstRecordStoryUsesTimeAndRecordInsteadOfEmotionTemplate() {
        let parking = HomeItem(title: "停车费", amount: 69.8, category: .transport, createdAt: date(7, 47))
        let line = HomeViewModel.singleRecordTodayStoryLine(for: parking, calendar: calendar)

        XCTAssertTrue(line.contains("早上"))
        XCTAssertTrue(line.contains("停车费"))
        XCTAssertFalse(line.contains("车停稳了"))
        XCTAssertFalse(line.contains("刚翻开第一页"))
    }

    func testEveningDiningDoesNotKeepStoredNoonTagAfterTimeEdit() {
        let item = HomeItem(
            title: "肯德基",
            amount: 25.90,
            category: .dining,
            createdAt: date(17, 56),
            emotionTag: "中午这顿安排好了"
        )

        XCTAssertEqual(item.displayEmotionTag, "晚饭时间坐一会儿")
    }

    func testExplicitNoonTitleStillWinsOverEveningClock() {
        let item = HomeItem(
            title: "中午带饭",
            amount: 25.90,
            category: .dining,
            createdAt: date(17, 56),
            emotionTag: "中午这顿安排好了"
        )

        XCTAssertEqual(item.displayEmotionTag, "中午这顿安排好了")
    }

    func testDiningResolutionUsesEveningTagForBrandAfterSeventeen() {
        let resolution = RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: "肯德基",
                fallbackCategory: .dining,
                amount: 25.90,
                date: date(17, 56),
                merchantBrandId: "kfc",
                categoryLockedByUser: false,
                userEditedTitle: true,
                source: "test"
            )
        )

        XCTAssertEqual(resolution.emotionTag, "晚饭时间坐一会儿")
    }

    func testGenericShoppingTitleDoesNotMatchDeskStationeryKeyword() {
        let item = HomeItem(
            title: "临时花了一笔",
            amount: 18,
            category: .shopping,
            createdAt: date(14, 10),
            emotionTag: "书桌常用的补上"
        )

        XCTAssertEqual(item.displayEmotionTag, "日常添置")
    }

    func testExplicitStationeryTermsKeepDeskStationeryEmotion() {
        let pen = HomeItem(
            title: "买了一支钢笔",
            amount: 18,
            category: .shopping,
            createdAt: date(14, 10)
        )
        let plainPen = HomeItem(
            title: "买了一支笔",
            amount: 8,
            category: .shopping,
            createdAt: date(14, 10)
        )
        let stationery = HomeItem(
            title: "买文具",
            amount: 18,
            category: .shopping,
            createdAt: date(14, 10)
        )

        XCTAssertEqual(pen.displayEmotionTag, "书桌常用的补上")
        XCTAssertEqual(plainPen.displayEmotionTag, "书桌常用的补上")
        XCTAssertEqual(stationery.displayEmotionTag, "书桌常用的补上")
    }

    func testSemanticBoundaryRejectsCommonSubstringFalsePositives() {
        XCTAssertFalse(SemanticBoundaryGuard.matchesStationery("另记两笔，分了几笔"))
        XCTAssertFalse(SemanticBoundaryGuard.matchesStationery("买笔记本电脑"))
        XCTAssertFalse(SemanticBoundaryGuard.matchesStationery("买了一支笔记本电脑"))
        XCTAssertTrue(SemanticBoundaryGuard.matchesStationery("书桌买了一个笔芯"))
        XCTAssertFalse(SemanticBoundaryGuard.matchesFlowerShopping("花呗还款、买花生和棉花"))
        XCTAssertTrue(SemanticBoundaryGuard.matchesFlowerShopping("花店买一束鲜花"))
        XCTAssertFalse(SemanticBoundaryGuard.matchesBabySupply("桂林米粉、手推车、成人奶粉"))
        XCTAssertFalse(SemanticBoundaryGuard.matchesBabySupply("买辅食、宠物辅食和辅食机"))
        XCTAssertFalse(SemanticBoundaryGuard.matchesBabySupply("给宝宝买辅食机"))
        XCTAssertFalse(SemanticBoundaryGuard.matchesBabySupply("婴儿辅食料理机"))
        XCTAssertTrue(SemanticBoundaryGuard.matchesBabySupply("婴儿推车和婴儿奶粉"))
        XCTAssertTrue(SemanticBoundaryGuard.matchesBabySupply("给宝宝买辅食"))
        XCTAssertFalse(SemanticBoundaryGuard.matchesFitness("视频会员年卡、英语课程"))
        XCTAssertTrue(SemanticBoundaryGuard.matchesFitness("健身房年卡、瑜伽课程"))
        XCTAssertFalse(SemanticBoundaryGuard.matchesLongDistanceTransit("机动车年检、电动车充电"))
        XCTAssertFalse(SemanticBoundaryGuard.matchesLongDistanceTransit("停车票"))
        XCTAssertFalse(SemanticBoundaryGuard.matchesLongDistanceTransit("买车票"))
        XCTAssertFalse(SemanticBoundaryGuard.matchesLongDistanceTransit("买火车模型"))
        XCTAssertFalse(SemanticBoundaryGuard.matchesLongDistanceTransit("高铁站停车费"))
        XCTAssertFalse(SemanticBoundaryGuard.matchesLongDistanceTransit("机场停车费"))
        XCTAssertTrue(SemanticBoundaryGuard.matchesLongDistanceTransit("买车票去外地"))
        XCTAssertTrue(SemanticBoundaryGuard.matchesLongDistanceTransit("买动车票去外地"))
    }

    func testLifeSceneDoesNotTreat裙带菜AsClothingOrVideoAnnualCardAsFitness() {
        let seaweed = HomeItem(title: "裙带菜", amount: 12, category: .shopping, createdAt: date(14, 10))
        let video = HomeItem(title: "视频会员年卡", amount: 98, category: .health, createdAt: date(14, 10))
        let seaweedScene = LifeSceneSemanticService.classify(seaweed)
        let videoScene = LifeSceneSemanticService.classify(video)
        XCTAssertNotEqual(seaweed.displayEmotionTag, "给衣柜添一件")
        XCTAssertNotEqual(video.displayEmotionTag, "健身会员安排")
        XCTAssertNotEqual(seaweedScene.kind, .shopping)
        XCTAssertNotEqual(videoScene.kind, .fitness)
    }

    func testPersistedNarrowEmotionTagsAreCorrectedByCurrentTitleEvidence() {
        let seaweed = HomeItem(
            title: "裙带菜",
            amount: 12,
            category: .shopping,
            createdAt: date(14, 10),
            emotionTag: "给衣柜添一件"
        )
        let video = HomeItem(
            title: "视频会员年卡",
            amount: 98,
            category: .health,
            createdAt: date(14, 10),
            emotionTag: "健身会员安排"
        )
        let inspection = HomeItem(
            title: "机动车年检",
            amount: 260,
            category: .transport,
            createdAt: date(14, 10),
            emotionTag: "远一点的路"
        )

        XCTAssertNotEqual(seaweed.displayEmotionTag, "给衣柜添一件")
        XCTAssertNotEqual(video.displayEmotionTag, "健身会员安排")
        XCTAssertNotEqual(inspection.displayEmotionTag, "远一点的路")
    }

    func testSceneLexiconDoesNotPromoteOrdinaryFoodToolsOrAdultNutritionToBabyCare() {
        let food = HomeItem(title: "桂林米粉", amount: 18, category: .dining, createdAt: date(14, 10))
        let cart = HomeItem(title: "手推车", amount: 80, category: .shopping, createdAt: date(14, 10))
        let adultNutrition = HomeItem(title: "成人奶粉", amount: 120, category: .daily, createdAt: date(14, 10))

        XCTAssertNotEqual(LifeSceneSemanticService.classify(food).kind, .homeSupply)
        XCTAssertNotEqual(LifeSceneSemanticService.classify(cart).kind, .homeSupply)
        XCTAssertNotEqual(LifeSceneSemanticService.classify(adultNutrition).kind, .homeSupply)
    }

    func testVehicleMaintenanceDoesNotBecomeAnOutingScene() {
        let charging = HomeItem(title: "电动车充电", amount: 8, category: .transport, createdAt: date(14, 10))
        let inspection = HomeItem(title: "机动车年检", amount: 120, category: .transport, createdAt: date(14, 10))

        XCTAssertNotEqual(LifeSceneSemanticService.classify(charging).kind, .cityRoute)
        XCTAssertNotEqual(LifeSceneSemanticService.classify(inspection).kind, .cityRoute)
    }

    func testLifeMarkLearningGrowthRequiresLearningEvidence() {
        let item = HomeItem(title: "另记两笔，分了几笔", amount: 36, category: .shopping, createdAt: date(14, 10))
        let marks = LifeMarkService.aggregates(for: [item], allItems: [item], isMember: false)
        XCTAssertFalse(marks.contains(where: { $0.id == "learning_growth" }))
    }

}

final class RecordPreviewTierBoundaryTests: XCTestCase {
    func testCategoryVisibilityDoesNotRequireGeneratingANote() {
        XCTAssertTrue(RecordPreviewTier.whisper.showsCategory(hasResolvedCategory: true))
        XCTAssertFalse(RecordPreviewTier.whisper.showsCategory(hasResolvedCategory: false))
        for resolved in [false, true] {
            XCTAssertFalse(RecordPreviewTier.hidden.showsCategory(hasResolvedCategory: resolved))
            XCTAssertTrue(RecordPreviewTier.confirm.showsCategory(hasResolvedCategory: resolved))
        }
    }

    func testAmountOnlyInputRemainsVisibleWhisperTier() {
        let tier = RecordPreviewTier.resolve(.init(
            amount: 18,
            itemsCount: 0,
            hasBrand: false,
            hasNote: false,
            previewLineWasRotated: false,
            isEditing: false,
            prefillSource: nil,
            prefillConfidence: nil
        ))

        XCTAssertEqual(tier, .whisper)
    }

    func testInvalidAmountKeepsPreviewHidden() {
        let tier = RecordPreviewTier.resolve(.init(
            amount: 0,
            itemsCount: 0,
            hasBrand: false,
            hasNote: false,
            previewLineWasRotated: false,
            isEditing: false,
            prefillSource: nil,
            prefillConfidence: nil
        ))

        XCTAssertEqual(tier, .hidden)
    }
}

final class LedgerPersistenceRevisionPolicyTests: XCTestCase {
    func testOnlyCurrentPersistenceCompletionCanPublishOrRollback() {
        XCTAssertTrue(LedgerPersistenceRevisionPolicy.acceptsCompletion(
            completionRevision: 8,
            currentRevision: 8
        ))
        XCTAssertFalse(LedgerPersistenceRevisionPolicy.acceptsCompletion(
            completionRevision: 7,
            currentRevision: 8
        ))
    }

    func testOlderRecordCompletionDoesNotOwnNewerRevisionResult() {
        XCTAssertFalse(LedgerPersistenceRevisionPolicy.ownsRecordCompletion(
            completionRevision: 7,
            latestRevisionForRecord: 8
        ))
        XCTAssertTrue(LedgerPersistenceRevisionPolicy.ownsRecordCompletion(
            completionRevision: 8,
            latestRevisionForRecord: 8
        ))
        XCTAssertFalse(LedgerPersistenceRevisionPolicy.ownsRecordCompletion(
            completionRevision: 8,
            latestRevisionForRecord: nil
        ))
    }

    func testPersistenceProjectionReleasesImageBytesFromDerivedCache() {
        let id = UUID()
        let reference = "images/\(id.uuidString.lowercased())/photo.jpg"
        let full = HomeItem(
            id: id,
            title: "带图账单",
            amount: 18,
            category: .shopping,
            memoryImageDatas: [Data(repeating: 1, count: 128)],
            memoryImageReferences: [reference],
            memoryImageByteCounts: [128]
        )
        var metadata = full
        metadata.setExternalMemoryImages(
            references: [reference],
            data: [Data()],
            byteCounts: [128]
        )
        var snapshot = ItemDerivedCacheSnapshot.empty(for: .init(ledgerRevision: 1, dayKey: "2026-09-15"))
        snapshot.todayPositiveItems = [full]
        snapshot.replaceItems(with: [id: metadata])

        XCTAssertNil(snapshot.todayPositiveItems[0].memoryImageData(at: 0))
        XCTAssertEqual(snapshot.todayPositiveItems[0].memoryImageReference(at: 0), reference)
        XCTAssertEqual(snapshot.todayPositiveItems[0].memoryImageByteCount(at: 0), 128)
    }
}

final class AICommuteBoundaryTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    func testTodayCommuteSlotsNeverIncludeFutureTime() {
        let day = date(2026, 7, 15, 0, 0)

        XCTAssertEqual(
            AICommuteDraftSchedule.eligibleSlots(for: day, now: date(2026, 7, 15, 8, 29), calendar: calendar).map(\.title),
            []
        )
        XCTAssertEqual(
            AICommuteDraftSchedule.eligibleSlots(for: day, now: date(2026, 7, 15, 8, 30), calendar: calendar).map(\.title),
            ["早高峰通勤"]
        )
        XCTAssertEqual(
            AICommuteDraftSchedule.eligibleSlots(for: day, now: date(2026, 7, 15, 18, 29), calendar: calendar).map(\.title),
            ["早高峰通勤"]
        )
        XCTAssertEqual(
            AICommuteDraftSchedule.eligibleSlots(for: day, now: date(2026, 7, 15, 18, 30), calendar: calendar).map(\.title),
            ["早高峰通勤", "晚高峰通勤"]
        )
    }

    func testHistoricalDayKeepsBothCommuteSlots() {
        let historicalDay = date(2026, 7, 14, 0, 0)
        let now = date(2026, 7, 15, 7, 0)

        XCTAssertEqual(
            AICommuteDraftSchedule.eligibleSlots(for: historicalDay, now: now, calendar: calendar).map(\.title),
            ["早高峰通勤", "晚高峰通勤"]
        )
    }

    func testStrongDirectionCuesOverrideNonstandardHours() {
        let day = date(2026, 7, 17, 0, 0)
        let morningSlot = AICommuteDraftSchedule.slots[0]
        let eveningSlot = AICommuteDraftSchedule.slots[1]
        let work = HomeItem(title: "上班", amount: 4.75, category: .transport, createdAt: date(2026, 7, 17, 13, 48))

        XCTAssertTrue(AICommuteDuplicatePolicy.matches(work, slot: morningSlot, day: day, proposedAmount: 4.75, calendar: calendar))
        XCTAssertFalse(AICommuteDuplicatePolicy.matches(work, slot: eveningSlot, day: day, proposedAmount: 4.75, calendar: calendar))
    }

    func testDirectionlessLateCommuteOnlyBlocksEveningSlot() {
        let day = date(2026, 7, 17, 0, 0)
        let morningSlot = AICommuteDraftSchedule.slots[0]
        let eveningSlot = AICommuteDraftSchedule.slots[1]
        let commute = HomeItem(title: "通勤路上记一笔", amount: 4.75, category: .transport, createdAt: date(2026, 7, 17, 22, 55))

        XCTAssertFalse(AICommuteDuplicatePolicy.matches(commute, slot: morningSlot, day: day, proposedAmount: 4.75, calendar: calendar))
        XCTAssertTrue(AICommuteDuplicatePolicy.matches(commute, slot: eveningSlot, day: day, proposedAmount: 4.75, calendar: calendar))
    }

    func testOrdinaryTransportAndTravelDoNotBlockCommuteSlots() {
        let day = date(2026, 7, 17, 0, 0)
        let morningSlot = AICommuteDraftSchedule.slots[0]
        let taxi = HomeItem(title: "临时打车", amount: 4.75, category: .transport, createdAt: date(2026, 7, 17, 8, 10))
        let train = HomeItem(title: "高铁出差", amount: 4.75, category: .transport, createdAt: date(2026, 7, 17, 8, 20))

        XCTAssertFalse(AICommuteDuplicatePolicy.matches(taxi, slot: morningSlot, day: day, proposedAmount: 4.75, calendar: calendar))
        XCTAssertFalse(AICommuteDuplicatePolicy.matches(train, slot: morningSlot, day: day, proposedAmount: 4.75, calendar: calendar))
    }

    func testAmountMismatchDoesNotBlockMatchingDirection() {
        let day = date(2026, 7, 17, 0, 0)
        let morningSlot = AICommuteDraftSchedule.slots[0]
        let work = HomeItem(title: "上班", amount: 42, category: .transport, createdAt: date(2026, 7, 17, 13, 48))

        XCTAssertFalse(AICommuteDuplicatePolicy.matches(work, slot: morningSlot, day: day, proposedAmount: 4.75, calendar: calendar))
    }

    func testLateEnteredMorningTransportUsesStableHistoricalCommuteEvidence() {
        let target = HomeItem(
            title: "",
            amount: 4.75,
            category: .transport,
            createdAt: date(2026, 7, 17, 9, 7)
        )
        let history = [
            HomeItem(title: "早高峰通勤", amount: 4.75, category: .transport, createdAt: date(2026, 7, 15, 8, 32)),
            HomeItem(title: "上班地铁", amount: 4.75, category: .transport, createdAt: date(2026, 7, 16, 8, 28))
        ]

        XCTAssertTrue(
            CommuteEvidencePolicy.matches(
                target,
                historyItems: history,
                calendar: calendar
            )
        )

        let morningSlot = AICommuteDraftSchedule.slots[0]
        XCTAssertTrue(
            AICommuteDuplicatePolicy.matches(
                target,
                slot: morningSlot,
                day: date(2026, 7, 17, 0, 0),
                proposedAmount: 4.75,
                historyItems: history,
                calendar: calendar
            )
        )

        let aggregates = LifeMarkService.aggregates(
            for: [target],
            allItems: [target] + history,
            isMember: true,
            now: date(2026, 7, 17, 12, 0)
        )
        XCTAssertTrue(aggregates.contains { $0.id == "commute" && $0.itemIDs == [target.id] })
    }

    func testLowAmountTransportWithoutHistoricalEvidenceDoesNotBecomeCommute() {
        let taxi = HomeItem(
            title: "临时打车",
            amount: 4.75,
            category: .transport,
            createdAt: date(2026, 7, 17, 9, 7)
        )
        XCTAssertFalse(
            CommuteEvidencePolicy.matches(
                taxi,
                historyItems: [],
                calendar: calendar
            )
        )
    }
}

final class PlaybackQuotaRegressionTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "PlaybackQuotaRegressionTests")!
        defaults.removePersistentDomain(forName: "PlaybackQuotaRegressionTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "PlaybackQuotaRegressionTests")
        defaults = nil
        super.tearDown()
    }

    func testPlaybackQuotaChangesOnlyAfterExplicitStart() {
        let store = DailyFeatureQuotaStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_768_000_000)

        XCTAssertEqual(store.todayPlaybackRemaining(isMember: false, now: now), 3)
        XCTAssertTrue(store.canPlayTodayPlayback(isMember: false, now: now))
        XCTAssertEqual(store.todayPlaybackRemaining(isMember: false, now: now), 3)

        store.markTodayPlaybackStarted(isMember: false, now: now)
        XCTAssertEqual(store.todayPlaybackRemaining(isMember: false, now: now), 2)
    }
}

final class TraceLifePreparationPolicyTests: XCTestCase {
    func testInitialEntryBuildsOnlyVisibleRangeThenPrewarmsTheOther() {
        XCTAssertTrue(
            TraceLifePreparationPolicy.needsPrimaryPreparation(
                selectedRange: .week,
                weekNeedsRefresh: true,
                monthNeedsRefresh: true,
                hasWeek: false,
                hasMonth: false
            )
        )
        XCTAssertEqual(TraceLifePreparationPolicy.prewarmRange(after: .week), .month)
        XCTAssertEqual(TraceLifePreparationPolicy.prewarmRange(after: .month), .week)
    }

    func testSwitchingToMissingMonthDoesNotExposeWeekDuringPreparation() {
        XCTAssertFalse(
            TraceLifePreparationPolicy.hasVisibleSnapshot(
                selectedRange: .month,
                hasWeek: true,
                hasMonth: false
            )
        )
        XCTAssertTrue(
            TraceLifePreparationPolicy.needsPrimaryPreparation(
                selectedRange: .month,
                weekNeedsRefresh: false,
                monthNeedsRefresh: true,
                hasWeek: true,
                hasMonth: false
            )
        )
    }

    func testSwitchingToMissingWeekDoesNotExposeMonthDuringPreparation() {
        XCTAssertFalse(
            TraceLifePreparationPolicy.hasVisibleSnapshot(
                selectedRange: .week,
                hasWeek: false,
                hasMonth: true
            )
        )
        XCTAssertTrue(
            TraceLifePreparationPolicy.hasVisibleSnapshot(
                selectedRange: .week,
                hasWeek: true,
                hasMonth: false
            )
        )
    }

    func testPreparedVisibleRangeDoesNotRebuildWhileOtherRangeWarms() {
        XCTAssertFalse(
            TraceLifePreparationPolicy.needsPrimaryPreparation(
                selectedRange: .week,
                weekNeedsRefresh: false,
                monthNeedsRefresh: true,
                hasWeek: true,
                hasMonth: false
            )
        )
    }
}

final class TraceSnapshotVisibilityPolicyTests: XCTestCase {
    func testLifeRangeMustMatchTheSelectedPresetPeriod() {
        XCTAssertTrue(
            TraceSnapshotVisibilityPolicy.representsSelectedLifeRange(
                range: .month,
                selectedPeriod: .month,
                usesCustomRange: false
            )
        )
        XCTAssertFalse(
            TraceSnapshotVisibilityPolicy.representsSelectedLifeRange(
                range: .month,
                selectedPeriod: .week,
                usesCustomRange: false
            )
        )
        XCTAssertFalse(
            TraceSnapshotVisibilityPolicy.representsSelectedLifeRange(
                range: .month,
                selectedPeriod: .month,
                usesCustomRange: true
            )
        )
    }

    func testChapterRequiresSelectedRangeAndExactPublicationKey() {
        XCTAssertTrue(
            TraceSnapshotVisibilityPolicy.canDisplayChapter(
                selectedRange: .month,
                snapshotRange: .month,
                publishedKey: "month-current",
                expectedKey: "month-current"
            )
        )
        XCTAssertFalse(
            TraceSnapshotVisibilityPolicy.canDisplayChapter(
                selectedRange: .month,
                snapshotRange: .week,
                publishedKey: "month-current",
                expectedKey: "month-current"
            )
        )
        XCTAssertFalse(
            TraceSnapshotVisibilityPolicy.canDisplayChapter(
                selectedRange: .month,
                snapshotRange: .month,
                publishedKey: "month-old",
                expectedKey: "month-current"
            )
        )
    }

    func testColdStartDisplayRequiresTheExactSelectedScope() {
        XCTAssertTrue(
            TraceSnapshotVisibilityPolicy.canDisplayColdStart(
                publishedScopeKey: "life|month",
                expectedScopeKey: "life|month"
            )
        )
        XCTAssertFalse(
            TraceSnapshotVisibilityPolicy.canDisplayColdStart(
                publishedScopeKey: "life|week",
                expectedScopeKey: "life|month"
            )
        )
    }
}

final class TraceDeferredScrollPolicyTests: XCTestCase {
    func testRepeatedTargetRequiresResetBeforeReissuingTheAnchor() {
        XCTAssertTrue(
            TraceDeferredScrollPolicy.requiresAnchorReset(
                currentAnchorID: TraceDeferredScrollPolicy.lifeChapterAnchorID,
                targetAnchorID: TraceDeferredScrollPolicy.lifeChapterAnchorID
            )
        )
    }

    func testMissingOrDifferentTargetDoesNotNeedAnAnchorReset() {
        XCTAssertFalse(
            TraceDeferredScrollPolicy.requiresAnchorReset(
                currentAnchorID: nil,
                targetAnchorID: TraceDeferredScrollPolicy.lifeChapterAnchorID
            )
        )
        XCTAssertFalse(
            TraceDeferredScrollPolicy.requiresAnchorReset(
                currentAnchorID: "trace-clue-board",
                targetAnchorID: TraceDeferredScrollPolicy.lifeChapterAnchorID
            )
        )
    }
}

final class TraceLoadingPresentationPolicyTests: XCTestCase {
    func testInitialMonthTraceShowsOneImmediateAccuratePresentation() {
        let presentation = TraceLoadingPresentationPolicy.make(
            viewMode: .life,
            selectedPeriod: .month,
            lifeRange: .month,
            usesCustomRange: false,
            hasCompleteSnapshot: false
        )

        XCTAssertEqual(presentation.message, "正在整理本月痕迹…")
        XCTAssertEqual(presentation.delayNanoseconds, 0)
        XCTAssertEqual(presentation.detail, "已可浏览和记账，完整内容会在后台补齐")
    }

    func testRefreshWithExistingSnapshotDelaysTheInlineStatus() {
        let presentation = TraceLoadingPresentationPolicy.make(
            viewMode: .life,
            selectedPeriod: .week,
            lifeRange: .week,
            usesCustomRange: false,
            hasCompleteSnapshot: true
        )

        XCTAssertEqual(
            presentation.delayNanoseconds,
            TraceLoadingPresentationPolicy.refreshDelayNanoseconds
        )
        XCTAssertEqual(presentation.detail, "当前内容可继续使用，最新结果会在后台更新")
    }

    func testClueCopyUsesOneContinuousScopeRegardlessOfLifeRange() {
        let month = TraceLoadingPresentationPolicy.make(
            viewMode: .clues,
            selectedPeriod: .month,
            lifeRange: .week,
            usesCustomRange: false,
            hasCompleteSnapshot: false
        )
        let custom = TraceLoadingPresentationPolicy.make(
            viewMode: .clues,
            selectedPeriod: .month,
            lifeRange: .week,
            usesCustomRange: true,
            hasCompleteSnapshot: false
        )

        XCTAssertEqual(month.message, "正在整理生活线索…")
        XCTAssertEqual(custom.message, "正在整理生活线索…")
    }

    func testColdStartStatusDoesNotDefineInteractionBlocking() {
        let presentation = TraceLoadingPresentationPolicy.make(
            viewMode: .life,
            selectedPeriod: .month,
            lifeRange: .month,
            usesCustomRange: false,
            hasCompleteSnapshot: false
        )

        XCTAssertEqual(presentation.delayNanoseconds, 0)
        XCTAssertEqual(presentation.detail, "已可浏览和记账，完整内容会在后台补齐")
        let firstScreen = TraceFirstScreenPresentationPolicy.loadedLedgerFacts(
            ledgerRevision: 1,
            dayKey: "2026-09-05",
            scopeKey: "life|month",
            periodLabel: "本月痕迹",
            loadedRecordCount: 0
        )
        XCTAssertFalse(TraceFirstScreenPresentationPolicy.blocksInteraction(
            hasCompleteSnapshot: false,
            firstScreen: firstScreen
        ))
    }
}

final class TraceFirstScreenProgressivePolicyTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .iso8601)
        value.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return value
    }

    private var now: Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: 5,
            hour: 12
        ))!
    }

    func testTraceRecordEntryIsLimitedToTheLifeFirstScreen() {
        XCTAssertEqual(
            TraceFirstScreenRecordEntryPolicy.title(
                viewMode: .life,
                lifeRange: .month,
                usesCustomRange: false
            ),
            "查看本月记录"
        )
        XCTAssertEqual(
            TraceFirstScreenRecordEntryPolicy.title(
                viewMode: .life,
                lifeRange: .week,
                usesCustomRange: false
            ),
            "查看本周记录"
        )
        XCTAssertEqual(
            TraceFirstScreenRecordEntryPolicy.title(
                viewMode: .life,
                lifeRange: .month,
                usesCustomRange: true
            ),
            "查看这段记录"
        )
        XCTAssertNil(
            TraceFirstScreenRecordEntryPolicy.title(
                viewMode: .clues,
                lifeRange: .month,
                usesCustomRange: false
            )
        )
    }

    func testEmptyAndSmallLedgersAlwaysHaveAnInteractiveFirstScreen() {
        for count in [0, 5] {
            let presentation = TraceFirstScreenPresentationPolicy.loadedLedgerFacts(
                ledgerRevision: count,
                dayKey: "2026-09-05",
                scopeKey: "clue|rolling-13-weeks-v1|all",
                periodLabel: "生活线索",
                loadedRecordCount: count
            )

            XCTAssertEqual(presentation.recordCount, count)
            XCTAssertEqual(presentation.isLedgerEmpty, count == 0)
            XCTAssertFalse(presentation.hasDetailedFacts)
            XCTAssertTrue(TraceFirstScreenPresentationPolicy.hasUsableFirstScreen(presentation))
            XCTAssertFalse(TraceFirstScreenPresentationPolicy.blocksInteraction(
                hasCompleteSnapshot: false,
                firstScreen: presentation
            ))
        }
    }

    func testCachedFirstScreenRequiresExactFingerprintDayMemberScopeAndPolicy() {
        let entry = TraceColdStartDisplayEntry(
            scopeKey: "clue|rolling-13-weeks-v1|all",
            savedAt: now,
            title: "同一账本的安全摘要",
            summary: "只承接完全匹配的内容。",
            periodLabel: "生活线索",
            recordCount: 8,
            activeDayCount: 4,
            total: 188,
            topCategory: "餐饮"
        )
        let expected = cacheIdentity()

        XCTAssertNotNil(TraceFirstScreenPresentationPolicy.exactCache(
            entry: entry,
            cachedIdentity: expected,
            expectedIdentity: expected
        ))

        let mismatches = [
            cacheIdentity(fingerprint: "other"),
            cacheIdentity(dayKey: "2026-09-06"),
            cacheIdentity(isMember: true),
            cacheIdentity(scopeKey: "clue|rolling-13-weeks-v1|餐饮"),
            cacheIdentity(displayPolicyVersion: TraceFirstScreenPresentationPolicy.currentDisplayPolicyVersion + 1)
        ]
        for mismatch in mismatches {
            XCTAssertNil(TraceFirstScreenPresentationPolicy.exactCache(
                entry: entry,
                cachedIdentity: expected,
                expectedIdentity: mismatch
            ))
        }
    }

    func testStageTwoPublicationRejectsEveryStaleIdentityDimension() {
        let current = preparationIdentity()
        XCTAssertTrue(TraceProgressivePublicationPolicy.accepts(
            candidateIdentity: current,
            pendingIdentity: current,
            currentIdentity: current,
            requestMatches: true,
            isSceneActive: true
        ))
        XCTAssertFalse(TraceProgressivePublicationPolicy.accepts(
            candidateIdentity: current,
            pendingIdentity: current,
            currentIdentity: current,
            requestMatches: false,
            isSceneActive: true
        ))
        XCTAssertFalse(TraceProgressivePublicationPolicy.accepts(
            candidateIdentity: current,
            pendingIdentity: current,
            currentIdentity: current,
            requestMatches: true,
            isSceneActive: false
        ))

        let staleIdentities = [
            preparationIdentity(revision: 10),
            preparationIdentity(scopeKey: "clue|rolling-13-weeks-v1|餐饮"),
            preparationIdentity(snapshotKey: "snapshot:other"),
            preparationIdentity(isMember: true),
            preparationIdentity(dayKey: "2026-09-06"),
            preparationIdentity(contentRevision: 4)
        ]
        for stale in staleIdentities {
            XCTAssertFalse(TraceProgressivePublicationPolicy.accepts(
                candidateIdentity: stale,
                pendingIdentity: stale,
                currentIdentity: current,
                requestMatches: true,
                isSceneActive: true
            ))
        }
    }

    func testBackgroundCancelsAndForegroundResumesOnlyOneLatestIdentity() {
        let latest = preparationIdentity()
        let stale = preparationIdentity(revision: 10)

        XCTAssertTrue(TraceProgressiveLifecyclePolicy.shouldCancel(isSceneActive: false))
        XCTAssertFalse(TraceProgressiveLifecyclePolicy.shouldCancel(isSceneActive: true))
        XCTAssertEqual(
            TraceProgressiveLifecyclePolicy.identityToResume(
                isSceneActive: true,
                latestRequestedIdentity: latest,
                currentIdentity: latest,
                hasCompleteSnapshot: false,
                lastResumedIdentity: nil
            ),
            latest
        )
        XCTAssertNil(TraceProgressiveLifecyclePolicy.identityToResume(
            isSceneActive: true,
            latestRequestedIdentity: latest,
            currentIdentity: latest,
            hasCompleteSnapshot: false,
            lastResumedIdentity: latest
        ))
        XCTAssertNil(TraceProgressiveLifecyclePolicy.identityToResume(
            isSceneActive: true,
            latestRequestedIdentity: stale,
            currentIdentity: latest,
            hasCompleteSnapshot: false
        ))
        XCTAssertNil(TraceProgressiveLifecyclePolicy.identityToResume(
            isSceneActive: false,
            latestRequestedIdentity: latest,
            currentIdentity: latest,
            hasCompleteSnapshot: false
        ))
        XCTAssertNil(TraceProgressiveLifecyclePolicy.identityToResume(
            isSceneActive: true,
            latestRequestedIdentity: latest,
            currentIdentity: latest,
            hasCompleteSnapshot: true
        ))
    }

    func testProgressiveClueMatchesDirectFullComputationAtReleaseScales() {
        for count in [0, 5, 100, 1_000, 5_000] {
            let allItems = makeItems(count: count)
            let scopedItems = TraceClueScopePolicy.items(
                from: allItems,
                now: now,
                calendar: calendar
            )
            let direct = TraceSnapshotComputation.buildClue(
                TraceClueComputationInput(
                    items: scopedItems,
                    allItems: allItems,
                    period: .month,
                    periodLabel: TraceClueScopePolicy.periodLabel,
                    isMember: false,
                    freeRemaining: LifeInsightService.freeMonthlyLimit,
                    storedUnlock: false,
                    sourceRevision: 11,
                    narrativeScope: TraceClueScopePolicy.narrativeScope,
                    allowsNarrativeRewrite: false,
                    now: now,
                    scope: TraceClueScopePolicy.scope
                )
            )
            let progressive = TraceSnapshotComputation.buildProgressiveClue(
                TraceClueProgressiveInput(
                    allItems: allItems,
                    category: nil,
                    period: .month,
                    periodLabel: TraceClueScopePolicy.periodLabel,
                    isMember: false,
                    freeRemaining: LifeInsightService.freeMonthlyLimit,
                    unlockedTraceKeys: [],
                    sourceRevision: 11,
                    narrativeScope: TraceClueScopePolicy.narrativeScope,
                    allowsNarrativeRewrite: false,
                    now: now,
                    scope: TraceClueScopePolicy.scope
                )
            )

            XCTAssertEqual(progressive, direct, "record count: \(count)")
        }
    }

    func testProgressiveWeekAndMonthChaptersMatchDirectFullComputationAtReleaseScales() throws {
        for count in [0, 5, 100, 1_000, 5_000] {
            let allItems = makeItems(count: count)
            for range in [SummaryPlaybackRange.week, .month] {
                let periodCalendar = range == .week ? PlaybackService.isoCalendar : Calendar.current
                let component: Calendar.Component = range == .week ? .weekOfYear : .month
                let interval = try XCTUnwrap(periodCalendar.dateInterval(of: component, for: now))
                let items = allItems
                    .filter {
                        $0.createdAt >= interval.start
                            && $0.createdAt < interval.end
                            && $0.amount > 0
                            && $0.draftMeta == nil
                    }
                    .sorted {
                        if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
                        return $0.id.uuidString < $1.id.uuidString
                    }
                let periodKey = "progressive-equivalence-\(range.rawValue)-\(count)"
                let direct = TraceSnapshotComputation.buildChapter(
                    TraceChapterComputationInput(
                        range: range,
                        items: items,
                        allItems: allItems,
                        isMember: false,
                        prioritizeRecurringMarks: range == .month,
                        periodKey: periodKey,
                        usesEchoAnchor: true,
                        sourceRevision: 11,
                        now: now
                    )
                )
                let progressive = try XCTUnwrap(
                    TraceSnapshotComputation.buildProgressiveChapter(
                        TraceChapterProgressiveInput(
                            range: range,
                            allItems: allItems,
                            interval: interval,
                            isMember: false,
                            prioritizeRecurringMarks: range == .month,
                            periodKey: periodKey,
                            usesEchoAnchor: true,
                            sourceRevision: 11,
                            now: now
                        )
                    )
                )

                assertChapterSnapshotsEquivalent(
                    progressive,
                    direct,
                    context: "\(range.rawValue), record count: \(count)"
                )
            }
        }
    }

    private func assertChapterSnapshotsEquivalent(
        _ actual: TraceChapterSnapshot,
        _ expected: TraceChapterSnapshot,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.range, expected.range, context, file: file, line: line)
        XCTAssertEqual(actual.items, expected.items, context, file: file, line: line)
        XCTAssertEqual(actual.periodFacts.range, expected.periodFacts.range, context, file: file, line: line)
        XCTAssertEqual(actual.periodFacts.sourceRevision, expected.periodFacts.sourceRevision, context, file: file, line: line)
        XCTAssertEqual(actual.periodFacts.isMember, expected.periodFacts.isMember, context, file: file, line: line)
        XCTAssertEqual(actual.periodFacts.preparedAt, expected.periodFacts.preparedAt, context, file: file, line: line)
        XCTAssertEqual(actual.periodFacts.periodStart, expected.periodFacts.periodStart, context, file: file, line: line)
        XCTAssertEqual(actual.periodFacts.periodEnd, expected.periodFacts.periodEnd, context, file: file, line: line)
        XCTAssertEqual(actual.periodFacts.periodItems, expected.periodFacts.periodItems, context, file: file, line: line)
        XCTAssertEqual(actual.periodFacts.previousPeriodItems, expected.periodFacts.previousPeriodItems, context, file: file, line: line)
        XCTAssertEqual(actual.periodFacts.lifeMarks, expected.periodFacts.lifeMarks, context, file: file, line: line)
        XCTAssertEqual(actual.periodFacts.journeyFact, expected.periodFacts.journeyFact, context, file: file, line: line)
        XCTAssertEqual(actual.periodFacts.narrativeEcho, expected.periodFacts.narrativeEcho, context, file: file, line: line)
        XCTAssertEqual(actual.periodFacts.narrativePlan, expected.periodFacts.narrativePlan, context, file: file, line: line)
        XCTAssertEqual(actual.periodFacts.narrativeRewrite, expected.periodFacts.narrativeRewrite, context, file: file, line: line)
        XCTAssertEqual(actual.periodFacts.weeklyShareLifeMark, expected.periodFacts.weeklyShareLifeMark, context, file: file, line: line)
        XCTAssertEqual(actual.periodFacts.auxiliaryMetrics, expected.periodFacts.auxiliaryMetrics, context, file: file, line: line)
        XCTAssertEqual(actual.marks, expected.marks, context, file: file, line: line)
        XCTAssertEqual(actual.memoryAnchors, expected.memoryAnchors, context, file: file, line: line)
        XCTAssertEqual(actual.monthDiaryAnchors, expected.monthDiaryAnchors, context, file: file, line: line)
        XCTAssertEqual(actual.coverFacts, expected.coverFacts, context, file: file, line: line)
        XCTAssertEqual(actual.narrativePlan, expected.narrativePlan, context, file: file, line: line)
        XCTAssertEqual(actual.narrativeRewrite, expected.narrativeRewrite, context, file: file, line: line)
        XCTAssertEqual(actual.narrative, expected.narrative, context, file: file, line: line)
        XCTAssertEqual(actual.chapterSummary, expected.chapterSummary, context, file: file, line: line)
        XCTAssertEqual(actual.evidenceGroups.count, expected.evidenceGroups.count, context, file: file, line: line)
        for (actualGroup, expectedGroup) in zip(actual.evidenceGroups, expected.evidenceGroups) {
            XCTAssertEqual(actualGroup.id, expectedGroup.id, context, file: file, line: line)
            XCTAssertEqual(actualGroup.markLabel, expectedGroup.markLabel, context, file: file, line: line)
            XCTAssertEqual(actualGroup.items, expectedGroup.items, context, file: file, line: line)
            XCTAssertEqual(actualGroup.overflowCount, expectedGroup.overflowCount, context, file: file, line: line)
        }
        XCTAssertEqual(actual.preview.count, expected.preview.count, context, file: file, line: line)
        XCTAssertEqual(actual.preview.total, expected.preview.total, context, file: file, line: line)
        XCTAssertEqual(actual.preview.chapterCount, expected.preview.chapterCount, context, file: file, line: line)
        XCTAssertEqual(actual.preview.topCategory, expected.preview.topCategory, context, file: file, line: line)
    }

    private func cacheIdentity(
        fingerprint: String = "ledger-a",
        dayKey: String = "2026-09-05",
        isMember: Bool = false,
        scopeKey: String = "clue|rolling-13-weeks-v1|all",
        displayPolicyVersion: Int = TraceFirstScreenPresentationPolicy.currentDisplayPolicyVersion
    ) -> TraceFirstScreenCacheIdentity {
        TraceFirstScreenCacheIdentity(
            ledgerFingerprint: fingerprint,
            dayKey: dayKey,
            isMember: isMember,
            scopeKey: scopeKey,
            displayPolicyVersion: displayPolicyVersion
        )
    }

    private func preparationIdentity(
        revision: Int = 11,
        scopeKey: String = "clue|rolling-13-weeks-v1|all",
        snapshotKey: String = "snapshot:11",
        isMember: Bool = false,
        dayKey: String = "2026-09-05",
        contentRevision: Int = 3
    ) -> TraceProgressivePreparationIdentity {
        TraceProgressivePreparationIdentity(
            ledgerRevision: revision,
            scopeKey: scopeKey,
            snapshotKey: snapshotKey,
            isMember: isMember,
            dayKey: dayKey,
            contentRevision: contentRevision
        )
    }

    private func makeItems(count: Int) -> [HomeItem] {
        let categories = HomeItem.Category.allCases
        return (0..<count).map { index in
            let suffix = String(format: "%012X", index + 1)
            return HomeItem(
                id: UUID(uuidString: "F1000000-0000-0000-0000-\(suffix)")!,
                title: "回归记录 \(index)",
                amount: Double((index % 180) + 1),
                category: categories[index % categories.count],
                createdAt: now.addingTimeInterval(
                    -Double(index % 84) * 86_400 - Double(index % 30) * 60
                )
            )
        }
    }
}

final class TraceSnapshotLifecycleTests: XCTestCase {
    func testContinuousClueKeyIgnoresLifePeriodAndCustomRangeState() {
        let week = TraceSnapshotLifecycleKeyPolicy.continuousClueKey(
            ledgerRevision: 9,
            isMember: false,
            category: .dining,
            freeRemaining: 5,
            isUnlocked: false,
            dayKey: "2026-07-23",
            windowKey: "2026-04-20",
            contentRevision: 3
        )
        let month = TraceSnapshotLifecycleKeyPolicy.continuousClueKey(
            ledgerRevision: 9,
            isMember: false,
            category: .dining,
            freeRemaining: 5,
            isUnlocked: false,
            dayKey: "2026-07-23",
            windowKey: "2026-04-20",
            contentRevision: 3
        )

        XCTAssertEqual(week, month)
        XCTAssertTrue(week.hasPrefix("clue-v3|\(TraceClueScopePolicy.identifier)|"))
        XCTAssertEqual(
            TraceSnapshotLifecycleKeyPolicy.continuousClueColdStartScopeKey(category: .dining),
            "clue|\(TraceClueScopePolicy.identifier)|餐饮"
        )
    }

    func testContinuousClueWindowIncludesCurrentAndTwelvePreviousWeeksOnly() {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: 2,
            hour: 12
        ))!
        let items = [
            HomeItem(title: "当前", amount: 1, category: .dining, createdAt: now),
            HomeItem(title: "第12周", amount: 1, category: .dining, createdAt: now.addingTimeInterval(-12 * 7 * 86_400)),
            HomeItem(title: "第13周", amount: 1, category: .dining, createdAt: now.addingTimeInterval(-13 * 7 * 86_400)),
            HomeItem(title: "草稿", amount: 1, category: .dining, createdAt: now, draftMeta: .init(
                batchId: "test",
                importedAt: now,
                status: .pending
            ))
        ]

        let included = TraceClueScopePolicy.items(from: items, now: now, calendar: calendar)

        XCTAssertEqual(included.map(\.title), ["当前", "第12周"])
    }

    func testChapterAndClueKeysReuseOnlyTheSameRealSourceState() {
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let end = start.addingTimeInterval(6 * 24 * 60 * 60)
        let chapter = TraceSnapshotLifecycleKeyPolicy.chapterKey(
            range: .week,
            ledgerRevision: 9,
            periodKey: "2026-W30|2026-07-23",
            isMember: false,
            contentRevision: 2
        )
        XCTAssertTrue(chapter.hasPrefix("chapter-v3|"))
        XCTAssertEqual(
            chapter,
            TraceSnapshotLifecycleKeyPolicy.chapterKey(
                range: .week,
                ledgerRevision: 9,
                periodKey: "2026-W30|2026-07-23",
                isMember: false,
                contentRevision: 2
            )
        )
        XCTAssertNotEqual(
            chapter,
            TraceSnapshotLifecycleKeyPolicy.chapterKey(
                range: .week,
                ledgerRevision: 10,
                periodKey: "2026-W30|2026-07-23",
                isMember: false,
                contentRevision: 2
            )
        )
        XCTAssertNotEqual(
            chapter,
            TraceSnapshotLifecycleKeyPolicy.chapterKey(
                range: .month,
                ledgerRevision: 9,
                periodKey: "2026-07|2026-07-23",
                isMember: false,
                contentRevision: 2
            )
        )
        XCTAssertNotEqual(
            chapter,
            TraceSnapshotLifecycleKeyPolicy.chapterKey(
                range: .week,
                ledgerRevision: 9,
                periodKey: "2026-W30|2026-07-23",
                isMember: true,
                contentRevision: 2
            )
        )
        XCTAssertNotEqual(
            chapter,
            TraceSnapshotLifecycleKeyPolicy.chapterKey(
                range: .week,
                ledgerRevision: 9,
                periodKey: "2026-W30|2026-07-23",
                isMember: false,
                contentRevision: 3
            )
        )

        let preset = TraceSnapshotLifecycleKeyPolicy.clueKey(
            period: .month,
            ledgerRevision: 9,
            isMember: true,
            usesCustomRange: false,
            customStartDate: start,
            customEndDate: end,
            category: .dining,
            freeRemaining: 5,
            isUnlocked: false,
            dayKey: "2026-07-23",
            contentRevision: 3
        )
        let presetWithIrrelevantDatesChanged = TraceSnapshotLifecycleKeyPolicy.clueKey(
            period: .month,
            ledgerRevision: 9,
            isMember: true,
            usesCustomRange: false,
            customStartDate: start.addingTimeInterval(-90_000),
            customEndDate: end.addingTimeInterval(90_000),
            category: .dining,
            freeRemaining: 5,
            isUnlocked: false,
            dayKey: "2026-07-23",
            contentRevision: 3
        )
        let custom = TraceSnapshotLifecycleKeyPolicy.clueKey(
            period: .month,
            ledgerRevision: 9,
            isMember: true,
            usesCustomRange: true,
            customStartDate: start,
            customEndDate: end,
            category: .dining,
            freeRemaining: 5,
            isUnlocked: false,
            dayKey: "2026-07-23",
            contentRevision: 3
        )

        XCTAssertEqual(preset, presetWithIrrelevantDatesChanged)
        XCTAssertNotEqual(preset, custom)
        XCTAssertNotEqual(
            custom,
            TraceSnapshotLifecycleKeyPolicy.clueKey(
                period: .month,
                ledgerRevision: 9,
                isMember: true,
                usesCustomRange: true,
                customStartDate: start.addingTimeInterval(-90_000),
                customEndDate: end,
                category: .dining,
                freeRemaining: 5,
                isUnlocked: false,
                dayKey: "2026-07-23",
                contentRevision: 3
            )
        )
    }

    func testColdStartFingerprintIsStableAcrossOrderingAndChangesWithLedgerContent() {
        let first = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000081")!,
            title: "午餐",
            amount: 28,
            category: .dining,
            createdAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
        var second = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000082")!,
            title: "地铁",
            amount: 6,
            category: .transport,
            createdAt: Date(timeIntervalSince1970: 1_790_003_600)
        )
        let original = LedgerDisplayFingerprintPolicy.make(items: [first, second])

        XCTAssertEqual(
            original,
            LedgerDisplayFingerprintPolicy.make(items: [second, first])
        )

        second.amount = 8
        XCTAssertNotEqual(
            original,
            LedgerDisplayFingerprintPolicy.make(items: [first, second])
        )
    }

    func testColdStartDisplaySurvivesStoreRecreationButRejectsAnotherContext() {
        let suiteName = "TraceSnapshotLifecycleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let storageKey = "trace-test"
        let context = TraceColdStartDisplayContext(
            ledgerFingerprint: "ledger-a",
            dayKey: "2026-07-23",
            isMember: false
        )
        let entry = TraceColdStartDisplayEntry(
            scopeKey: "life|week",
            savedAt: Date(timeIntervalSince1970: 1_790_000_000),
            title: "这一周留下了几段生活",
            summary: "原内容先承接，最新快照在后台准备。",
            periodLabel: "本周痕迹",
            recordCount: 8,
            activeDayCount: 4,
            total: 188,
            topCategory: "餐饮"
        )

        TraceColdStartDisplayStore(defaults: defaults, storageKey: storageKey).store(
            entry,
            context: context
        )
        let relaunchedStore = TraceColdStartDisplayStore(
            defaults: defaults,
            storageKey: storageKey
        )

        XCTAssertEqual(
            relaunchedStore.entry(for: context, scopeKey: entry.scopeKey),
            entry
        )
        XCTAssertNil(
            relaunchedStore.entry(
                for: TraceColdStartDisplayContext(
                    ledgerFingerprint: "ledger-b",
                    dayKey: context.dayKey,
                    isMember: context.isMember
                ),
                scopeKey: entry.scopeKey
            )
        )
        XCTAssertNil(
            relaunchedStore.entry(
                for: TraceColdStartDisplayContext(
                    ledgerFingerprint: context.ledgerFingerprint,
                    dayKey: "2026-07-24",
                    isMember: context.isMember
                ),
                scopeKey: entry.scopeKey
            )
        )
        defaults.set(Data([0xFF, 0x00]), forKey: storageKey)
        XCTAssertNil(relaunchedStore.entry(for: context, scopeKey: entry.scopeKey))
        XCTAssertNil(defaults.data(forKey: storageKey))
    }
}

final class RecordInputAssistanceSnapshotTests: XCTestCase {
    func testDeferredQuickNotesKeepRecommendationAndHistoricalPoolIdentical() {
        let calendar = Calendar.current
        let reference = calendar.date(bySettingHour: 18, minute: 43, second: 0, of: Date())!
        let dates = (1...60).compactMap { calendar.date(byAdding: .day, value: -$0, to: reference) }
            .filter { RecordCalendarContext.dayKind(for: $0) == RecordCalendarContext.dayKind(for: reference) }
            .prefix(8)
        let items = dates.map {
            HomeItem(title: "牛肉面", amount: 36, category: .dining, createdAt: $0, userEditedTitle: true)
        }
        let key = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: 386, referenceDate: reference, referenceDateEditedByUser: true
        )
        let input = RecordInputHistoryPreparationInput(key: key, items: items, referenceDate: reference, now: reference)
        let combined = RecordInputAssistanceComputation.historySnapshot(input)
        let critical = RecordInputAssistanceComputation.historySnapshot(input, includeQuickNoteHistory: false)
        XCTAssertFalse(combined.quickNoteTitlesByContext.isEmpty)
        XCTAssertTrue(critical.quickNoteTitlesByContext.isEmpty)
        XCTAssertEqual(critical.key, combined.key)
        XCTAssertEqual(critical.prefillItems.map(\.id), combined.prefillItems.map(\.id))
        XCTAssertFalse(critical.frequentSuggestions.isEmpty)
        XCTAssertEqual(critical.frequentSuggestions, combined.frequentSuggestions)
        XCTAssertEqual(critical.frequentTitlesBySuggestionID, combined.frequentTitlesBySuggestionID)
        XCTAssertEqual(combined.quickNoteTitlesByContext, RecordQuickNotePolicy.historicalTitles(items: items, at: reference))
        let context = RecordContextSignal(referenceDate: reference, weather: nil)
        let prefillKey = RecordPrefillPreparationKey(
            historyKey: key, amount: 36, referenceDate: reference, noteDraft: "", selectedCategory: .other, context: context
        )
        func recommendation(_ history: RecordInputHistorySnapshot) -> RecordPrefillSnapshot {
            RecordInputAssistanceComputation.prefillSnapshot(.init(
                key: prefillKey, history: history, amount: 36, referenceDate: reference, now: reference,
                noteDraft: "", selectedCategory: .other, context: context
            ))
        }
        let old = recommendation(combined)
        let new = recommendation(critical)
        XCTAssertEqual(new.appliedCategory, old.appliedCategory)
        XCTAssertEqual(new.categoryGridRecommendation, old.categoryGridRecommendation)
        XCTAssertTrue(RecordInputAssistanceComputation.prefillResultsEqual(new.result, old.result))
    }

    private var semanticFixCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private var semanticFixReferenceDate: Date {
        let now = Date()
        for daysAgo in 1...7 {
            guard let day = semanticFixCalendar.date(
                byAdding: .day,
                value: -daysAgo,
                to: now
            ),
            RecordCalendarContext.isWorkday(day, calendar: semanticFixCalendar),
            let referenceDate = semanticFixCalendar.date(
                bySettingHour: 18,
                minute: 43,
                second: 0,
                of: day
            ) else {
                continue
            }
            return referenceDate
        }
        return now.addingTimeInterval(-24 * 60 * 60)
    }

    private func sixYuanEveningCommuteHistory() -> [HomeItem] {
        (0..<8).map { index in
            HomeItem(
                title: "地铁",
                amount: 6,
                category: .transport,
                createdAt: semanticFixCalendar.date(
                    byAdding: .minute,
                    value: -(index + 1),
                    to: semanticFixReferenceDate
                )!,
                userEditedTitle: true
            )
        }
    }

    private func semanticFixPrefill(
        note: String,
        items: [HomeItem],
        categoryLocked: Bool = false,
        merchantBrandID: String? = nil
    ) -> RecordPrefillResult? {
        RecordPrefillService().prefill(
            input: RecordPrefillInput(
                amount: 6,
                referenceDate: semanticFixReferenceDate,
                items: items,
                noteDraft: note,
                categoryLocked: categoryLocked,
                merchantBrandId: merchantBrandID
            )
        )
    }

    func testOrientalLeavesTeaWinsOverSixYuanEveningCommuteHabit() {
        let history = sixYuanEveningCommuteHistory()
        let historyKey = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: 86,
            referenceDate: semanticFixReferenceDate,
            referenceDateEditedByUser: true,
            calendar: semanticFixCalendar
        )
        let snapshotHistory = RecordInputAssistanceComputation.historySnapshot(
            RecordInputHistoryPreparationInput(
                key: historyKey,
                items: history,
                referenceDate: semanticFixReferenceDate,
                now: semanticFixReferenceDate
            )
        )
        let context = RecordContextSignal(referenceDate: semanticFixReferenceDate, weather: nil)
        let key = RecordPrefillPreparationKey(
            historyKey: historyKey,
            amount: 6,
            referenceDate: semanticFixReferenceDate,
            noteDraft: "东方树叶 青柑普洱",
            selectedCategory: .other,
            context: context
        )

        let snapshot = RecordInputAssistanceComputation.prefillSnapshot(
            RecordPrefillPreparationInput(
                key: key,
                history: snapshotHistory,
                amount: 6,
                referenceDate: semanticFixReferenceDate,
                now: semanticFixReferenceDate,
                noteDraft: "东方树叶 青柑普洱",
                selectedCategory: .other,
                context: context
            )
        )

        XCTAssertEqual(MerchantBrandCatalog.matchBrand(in: "东方树叶")?.id, "oriental_leaves")
        XCTAssertEqual(snapshot.appliedCategory, .dining)
        XCTAssertEqual(snapshot.categoryGridRecommendation, .dining)
        XCTAssertEqual(snapshot.result?.category, .dining)
        XCTAssertNotEqual(snapshot.result?.source, "habit")
        XCTAssertNotEqual(snapshot.result?.source, "scene_habit")
        XCTAssertNotEqual(snapshot.result?.source, "frequent")
    }

    func testTeaProductAndBoundaryTermsKeepTheirExplicitCategories() {
        XCTAssertEqual(RecordSemanticLexicon.semanticCategory(of: "青柑普洱"), .dining)
        XCTAssertEqual(RecordSemanticLexicon.semanticCategory(of: "茶具"), .shopping)
        XCTAssertEqual(RecordSemanticLexicon.semanticCategory(of: "茶叶蛋"), .dining)
        XCTAssertEqual(
            semanticFixPrefill(
                note: "东方树叶",
                items: sixYuanEveningCommuteHistory(),
                merchantBrandID: "oriental_leaves"
            )?.category,
            .dining
        )
        XCTAssertEqual(
            semanticFixPrefill(note: "地铁", items: sixYuanEveningCommuteHistory())?.category,
            .transport
        )
    }

    func testUnknownConcreteTitleRejectsAmountHabitUntilUserCorrectsThatEntity() {
        let history = sixYuanEveningCommuteHistory()
        XCTAssertNil(semanticFixPrefill(note: "星河蓝瓶一号", items: history))

        let corrected = HomeItem(
            title: "星河蓝瓶1号款",
            amount: 6,
            category: .dining,
            createdAt: semanticFixReferenceDate.addingTimeInterval(-30),
            userEditedTitle: true,
            userEditedCategory: true
        )
        let learned = semanticFixPrefill(
            note: "星河蓝瓶1号",
            items: history + [corrected]
        )

        XCTAssertEqual(learned?.category, .dining)
        XCTAssertEqual(learned?.source, "entity_history")
    }

    func testEmptyNoteKeepsReliableHabitAndUserLockPreventsPrefill() {
        let history = sixYuanEveningCommuteHistory()
        XCTAssertEqual(semanticFixPrefill(note: "", items: history)?.category, .transport)
        XCTAssertNil(
            semanticFixPrefill(
                note: "东方树叶",
                items: history,
                categoryLocked: true,
                merchantBrandID: "oriental_leaves"
            )
        )
    }

    func testHistoryKeyChangesOnlyForLedgerOrMeaningfulDateContext() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let base = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 10,
            minute: 15
        ))!

        let first = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: 7,
            referenceDate: base,
            referenceDateEditedByUser: false,
            calendar: calendar
        )
        let redrawOnly = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: 7,
            referenceDate: base.addingTimeInterval(30),
            referenceDateEditedByUser: false,
            calendar: calendar
        )
        let nextHabitBucket = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: 7,
            referenceDate: base.addingTimeInterval(3 * 60 * 60),
            referenceDateEditedByUser: false,
            calendar: calendar
        )
        let changedLedger = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: 8,
            referenceDate: base,
            referenceDateEditedByUser: false,
            calendar: calendar
        )
        let editedMinute = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: 7,
            referenceDate: base.addingTimeInterval(60),
            referenceDateEditedByUser: true,
            calendar: calendar
        )

        XCTAssertEqual(first, redrawOnly)
        XCTAssertNotEqual(first, nextHabitBucket)
        XCTAssertNotEqual(first, changedLedger)
        XCTAssertNotEqual(
            RecordInputAssistanceComputation.historyKey(
                ledgerRevision: 7,
                referenceDate: base,
                referenceDateEditedByUser: true,
                calendar: calendar
            ),
            editedMinute
        )
    }

    func testHistorySnapshotFeedsWarmupAndPrefillWithoutRescanningViewBody() {
        let calendar = Calendar.current
        let now = Date()
        let referenceDate = calendar.date(
            bySettingHour: 10,
            minute: 30,
            second: 0,
            of: now
        ) ?? now
        let amounts = [12.5, 12.5, 12.5, 21, 32, 43]
        let items = amounts.enumerated().map { index, amount in
            HomeItem(
                title: index < 3 ? "工作日早餐" : "日常记录 \(index)",
                amount: amount,
                category: index < 3 ? .dining : .other,
                createdAt: referenceDate.addingTimeInterval(TimeInterval(-3_600 - index * 60)),
                userEditedTitle: index < 3
            )
        }
        let historyKey = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: 3,
            referenceDate: referenceDate,
            referenceDateEditedByUser: false
        )
        let history = RecordInputAssistanceComputation.historySnapshot(
            RecordInputHistoryPreparationInput(
                key: historyKey,
                items: items,
                referenceDate: referenceDate,
                now: now
            )
        )

        XCTAssertEqual(history.frequentSuggestions.first?.amount, 12.5)
        XCTAssertEqual(history.frequentSuggestions.first?.category, .dining)

        let context = RecordContextSignal(referenceDate: referenceDate, weather: nil)
        let prefillKey = RecordPrefillPreparationKey(
            historyKey: historyKey,
            amount: 12.5,
            referenceDate: referenceDate,
            noteDraft: "",
            selectedCategory: .other,
            context: context
        )
        let snapshot = RecordInputAssistanceComputation.prefillSnapshot(
            RecordPrefillPreparationInput(
                key: prefillKey,
                history: history,
                amount: 12.5,
                referenceDate: referenceDate,
                now: now,
                noteDraft: "",
                selectedCategory: .other,
                context: context
            )
        )

        XCTAssertEqual(snapshot.appliedCategory, .dining)
        XCTAssertEqual(snapshot.categoryGridRecommendation, .dining)
        XCTAssertEqual(snapshot.result?.category, .dining)
    }

    func testManualAmountMatchesShortcutAmountWhenHistoryHasStableMerchantTitle() {
        let calendar = Calendar.current
        let referenceDate = calendar.date(
            bySettingHour: 9,
            minute: 8,
            second: 0,
            of: Date()
        ) ?? Date()
        let repeated = (0..<3).map { index in
            HomeItem(
                title: "瑞幸咖啡",
                amount: 9.9,
                category: .dining,
                createdAt: referenceDate.addingTimeInterval(TimeInterval(-(index + 1) * 86_400)),
                userEditedTitle: true
            )
        }
        var supporting: [HomeItem] = repeated
        for index in 0..<3 {
            supporting.append(
                HomeItem(
                    title: "日常记录 \(index)",
                    amount: Double(20 + index),
                    category: .other,
                    createdAt: referenceDate.addingTimeInterval(-Double(index + 1) * 7_200)
                )
            )
        }
        let historyKey = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: 7,
            referenceDate: referenceDate,
            referenceDateEditedByUser: false
        )
        let history = RecordInputAssistanceComputation.historySnapshot(
            RecordInputHistoryPreparationInput(
                key: historyKey,
                items: supporting,
                referenceDate: referenceDate,
                now: referenceDate
            )
        )
        let key = RecordPrefillPreparationKey(
            historyKey: historyKey,
            amount: 9.9,
            referenceDate: referenceDate,
            noteDraft: "",
            selectedCategory: .other,
            context: RecordContextSignal(referenceDate: referenceDate, weather: nil)
        )
        let snapshot = RecordInputAssistanceComputation.prefillSnapshot(
            RecordPrefillPreparationInput(
                key: key,
                history: history,
                amount: 9.9,
                referenceDate: referenceDate,
                now: referenceDate,
                noteDraft: "",
                selectedCategory: .other,
                context: key.context
            )
        )

        XCTAssertEqual(history.frequentSuggestions.first?.amount, 9.9)
        XCTAssertEqual(snapshot.result?.title, "瑞幸咖啡")
        XCTAssertTrue(["frequent", "habit", "scene_habit"].contains(snapshot.result?.source ?? ""))
        XCTAssertEqual(snapshot.appliedCategory, HomeItem.Category.dining)
    }

    func testPreviewLifeMarkSnapshotIsDeterministicForTheSameDraftAndLedgerRevision() {
        let date = Date(timeIntervalSince1970: 1_784_240_000)
        let draft = HomeItem(
            title: "牛肉面",
            amount: 18,
            category: .dining,
            createdAt: date,
            userEditedTitle: true
        )
        let key = RecordPreviewLifeMarkKey(
            ledgerRevision: 4,
            title: draft.title,
            amount: draft.amount,
            category: draft.category,
            createdAt: draft.createdAt,
            emotionTag: draft.emotionTag,
            merchantBrandID: nil,
            scenePackID: nil,
            isMember: true
        )
        let input = RecordPreviewLifeMarkPreparationInput(
            key: key,
            draft: draft,
            allItems: [draft],
            isMember: true
        )

        let first = RecordInputAssistanceComputation.previewLifeMarkText(input)
        let second = RecordInputAssistanceComputation.previewLifeMarkText(input)
        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
    }
}

final class RecordRecommendationConsistencyTests: XCTestCase {
    // Keep fixtures recent for RecordPrefillService's 180-day window and well
    // inside one hour bucket; no dependence on weekday or a fixed release date.
    private var referenceDate: Date {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        return calendar.date(bySettingHour: 12, minute: 30, second: 0, of: yesterday)!
    }

    private func historyItem(
        title: String,
        amount: Double,
        category: HomeItem.Category,
        index: Int,
        at date: Date,
        userEditedTitle: Bool = true,
        userEditedCategory: Bool = false
    ) -> HomeItem {
        HomeItem(
            title: title,
            amount: amount,
            category: category,
            createdAt: date.addingTimeInterval(TimeInterval(-(index + 1) * 60)),
            emotionTag: "",
            userEditedTitle: userEditedTitle,
            userEditedCategory: userEditedCategory
        )
    }

    private func snapshot(
        items: [HomeItem],
        amount: Double,
        note: String = "",
        selectedCategory: HomeItem.Category = .other,
        at date: Date
    ) -> RecordPrefillSnapshot {
        let historyKey = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: 153,
            referenceDate: date,
            referenceDateEditedByUser: true
        )
        let history = RecordInputAssistanceComputation.historySnapshot(
            RecordInputHistoryPreparationInput(
                key: historyKey,
                items: items,
                referenceDate: date,
                now: date
            )
        )
        let key = RecordPrefillPreparationKey(
            historyKey: historyKey,
            amount: amount,
            referenceDate: date,
            noteDraft: note,
            selectedCategory: selectedCategory,
            context: nil
        )
        return RecordInputAssistanceComputation.prefillSnapshot(
            RecordPrefillPreparationInput(
                key: key,
                history: history,
                amount: amount,
                referenceDate: date,
                now: date,
                noteDraft: note,
                selectedCategory: selectedCategory,
                context: nil
            )
        )
    }

    private func conflictingHistory(
        at date: Date,
        shoppingTitle: String = "衣服"
    ) -> [HomeItem] {
        let shopping = (0..<2).map { index in
            historyItem(title: shoppingTitle, amount: 100, category: .shopping, index: index, at: date)
        }
        let dining = (2..<10).map { index in
            historyItem(title: "牛肉面", amount: 95, category: .dining, index: index, at: date)
        }
        return shopping + dining
    }

    func testAdoptedHabitThresholdDoesNotInventATitleOrDescribeAnotherCategory() {
        let date = referenceDate
        for source in ["habit", "scene_habit"] {
            for confidence in [0.54, 0.55, 0.65] {
                let candidate = RecordPrefillResult(
                    category: .dining,
                    title: nil,
                    emotionTag: nil,
                    confidence: confidence,
                    source: source
                )
                let adopted = RecordInputAssistanceComputation.adoptedPrefillResult(
                    habitResult: candidate,
                    frequentSuggestion: nil,
                    frequentCanOverride: false,
                    frequentTitle: nil,
                    amount: 12,
                    referenceDate: date
                )
                if confidence < 0.55 {
                    XCTAssertNil(adopted, source)
                } else {
                    XCTAssertEqual(adopted?.category, .dining, source)
                    XCTAssertNil(adopted?.title, "Category confidence must not manufacture a title")
                }
                XCTAssertEqual(
                    RecordInputAssistanceComputation.canDescribeAdoptedRecommendation(candidate, selectedCategory: .dining),
                    confidence >= 0.55,
                    source
                )
                XCTAssertFalse(
                    RecordInputAssistanceComputation.canDescribeAdoptedRecommendation(candidate, selectedCategory: .other),
                    source
                )
            }
        }
    }

    func testSixRecordSparseHabitDoesNotPublishItsUnadoptedDiningCandidate() throws {
        let date = referenceDate
        let amounts = [12.0, 31, 42, 53, 64, 75]
        let items = amounts.enumerated().map { index, amount in
            historyItem(
                title: index == 0 ? "牛肉面" : "星河随记",
                amount: amount,
                category: index == 0 ? .dining : .other,
                index: index,
                at: date
            )
        }
        let candidate = try XCTUnwrap(RecordPrefillService().prefill(
            input: RecordPrefillInput(
                amount: 12,
                referenceDate: date,
                items: items,
                noteDraft: "",
                categoryLocked: false,
                merchantBrandId: nil
            )
        ))
        XCTAssertEqual(candidate.source, "habit")
        XCTAssertEqual(candidate.category, .dining)
        XCTAssertEqual(candidate.confidence, 0.54, accuracy: 0.000_001)
        XCTAssertNil(candidate.title)

        let result = snapshot(items: items, amount: 12, at: date)
        XCTAssertNil(result.result)
        XCTAssertNil(result.appliedCategory)
        XCTAssertNil(result.categoryGridRecommendation)
        XCTAssertEqual(result.appliedCategory ?? result.key.selectedCategory, .other)
        XCTAssertFalse(RecordInputAssistanceComputation.canDescribeAdoptedRecommendation(candidate, selectedCategory: .other))
    }

    func testColdStartEmptyNoteDoesNotInventARecommendationOrTitle() {
        let result = snapshot(items: [], amount: 50, at: referenceDate)
        XCTAssertNil(result.result)
        XCTAssertNil(result.appliedCategory)
        XCTAssertNil(result.categoryGridRecommendation)
        XCTAssertEqual(result.key.selectedCategory, .other)
    }

    func testGenericDecisionKeepsItsExistingAdoptionPolicy() throws {
        let candidate = RecordPrefillResult(category: .other, title: nil, emotionTag: nil, confidence: 0.4, source: "generic")
        let adopted = try XCTUnwrap(RecordInputAssistanceComputation.adoptedPrefillResult(
            habitResult: candidate,
            frequentSuggestion: nil,
            frequentCanOverride: false,
            frequentTitle: nil,
            amount: 50,
            referenceDate: referenceDate
        ))
        XCTAssertEqual(adopted.category, .other)
        XCTAssertEqual(adopted.source, "generic")
        XCTAssertNil(adopted.title)
        XCTAssertTrue(RecordInputAssistanceComputation.canDescribeAdoptedRecommendation(adopted, selectedCategory: .other))
        XCTAssertFalse(RecordInputAssistanceComputation.canDescribeAdoptedRecommendation(adopted, selectedCategory: .dining))
    }

    func testServiceKeepsTitleConfidenceSeparateFromCategoryConfidence() throws {
        let date = referenceDate
        func candidate(diningCount: Int) throws -> RecordPrefillResult {
            let dining = (0..<diningCount).map { index in
                historyItem(title: "星河一号", amount: 12, category: .dining, index: index, at: date)
            }
            let shopping = (diningCount..<(diningCount + 3)).map { index in
                historyItem(title: "蓝瓶二号", amount: 12, category: .shopping, index: index, at: date)
            }
            return try XCTUnwrap(RecordPrefillService().prefill(
                input: RecordPrefillInput(
                    amount: 12,
                    referenceDate: date,
                    items: dining + shopping,
                    noteDraft: "",
                    categoryLocked: false,
                    merchantBrandId: nil
                )
            ))
        }

        let categoryOnly = try candidate(diningCount: 4)
        XCTAssertEqual(categoryOnly.source, "habit")
        XCTAssertGreaterThanOrEqual(categoryOnly.confidence, 0.55)
        XCTAssertLessThan(categoryOnly.confidence, 0.65)
        XCTAssertNil(categoryOnly.title)

        let titleCandidate = try candidate(diningCount: 6)
        XCTAssertEqual(titleCandidate.source, "habit")
        XCTAssertGreaterThanOrEqual(titleCandidate.confidence, 0.65)
        XCTAssertEqual(titleCandidate.title, "星河一号")
    }

    func testExactAmountShoppingWinsOverNearbyDiningForEverySnapshotOutput() throws {
        let date = referenceDate
        let items = conflictingHistory(at: date)
        let habit = try XCTUnwrap(RecordPrefillService().prefill(
            input: RecordPrefillInput(
                amount: 100,
                referenceDate: date,
                items: items,
                noteDraft: "",
                categoryLocked: false,
                merchantBrandId: nil
            )
        ))
        XCTAssertEqual(habit.category, .dining, "Fixture must actually have conflicting habit evidence")
        XCTAssertGreaterThanOrEqual(habit.confidence, 0.55)

        let result = snapshot(items: items, amount: 100, at: date)
        let adopted = try XCTUnwrap(result.result)
        XCTAssertEqual(result.appliedCategory, .shopping)
        XCTAssertEqual(result.categoryGridRecommendation, .shopping)
        XCTAssertEqual(adopted.category, .shopping)
        XCTAssertEqual(adopted.source, "frequent")
        XCTAssertEqual(adopted.title, "衣服")
        XCTAssertTrue(RecordInputAssistanceComputation.canDescribeAdoptedRecommendation(adopted, selectedCategory: .shopping))
        XCTAssertFalse(RecordInputAssistanceComputation.canDescribeAdoptedRecommendation(habit, selectedCategory: .shopping))
    }

    func testWinningAmountWithoutReliableTitleDoesNotBorrowDefeatedDiningTitle() {
        let date = referenceDate
        let result = snapshot(items: conflictingHistory(at: date, shoppingTitle: "购物记录"), amount: 100, at: date)
        XCTAssertEqual(result.appliedCategory, .shopping)
        XCTAssertEqual(result.categoryGridRecommendation, .shopping)
        XCTAssertEqual(result.result?.category, .shopping)
        XCTAssertEqual(result.result?.source, "frequent")
        XCTAssertNil(result.result?.title)
        XCTAssertNil(result.result?.emotionTag)
    }

    func testReliableFourYuanSeventyFiveTransitKeepsCategoryAndTitle() {
        let date = referenceDate
        let items = (0..<6).map { index in
            historyItem(title: "地铁/公交", amount: 4.75, category: .transport, index: index, at: date)
        }
        let result = snapshot(items: items, amount: 4.75, at: date)
        XCTAssertEqual(result.appliedCategory, .transport)
        XCTAssertEqual(result.categoryGridRecommendation, .transport)
        XCTAssertEqual(result.result?.category, .transport)
        XCTAssertEqual(result.result?.title, "地铁/公交")
    }

    func testConflictingProductMeaningIsNotPublishedAsACompatibleMerchantTitle() {
        let date = referenceDate
        // A historic dining label and a dining-brand alias cannot make a
        // paper-tissue title safe: the save resolver recognizes daily supplies.
        let result = RecordInputAssistanceComputation.adoptedPrefillResult(
            habitResult: nil,
            frequentSuggestion: RecordFrequentAmountSuggestion(
                amount: 12,
                category: .dining,
                count: 3,
                confidence: 1,
                latest: date
            ),
            frequentCanOverride: true,
            frequentTitle: "罗森纸巾",
            amount: 12,
            referenceDate: date
        )
        XCTAssertEqual(RecordSemanticLexicon.semanticCategory(of: "罗森纸巾"), .daily)
        XCTAssertEqual(result?.category, .dining)
        XCTAssertNil(result?.title)
        XCTAssertNil(result?.emotionTag)
    }

    func testConvenienceProductKeepsItsExplicitMeaningAfterPrefillAlreadySelectedIt() {
        let date = referenceDate
        let fallbackCategories: [HomeItem.Category] = [.other, .daily]
        for fallback in fallbackCategories {
            for source in ["preview", "manual"] {
                let resolution = RecordDraftResolutionService.resolve(
                    RecordDraftResolutionInput(
                        rawTitle: "罗森纸巾",
                        fallbackCategory: fallback,
                        amount: 12,
                        date: date,
                        merchantBrandId: "lawson",
                        categoryLockedByUser: false,
                        userEditedTitle: true,
                        source: source
                    )
                )
                XCTAssertEqual(resolution.category, .daily)
                XCTAssertEqual(resolution.title, "罗森纸巾")
                XCTAssertNil(resolution.merchantBrandId)
            }
        }
    }

    func testExplicitNoteBrandAndLearnedEntityKeepPriorityOverAmountHistory() {
        let date = referenceDate
        let items = conflictingHistory(at: date)
        let cases: [(note: String, category: HomeItem.Category, source: String)] = [
            ("牛肉面", .dining, "semantic"),
            ("瑞幸咖啡", .dining, "brand"),
            ("罗森纸巾", .daily, "semantic"),
        ]
        for testCase in cases {
            let result = snapshot(items: items, amount: 100, note: testCase.note, at: date)
            XCTAssertEqual(result.appliedCategory, testCase.category, testCase.note)
            XCTAssertEqual(result.categoryGridRecommendation, testCase.category, testCase.note)
            XCTAssertEqual(result.result?.category, testCase.category, testCase.note)
            XCTAssertEqual(result.result?.source, testCase.source, testCase.note)
        }

        let corrected = historyItem(
            title: "星河蓝瓶一号",
            amount: 7,
            category: .health,
            index: 11,
            at: date,
            userEditedCategory: true
        )
        let learned = snapshot(items: items + [corrected], amount: 100, note: corrected.title, at: date)
        XCTAssertEqual(learned.appliedCategory, .health)
        XCTAssertEqual(learned.categoryGridRecommendation, .health)
        XCTAssertEqual(learned.result?.category, .health)
        XCTAssertEqual(learned.result?.source, "entity_history")
    }

    func testFrequentOverrideRequiresPermissionAndPreservesCompatibleHabitTitle() {
        let date = referenceDate
        let suggestion = RecordFrequentAmountSuggestion(amount: 100, category: .shopping, count: 2, confidence: 1, latest: date)
        let dining = RecordPrefillResult(category: .dining, title: "牛肉面", emotionTag: nil, confidence: 0.9, source: "habit")
        let rejected = RecordInputAssistanceComputation.adoptedPrefillResult(
            habitResult: dining,
            frequentSuggestion: suggestion,
            frequentCanOverride: false,
            frequentTitle: "衣服",
            amount: 100,
            referenceDate: date
        )
        XCTAssertEqual(rejected?.category, .dining)
        XCTAssertEqual(rejected?.title, "牛肉面")

        let shopping = RecordPrefillResult(category: .shopping, title: "衣服", emotionTag: nil, confidence: 0.9, source: "habit")
        let adopted = RecordInputAssistanceComputation.adoptedPrefillResult(
            habitResult: shopping,
            frequentSuggestion: suggestion,
            frequentCanOverride: true,
            frequentTitle: nil,
            amount: 100,
            referenceDate: date
        )
        XCTAssertEqual(adopted?.category, .shopping)
        XCTAssertEqual(adopted?.title, "衣服")
        XCTAssertEqual(adopted?.source, "frequent")
    }

    func testCurrentDraftGuardRejectsEveryChangedInputAndExplicitLock() {
        let date = referenceDate
        let historyKey = RecordInputHistoryKey(ledgerRevision: 153, referenceContext: "current-context")
        let key = RecordPrefillPreparationKey(
            historyKey: historyKey,
            amount: 50,
            referenceDate: date,
            noteDraft: "当前备注",
            selectedCategory: .other,
            context: nil
        )
        func matches(
            history: RecordInputHistoryKey? = nil,
            amount: Double? = 50,
            changedDate: Date? = nil,
            note: String = "当前备注",
            category: HomeItem.Category = .other,
            locked: Bool = false,
            generated: RecordGeneratedNoteContext? = nil
        ) -> Bool {
            RecordInputAssistanceComputation.matchesCurrentDraft(
                key,
                historyKey: history ?? historyKey,
                amount: amount,
                referenceDate: changedDate ?? date,
                noteDraft: note,
                selectedCategory: category,
                categoryLockedByUser: locked,
                generatedNoteContext: generated
            )
        }

        XCTAssertTrue(matches())
        XCTAssertFalse(matches(note: "已经输入的新备注"), "Old completion must fail even before the debounce schedules a new key")
        XCTAssertFalse(matches(note: ""))
        XCTAssertFalse(matches(amount: 51))
        XCTAssertFalse(matches(amount: nil))
        XCTAssertFalse(matches(changedDate: date.addingTimeInterval(60)))
        XCTAssertFalse(matches(category: .shopping))
        XCTAssertFalse(matches(history: RecordInputHistoryKey(ledgerRevision: 154, referenceContext: historyKey.referenceContext)))
        XCTAssertFalse(matches(history: RecordInputHistoryKey(ledgerRevision: 153, referenceContext: "another-context")))
        XCTAssertFalse(matches(locked: true), "Category and scene-pack locks share this boundary")
        XCTAssertFalse(matches(generated: RecordGeneratedNoteContext(title: key.noteDraft, category: .other)))
        XCTAssertTrue(matches(generated: RecordGeneratedNoteContext(title: "已被改掉的生成句", category: .other)))
    }

    func testGeneratedNoteContextMatchesOnlyItsNonemptyTitleAndCategory() {
        let context = RecordGeneratedNoteContext(title: " 买到常用的小东西 ", category: .shopping)
        XCTAssertTrue(context.matches(title: "买到常用的小东西", category: .shopping))
        XCTAssertFalse(context.matches(title: "牛肉面", category: .shopping))
        XCTAssertFalse(context.matches(title: "", category: .shopping))
        XCTAssertFalse(context.matches(title: "买到常用的小东西", category: .other))
        XCTAssertFalse(RecordGeneratedNoteContext(title: "  ", category: .other).matches(title: "", category: .other))
    }

    func testGeneratedShoppingRemainsProtectedAcrossDateAndHistoryRecalculation() {
        let title = "买到常用的小东西"
        let context = RecordGeneratedNoteContext(title: title, category: .shopping)
        let date = referenceDate
        for offset in [TimeInterval(0), TimeInterval(6 * 3_600)] {
            let currentDate = date.addingTimeInterval(offset)
            let historyKey = RecordInputAssistanceComputation.historyKey(
                ledgerRevision: offset == 0 ? 153 : 154,
                referenceDate: currentDate,
                referenceDateEditedByUser: true
            )
            let key = RecordPrefillPreparationKey(
                historyKey: historyKey,
                amount: 50,
                referenceDate: currentDate,
                noteDraft: title,
                selectedCategory: .shopping,
                context: nil
            )
            XCTAssertFalse(RecordInputAssistanceComputation.matchesCurrentDraft(
                key,
                historyKey: historyKey,
                amount: 50,
                referenceDate: currentDate,
                noteDraft: title,
                selectedCategory: .shopping,
                categoryLockedByUser: false,
                generatedNoteContext: context
            ))
            let resolution = RecordDraftResolutionService.resolve(
                RecordDraftResolutionInput(
                    rawTitle: title,
                    fallbackCategory: .shopping,
                    amount: 50,
                    date: currentDate,
                    merchantBrandId: nil,
                    categoryLockedByUser: false,
                    userEditedTitle: false,
                    source: "manual",
                    generatedNoteContext: context
                )
            )
            XCTAssertEqual(resolution.category, HomeItem.Category.shopping)
            XCTAssertEqual(resolution.title, title)
            XCTAssertTrue(resolution.trace.contains("category:generatedDraft"))
            XCTAssertFalse(resolution.trace.contains("category:userLocked"))
        }
    }

    func testEditedGeneratedNoteReturnsToExplicitSemanticClassification() {
        let generated = RecordGeneratedNoteContext(title: "买到常用的小东西", category: .shopping)
        let resolution = RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: "牛肉面",
                fallbackCategory: .shopping,
                amount: 50,
                date: referenceDate,
                merchantBrandId: nil,
                categoryLockedByUser: false,
                userEditedTitle: true,
                source: "manual",
                generatedNoteContext: generated
            )
        )
        XCTAssertEqual(resolution.category, .dining)
        XCTAssertEqual(resolution.title, "牛肉面")
        XCTAssertTrue(resolution.trace.contains("category:semantic"))
        XCTAssertFalse(resolution.trace.contains("category:generatedDraft"))
    }

    func testGeneratedSocialCopyUsesSameCategoryInPreviewAndSaveWithoutAUserLock() {
        let title = "一起吃顿饭"
        let date = referenceDate
        let generated = RecordGeneratedNoteContext(title: title, category: .social)
        var results: [RecordDraftResolution] = []
        for source in ["preview", "manual"] {
            let resolution = RecordDraftResolutionService.resolve(
                RecordDraftResolutionInput(
                    rawTitle: title,
                    fallbackCategory: .social,
                    amount: 50,
                    date: date,
                    merchantBrandId: nil,
                    categoryLockedByUser: false,
                    userEditedTitle: false,
                    source: source,
                    generatedNoteContext: generated
                )
            )
            XCTAssertEqual(resolution.category, .social)
            XCTAssertEqual(resolution.title, title)
            XCTAssertTrue(resolution.trace.contains("category:generatedDraft"))
            XCTAssertFalse(resolution.trace.contains("category:userLocked"))
            results.append(resolution)
        }
        XCTAssertEqual(results[0].emotionTag, results[1].emotionTag)
        XCTAssertEqual(results[0].merchantBrandId, results[1].merchantBrandId)
    }

    func testSameSocialPhraseWithoutGeneratedOriginKeepsExistingDiningSemantics() {
        let resolution = RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: "一起吃顿饭",
                fallbackCategory: .social,
                amount: 50,
                date: referenceDate,
                merchantBrandId: nil,
                categoryLockedByUser: false,
                userEditedTitle: true,
                source: "manual"
            )
        )
        XCTAssertEqual(resolution.category, .dining)
        XCTAssertEqual(resolution.title, "一起吃顿饭")
        XCTAssertTrue(resolution.trace.contains("category:semantic"))
        XCTAssertFalse(resolution.trace.contains("category:generatedDraft"))
    }

    func testExplicitScenePackLockStillWinsAndRetainsExistingTitleRepair() {
        let title = "酒店住一晚"
        let date = referenceDate
        var input = RecordDraftResolutionInput(
            rawTitle: title,
            fallbackCategory: .transport,
            amount: 100,
            date: date,
            merchantBrandId: nil,
            categoryLockedByUser: true,
            userEditedTitle: false,
            source: "manual",
            scenePackId: "travel"
        )
        let existingPackResolution = RecordDraftResolutionService.resolve(input)
        input.generatedNoteContext = RecordGeneratedNoteContext(title: title, category: .transport)
        let generatedPackResolution = RecordDraftResolutionService.resolve(input)
        XCTAssertEqual(generatedPackResolution.category, .transport)
        XCTAssertTrue(generatedPackResolution.trace.contains("category:userLocked"))
        XCTAssertFalse(generatedPackResolution.trace.contains("category:generatedDraft"))
        XCTAssertEqual(generatedPackResolution.title, existingPackResolution.title)
        XCTAssertEqual(generatedPackResolution.emotionTag, existingPackResolution.emotionTag)
        XCTAssertEqual(generatedPackResolution.merchantBrandId, existingPackResolution.merchantBrandId)
        XCTAssertNotEqual(existingPackResolution.title, title, "This task must not silently change locked-pack title repair")
    }
}

final class HomeDashboardSnapshotTests: XCTestCase {
    func testJourneyLedgerFactsReuseOneCommittedRecordSnapshot() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_784_240_000)
        let week = DateInterval(
            start: now.addingTimeInterval(-3 * 24 * 60 * 60),
            end: now.addingTimeInterval(4 * 24 * 60 * 60)
        )
        let month = DateInterval(
            start: now.addingTimeInterval(-15 * 24 * 60 * 60),
            end: now.addingTimeInterval(16 * 24 * 60 * 60)
        )
        let committed = HomeItem(
            title: "牛肉面",
            amount: 28,
            category: .dining,
            createdAt: now
        )
        let olderCommitted = HomeItem(
            title: "地铁",
            amount: 3,
            category: .transport,
            createdAt: now.addingTimeInterval(-10 * 24 * 60 * 60)
        )
        let draft = HomeItem(
            title: "待整理",
            amount: 20,
            category: .other,
            createdAt: now,
            draftMeta: .init(batchId: "qa", importedAt: now, status: .pending)
        )
        let zero = HomeItem(
            title: "零金额",
            amount: 0,
            category: .other,
            createdAt: now
        )

        let facts = HomeJourneyLedgerFacts.build(
            from: [committed, olderCommitted, draft, zero],
            currentWeekInterval: week,
            currentMonthInterval: month,
            calendar: calendar
        )

        XCTAssertEqual(facts.totalCommittedRecordCount, 2)
        XCTAssertEqual(facts.allRecordDayCount, 2)
        XCTAssertEqual(facts.currentWeekCommittedRecordCount, 1)
        XCTAssertEqual(facts.currentWeekActiveDayCount, 1)
        XCTAssertEqual(facts.currentMonthCommittedRecordCount, 2)
        XCTAssertEqual(facts.currentMonthActiveDayCount, 2)
    }

    func testVisibleLifeMarksPrepareOnceForOnlyVisibleRecordIDs() {
        let date = Date(timeIntervalSince1970: 1_784_240_000)
        let visible = HomeItem(
            title: "牛肉面",
            amount: 28,
            category: .dining,
            createdAt: date
        )
        let hidden = HomeItem(
            title: "上班地铁",
            amount: 3,
            category: .transport,
            createdAt: date.addingTimeInterval(-60)
        )
        let key = HomeLifeMarkSnapshotKey(
            ledgerRevision: 2,
            dayKey: "2026-07-17",
            isMember: true
        )
        let first = HomeDashboardSnapshotComputation.lifeMarkSnapshot(
            HomeLifeMarkPreparationInput(
                key: key,
                visibleItems: [visible],
                weekItems: [visible, hidden],
                allItems: [visible, hidden],
                isMember: true,
                frequentSuggestionLine: nil
            )
        )
        let second = HomeDashboardSnapshotComputation.lifeMarkSnapshot(
            HomeLifeMarkPreparationInput(
                key: key,
                visibleItems: [visible],
                weekItems: [visible, hidden],
                allItems: [visible, hidden],
                isMember: true,
                frequentSuggestionLine: nil
            )
        )

        XCTAssertNotNil(first.textsByItemID[visible.id])
        XCTAssertNil(first.textsByItemID[hidden.id])
        XCTAssertEqual(first.textsByItemID, second.textsByItemID)
        XCTAssertNotNil(first.todayPrimaryLine)
        XCTAssertEqual(first.todayPrimaryLine, second.todayPrimaryLine)
        XCTAssertEqual(first.weekLifeThemeText, second.weekLifeThemeText)
        XCTAssertEqual(first.quickRecordNudgeText, second.quickRecordNudgeText)
        XCTAssertEqual(first.weekTopCategoryText, second.weekTopCategoryText)
    }

    func testPreparedLifeMarkContextMatchesLegacyCombinedAndPerItemResults() {
        let now = Date(timeIntervalSince1970: 1_784_240_000)
        let items = [
            HomeItem(title: "咖啡", amount: 18, category: .dining, createdAt: now),
            HomeItem(
                title: "咖啡",
                amount: 16,
                category: .dining,
                createdAt: now.addingTimeInterval(-24 * 60 * 60)
            ),
            HomeItem(
                title: "上班地铁",
                amount: 4,
                category: .transport,
                createdAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
                scenePackId: "commute"
            ),
            HomeItem(
                title: "普通午餐",
                amount: 28,
                category: .dining,
                createdAt: now.addingTimeInterval(-3 * 24 * 60 * 60)
            )
        ]
        let context = LifeMarkService.prepareAggregationContext(
            allItems: items,
            periodItems: items
        )
        let periods = [items, [items[0]], [items[2]]]

        for period in periods {
            XCTAssertEqual(
                LifeMarkService.aggregates(
                    for: period,
                    preparedContext: context,
                    isMember: true,
                    limit: 8
                ),
                LifeMarkService.aggregates(
                    for: period,
                    allItems: items,
                    isMember: true,
                    limit: 8
                )
            )
        }
    }

    func testSceneRewardColdStartPreparedAggregationPreservesLegacyDecision() {
        let suiteName = "LifeMarkSceneRewardServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let service = LifeMarkSceneRewardService(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_784_240_000)
        let commute = HomeItem(
            title: "上班地铁",
            amount: 4,
            category: .transport,
            createdAt: now,
            scenePackId: "commute"
        )
        let earlierCoffee = HomeItem(
            title: "拿铁咖啡",
            amount: 18,
            category: .dining,
            createdAt: now.addingTimeInterval(-24 * 60 * 60)
        )
        let ordinary = HomeItem(
            title: "普通午餐",
            amount: 28,
            category: .dining,
            createdAt: now.addingTimeInterval(60)
        )
        let scenarios = [
            (item: commute, allItems: [commute]),
            (item: commute, allItems: [commute, earlierCoffee]),
            (item: ordinary, allItems: [ordinary])
        ]

        for scenario in scenarios {
            let previousItems = scenario.allItems.filter { $0.id != scenario.item.id }
            let expected = !LifeMarkService.aggregates(
                for: [scenario.item],
                allItems: scenario.allItems,
                isMember: true,
                limit: 1
            ).isEmpty && LifeMarkService.aggregates(
                for: previousItems,
                allItems: previousItems,
                isMember: true,
                limit: 1
            ).isEmpty

            XCTAssertEqual(
                service.shouldShowColdStartGuide(
                    after: scenario.item,
                    allItems: scenario.allItems,
                    isMember: false
                ),
                expected
            )
        }
    }

    func testItemDerivedCacheBuildsOneAtomicSnapshotAtReleaseScale() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 21,
            hour: 18,
            minute: 30
        ))!
        let items = Array((0..<5_000).map { index in
            HomeItem(
                title: "记录 \(index)",
                amount: Double((index % 200) + 1),
                category: HomeItem.Category.allCases[index % HomeItem.Category.allCases.count],
                createdAt: now.addingTimeInterval(TimeInterval(-index * 1_800))
            )
        }.reversed())
        let key = ItemDerivedCachePreparationKey(
            ledgerRevision: 42,
            dayKey: "2026-07-21"
        )

        let snapshot = ItemDerivedCacheComputation.build(
            ItemDerivedCachePreparationInput(
                key: key,
                items: items,
                now: now,
                itemsAreSortedDescending: false
            )
        )

        let expectedToday = items.filter {
            calendar.isDate($0.createdAt, inSameDayAs: now) && $0.amount > 0
        }
        XCTAssertEqual(snapshot.key, key)
        XCTAssertEqual(snapshot.todayPositiveItems.count, expectedToday.count)
        XCTAssertEqual(snapshot.recentThreeTodayItems, Array(snapshot.todayPositiveItems.prefix(3)))
        XCTAssertEqual(snapshot.todayPositiveItems, snapshot.todayPositiveItems.sorted { $0.createdAt > $1.createdAt })
        XCTAssertEqual(
            snapshot.todayPlayback,
            PlaybackService().buildTodayPlayback(from: items, now: now)
        )
        XCTAssertEqual(snapshot.homeJourneyLedgerFacts.totalCommittedRecordCount, items.count)
    }

    func testItemDerivedCachePublicationRejectsOldRevisionAndRequest() {
        let old = ItemDerivedCachePreparationKey(ledgerRevision: 8, dayKey: "2026-07-21")
        let latest = ItemDerivedCachePreparationKey(ledgerRevision: 9, dayKey: "2026-07-21")

        XCTAssertFalse(
            ItemDerivedCachePublicationPolicy.accepts(
                snapshotKey: old,
                pendingKey: latest,
                currentKey: latest,
                requestMatches: true
            )
        )
        XCTAssertFalse(
            ItemDerivedCachePublicationPolicy.accepts(
                snapshotKey: latest,
                pendingKey: latest,
                currentKey: latest,
                requestMatches: false
            )
        )
        XCTAssertTrue(
            ItemDerivedCachePublicationPolicy.accepts(
                snapshotKey: latest,
                pendingKey: latest,
                currentKey: latest,
                requestMatches: true
            )
        )
        XCTAssertGreaterThanOrEqual(
            ItemDerivedCachePublicationPolicy.coalescingDelayNanoseconds,
            100_000_000
        )
        XCTAssertLessThanOrEqual(
            ItemDerivedCachePublicationPolicy.coalescingDelayNanoseconds,
            150_000_000
        )
    }

    func testImmediateEditedItemProjectionKeepsListsCurrentUntilBackgroundPublication() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 8,
            day: 26,
            hour: 9
        ))!
        let first = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000501")!,
            title: "晨间咖啡和小食",
            amount: 10,
            category: .dining,
            createdAt: calendar.date(byAdding: .minute, value: -8, to: now)!
        )
        let second = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000502")!,
            title: "地铁通勤",
            amount: 4.5,
            category: .transport,
            createdAt: calendar.date(byAdding: .minute, value: -7, to: now)!
        )
        let key = ItemDerivedCachePreparationKey(
            ledgerRevision: 12,
            dayKey: "2026-08-26"
        )
        let snapshot = ItemDerivedCacheComputation.build(
            ItemDerivedCachePreparationInput(
                key: key,
                items: [second, first],
                now: now,
                itemsAreSortedDescending: true
            )
        )

        var edited = first
        edited.title = "吃馄饨"
        edited.createdAt = calendar.date(byAdding: .minute, value: 1, to: now)!
        let projected = ItemDerivedCacheImmediateMutationPolicy.replacing(
            edited,
            in: snapshot,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(projected.key, snapshot.key)
        XCTAssertEqual(projected.todayPositiveItems.map(\.title), ["吃馄饨", "地铁通勤"])
        XCTAssertEqual(projected.recentThreeTodayItems, projected.todayPositiveItems)
        XCTAssertEqual(projected.currentWeekItems.first(where: { $0.id == edited.id })?.title, "吃馄饨")
        XCTAssertEqual(projected.currentMonthItems.first(where: { $0.id == edited.id })?.title, "吃馄饨")
        XCTAssertEqual(projected.currentYearItems.first(where: { $0.id == edited.id })?.title, "吃馄饨")
        XCTAssertEqual(projected.ledgerDisplayFingerprint, snapshot.ledgerDisplayFingerprint)
        XCTAssertEqual(projected.todayPlayback, snapshot.todayPlayback)

        edited.createdAt = calendar.date(byAdding: .day, value: -1, to: now)!
        let movedOut = ItemDerivedCacheImmediateMutationPolicy.replacing(
            edited,
            in: projected,
            now: now,
            calendar: calendar
        )
        XCTAssertFalse(movedOut.todayPositiveItems.contains { $0.id == edited.id })
        XCTAssertTrue(movedOut.currentWeekItems.contains { $0.id == edited.id })

        edited.createdAt = now
        edited.amount = 0
        let zeroAmount = ItemDerivedCacheImmediateMutationPolicy.replacing(
            edited,
            in: movedOut,
            now: now,
            calendar: calendar
        )
        XCTAssertFalse(zeroAmount.todayPositiveItems.contains { $0.id == edited.id })
        XCTAssertTrue(zeroAmount.currentWeekItems.contains { $0.id == edited.id })
    }

    func testImmediateLedgerMutationProjectionAddsAndRemovesHomeRows() {
        let now = Date()
        let existing = HomeItem(
            title: "早餐",
            amount: 12,
            category: .dining,
            createdAt: now.addingTimeInterval(-60)
        )
        let added = HomeItem(
            title: "瑞幸咖啡",
            amount: 9.9,
            category: .dining,
            createdAt: now
        )
        let key = ItemDerivedCachePreparationKey(
            ledgerRevision: 4,
            dayKey: "test-day"
        )
        let base = ItemDerivedCacheComputation.build(
            ItemDerivedCachePreparationInput(
                key: key,
                items: [existing],
                now: now,
                itemsAreSortedDescending: true
            )
        )
        let withAdded = ItemDerivedCacheImmediateMutationPolicy.adding(
            added,
            in: base,
            now: now
        )
        XCTAssertEqual(withAdded.todayPositiveItems.map(\.id), [added.id, existing.id])
        XCTAssertEqual(withAdded.recentThreeTodayItems.count, 2)

        let afterDelete = ItemDerivedCacheImmediateMutationPolicy.removing(
            ids: [added.id],
            from: withAdded
        )
        XCTAssertEqual(afterDelete.todayPositiveItems.map(\.id), [existing.id])
        XCTAssertFalse(afterDelete.recentThreeTodayItems.contains { $0.id == added.id })
    }

    func testRapidInteractionMemoryPolicyBoundsDisplayImagesSnapshotsAndCoalescing() {
        XCTAssertLessThanOrEqual(MemoryAttachmentImagePolicy.cacheCountLimit, 40)
        XCTAssertLessThanOrEqual(
            MemoryAttachmentImagePolicy.cacheCostLimitBytes,
            32 * 1024 * 1024
        )
        XCTAssertLessThanOrEqual(MemoryAttachmentImagePolicy.thumbnailMaxPixelSize, 480)
        XCTAssertLessThanOrEqual(MemoryAttachmentImagePolicy.originalDisplayMaxPixelSize, 1_600)
        XCTAssertEqual(MemoryAttachmentImagePolicy.originalPagePreloadRadius, 1)

        let loadedPages = (0..<9).filter {
            MemoryAttachmentImagePolicy.shouldLoadOriginalPage(
                index: $0,
                selectedIndex: 4,
                imageCount: 9
            )
        }
        XCTAssertEqual(loadedPages, [3, 4, 5])
        XCTAssertFalse(MemoryAttachmentImagePolicy.shouldLoadOriginalPage(
            index: 9,
            selectedIndex: 4,
            imageCount: 9
        ))

        XCTAssertLessThanOrEqual(TraceSnapshotMemoryPolicy.chapterCacheLimit, 2)
        XCTAssertLessThanOrEqual(TraceSnapshotMemoryPolicy.clueCacheLimit, 4)
        XCTAssertGreaterThanOrEqual(
            LedgerRapidInteractionPolicy.traceCoalescingDelayNanoseconds,
            60_000_000
        )
        XCTAssertLessThanOrEqual(
            LedgerRapidInteractionPolicy.traceCoalescingDelayNanoseconds,
            120_000_000
        )
        XCTAssertGreaterThanOrEqual(
            LedgerRapidInteractionPolicy.homeSnapshotCoalescingDelayNanoseconds,
            60_000_000
        )
    }

    func testTracePrewarmWaitsUntilVisibleSnapshotHasSettled() {
        XCTAssertGreaterThanOrEqual(
            TraceLifePreparationPolicy.prewarmDelayNanoseconds,
            200_000_000
        )
        XCTAssertEqual(TraceLifePreparationPolicy.prewarmRange(after: .week), .month)
        XCTAssertEqual(TraceLifePreparationPolicy.prewarmRange(after: .month), .week)
    }

    func testLifeMarkRefreshPreservesRowsOnlyForTheSameDayAndMembership() {
        let previous = HomeLifeMarkSnapshotKey(
            ledgerRevision: 2,
            dayKey: "2026-07-21",
            isMember: true
        )
        XCTAssertTrue(
            HomeLifeMarkRefreshPolicy.preservesVisibleLines(
                previousKey: previous,
                nextKey: HomeLifeMarkSnapshotKey(
                    ledgerRevision: 3,
                    dayKey: "2026-07-21",
                    isMember: true
                )
            )
        )
        XCTAssertFalse(
            HomeLifeMarkRefreshPolicy.preservesVisibleLines(
                previousKey: previous,
                nextKey: HomeLifeMarkSnapshotKey(
                    ledgerRevision: 3,
                    dayKey: "2026-07-22",
                    isMember: true
                )
            )
        )
        XCTAssertFalse(
            HomeLifeMarkRefreshPolicy.preservesVisibleLines(
                previousKey: previous,
                nextKey: HomeLifeMarkSnapshotKey(
                    ledgerRevision: 3,
                    dayKey: "2026-07-21",
                    isMember: false
                )
            )
        )
    }

    func testLifeMarkRefreshDropsOnlyEditedOrDeletedRowsBeforeAsyncRebuild() {
        let date = Date(timeIntervalSince1970: 1_784_240_000)
        let chargingID = UUID(uuidString: "E1000000-0000-0000-0000-000000000001")!
        let mealID = UUID(uuidString: "E1000000-0000-0000-0000-000000000002")!
        let previousCharging = HomeItem(
            id: chargingID,
            title: "电车充电",
            amount: 42,
            category: .daily,
            createdAt: date,
            updatedAt: date
        )
        let meal = HomeItem(
            id: mealID,
            title: "牛肉面",
            amount: 28,
            category: .dining,
            createdAt: date.addingTimeInterval(60),
            updatedAt: date.addingTimeInterval(60)
        )
        var correctedCharging = previousCharging
        correctedCharging.category = .transport
        correctedCharging.userEditedCategory = true
        correctedCharging.categoryCorrectionFrom = .daily
        correctedCharging.updatedAt = date.addingTimeInterval(120)
        let previousItems = [previousCharging, meal]
        let previousTexts = [
            chargingID: "生活线索 · 超市买菜和家用",
            mealID: "生活线索 · 日常吃饭",
        ]

        let retained = HomeLifeMarkRefreshPolicy.retainedVisibleLines(
            previousTexts: previousTexts,
            previousSignatures: HomeLifeMarkRefreshPolicy.semanticSignatures(for: previousItems),
            nextItems: [correctedCharging, meal]
        )
        let afterDeletion = HomeLifeMarkRefreshPolicy.retainedVisibleLines(
            previousTexts: previousTexts,
            previousSignatures: HomeLifeMarkRefreshPolicy.semanticSignatures(for: previousItems),
            nextItems: [correctedCharging]
        )

        XCTAssertNil(retained[chargingID])
        XCTAssertEqual(retained[mealID], previousTexts[mealID])
        XCTAssertNil(afterDeletion[chargingID])
        XCTAssertNil(afterDeletion[mealID])

        let key = HomeLifeMarkSnapshotKey(
            ledgerRevision: 3,
            dayKey: "2026-07-21",
            isMember: true
        )
        let rebuilt = HomeDashboardSnapshotComputation.lifeMarkSnapshot(
            HomeLifeMarkPreparationInput(
                key: key,
                visibleItems: [correctedCharging],
                weekItems: [correctedCharging],
                allItems: [correctedCharging],
                isMember: true,
                frequentSuggestionLine: nil
            )
        )
        XCTAssertEqual(rebuilt.textsByItemID[chargingID], "生活线索 · 车主日常")
        XCTAssertFalse(rebuilt.textsByItemID[chargingID]?.contains("买菜") == true)
    }

    func testQuickRecordSnapshotKeyChangesOnlyWithLedgerOrMinuteBucket() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let base = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 8,
            minute: 30
        ))!
        let first = HomeQuickRecordSnapshotKey(
            ledgerRevision: 3,
            minuteKey: HomeDashboardSnapshotComputation.minuteKey(for: base, calendar: calendar)
        )
        let redrawOnly = HomeQuickRecordSnapshotKey(
            ledgerRevision: 3,
            minuteKey: HomeDashboardSnapshotComputation.minuteKey(
                for: base.addingTimeInterval(20),
                calendar: calendar
            )
        )
        let nextMinute = HomeQuickRecordSnapshotKey(
            ledgerRevision: 3,
            minuteKey: HomeDashboardSnapshotComputation.minuteKey(
                for: base.addingTimeInterval(60),
                calendar: calendar
            )
        )

        XCTAssertEqual(first, redrawOnly)
        XCTAssertNotEqual(first, nextMinute)
        XCTAssertNotEqual(first, HomeQuickRecordSnapshotKey(ledgerRevision: 4, minuteKey: first.minuteKey))
    }

    func testForegroundResumeAdvancesTheQuickRecordKeyAcrossAnOvernightBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let beforeBackground = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 19,
            hour: 23,
            minute: 48
        ))!
        let afterForeground = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 20,
            hour: 8,
            minute: 12
        ))!

        let stale = HomeQuickRecordSnapshotKey(
            ledgerRevision: 9,
            minuteKey: HomeDashboardSnapshotComputation.minuteKey(
                for: beforeBackground,
                calendar: calendar
            )
        )
        let refreshed = HomeQuickRecordSnapshotKey(
            ledgerRevision: 9,
            minuteKey: HomeDashboardSnapshotComputation.minuteKey(
                for: afterForeground,
                calendar: calendar
            )
        )

        XCTAssertNotEqual(stale, refreshed)
    }

    func testLifecycleRefreshClearsOnlyAStaleQuickRecordPresentation() {
        let current = HomeQuickRecordSnapshotKey(
            ledgerRevision: 9,
            minuteKey: "2026-07-20-08-12"
        )
        let nextMinute = HomeQuickRecordSnapshotKey(
            ledgerRevision: 9,
            minuteKey: "2026-07-20-08-13"
        )

        XCTAssertFalse(
            HomeQuickRecordRefreshPolicy.shouldClearVisibleSuggestion(
                previousKey: current,
                nextKey: current,
                isLifecycleRefresh: true
            )
        )
        XCTAssertTrue(
            HomeQuickRecordRefreshPolicy.shouldClearVisibleSuggestion(
                previousKey: current,
                nextKey: nextMinute,
                isLifecycleRefresh: true
            )
        )
        XCTAssertFalse(
            HomeQuickRecordRefreshPolicy.shouldClearVisibleSuggestion(
                previousKey: current,
                nextKey: nextMinute,
                isLifecycleRefresh: false
            )
        )
    }

    func testCommuteSuggestionKeepsExistingRulesOnImmutableLedgerInput() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 13,
            hour: 8,
            minute: 30
        ))!
        var items: [HomeItem] = (1...4).map { weekOffset in
            HomeItem(
                title: "上班地铁",
                amount: 3,
                category: .transport,
                createdAt: calendar.date(
                    byAdding: .day,
                    value: -7 * weekOffset,
                    to: now.addingTimeInterval(-15 * 60)
                )!,
                userEditedTitle: true
            )
        }
        for index in 1...4 {
            items.append(
                HomeItem(
                    title: "日常记录 \(index)",
                    amount: Double(10 + index),
                    category: .other,
                    createdAt: now.addingTimeInterval(-Double(index) * 24 * 60 * 60)
                )
            )
        }

        let first = HomeViewModel.highConfidenceQuickRecordSuggestionForSnapshot(
            items: items,
            at: now
        )
        let second = HomeViewModel.highConfidenceQuickRecordSuggestionForSnapshot(
            items: items,
            at: now
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(first?.amount, 3)
        XCTAssertEqual(first?.category, .transport)
        XCTAssertEqual(first?.supportCount, 4)
    }

    func testForegroundRefreshDoesNotRelaxCommuteWindowOrTodayDuplicateRules() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 20,
            hour: 8,
            minute: 30
        ))!
        var history: [HomeItem] = (1...4).map { weekOffset in
            HomeItem(
                title: "上班地铁",
                amount: 3,
                category: .transport,
                createdAt: calendar.date(
                    byAdding: .day,
                    value: -7 * weekOffset,
                    to: now.addingTimeInterval(-15 * 60)
                )!,
                userEditedTitle: true
            )
        }
        for index in 1...4 {
            history.append(
                HomeItem(
                    title: "普通记录 \(index)",
                    amount: Double(20 + index),
                    category: .other,
                    createdAt: now.addingTimeInterval(-Double(index) * 24 * 60 * 60)
                )
            )
        }

        XCTAssertNotNil(
            HomeViewModel.highConfidenceQuickRecordSuggestionForSnapshot(
                items: history,
                at: now
            )
        )

        let beforePersonalWindow = calendar.date(
            bySettingHour: 7,
            minute: 0,
            second: 0,
            of: now
        )!
        XCTAssertNil(
            HomeViewModel.highConfidenceQuickRecordSuggestionForSnapshot(
                items: history,
                at: beforePersonalWindow
            )
        )

        let todayCommute = HomeItem(
            title: "上班地铁",
            amount: 3,
            category: .transport,
            createdAt: calendar.date(
                bySettingHour: 8,
                minute: 5,
                second: 0,
                of: now
            )!,
            scenePackId: "commute"
        )
        XCTAssertNil(
            HomeViewModel.highConfidenceQuickRecordSuggestionForSnapshot(
                items: history + [todayCommute],
                at: now
            )
        )
    }
}

final class LifeMarkFactAuthorityTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(_ day: Int, hour: Int = 20, minute: Int = 43) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    func testGeneratedDisplayCopyDoesNotCreateGroceryOrSocialFacts() {
        let generatedSupply = HomeItem(
            title: "日用记录",
            amount: 72.95,
            category: .daily,
            createdAt: date(20, hour: 12),
            emotionTag: "超市买菜和家用"
        )
        let generatedGathering = HomeItem(
            title: "餐饮记录",
            amount: 29,
            category: .dining,
            createdAt: date(21, hour: 12),
            emotionTag: "朋友小聚聚餐"
        )

        let marks = LifeMarkService.aggregates(
            for: [generatedSupply, generatedGathering],
            allItems: [generatedSupply, generatedGathering],
            isMember: true,
            limit: 12
        )

        XCTAssertFalse(marks.contains { $0.id == "daily_supply" || $0.id == "groceries" })
        XCTAssertFalse(marks.contains { $0.id == "social_care" || $0.id == "weekend_gathering" })
        XCTAssertNotEqual(LifeSceneSemanticService.classify(generatedSupply).kind, .groceries)
        XCTAssertNotEqual(LifeSceneSemanticService.classify(generatedGathering).kind, .social)
    }

    func testTrustedTitleBrandAndScenePackStillCreateFacts() {
        let groceries = HomeItem(
            title: "今天这一单",
            amount: 68,
            category: .daily,
            createdAt: date(20, hour: 18),
            merchantBrandId: "freshippo"
        )
        let social = HomeItem(
            title: "给朋友随礼",
            amount: 200,
            category: .social,
            createdAt: date(21, hour: 18)
        )
        let commute = HomeItem(
            title: "下班路上拍了张照片",
            amount: 5.70,
            category: .transport,
            createdAt: date(22)
        )

        let marks = LifeMarkService.aggregates(
            for: [groceries, social, commute],
            allItems: [groceries, social, commute],
            isMember: true,
            limit: 12
        )

        XCTAssertTrue(marks.contains { $0.id == "groceries" })
        XCTAssertTrue(marks.contains { $0.id == "social_care" })
        XCTAssertTrue(marks.contains { $0.id == "commute" })
        XCTAssertEqual(LifeSceneSemanticService.classify(commute).kind, .commute)
    }

    func testOCRTransitRouteUsesWorkdayHistoryInsteadOfExactAmount() {
        let history = [20, 21].map { day in
            HomeItem(
                title: "天隆寺1号口 > 雨山路",
                amount: day == 20 ? 4.75 : 5.20,
                category: .transport,
                createdAt: date(day),
                merchantBrandId: "metro_transit"
            )
        }

        XCTAssertEqual(
            OCRCommuteScenePolicy.inferredScenePackID(
                title: "天隆寺2号口 > 雨山路",
                rawText: "支付方式：金陵通交通卡\n地铁",
                merchantBrandID: "metro_transit",
                category: .transport,
                date: date(22),
                historyItems: history,
                calendar: calendar
            ),
            "commute"
        )
        XCTAssertNil(
            OCRCommuteScenePolicy.inferredScenePackID(
                title: "天隆寺2号口 > 雨山路",
                rawText: "地铁",
                merchantBrandID: "metro_transit",
                category: .transport,
                date: date(22),
                historyItems: Array(history.prefix(1)),
                calendar: calendar
            )
        )
    }

    func testExplicitCommuteWinsButSingleNonWorkdayTransitDoesNot() {
        XCTAssertEqual(
            OCRCommuteScenePolicy.inferredScenePackID(
                title: "下班路上坐地铁",
                rawText: "地铁",
                merchantBrandID: "metro_transit",
                category: .transport,
                date: date(22),
                historyItems: [],
                calendar: calendar
            ),
            "commute"
        )
        XCTAssertNil(
            OCRCommuteScenePolicy.inferredScenePackID(
                title: "天隆寺 > 雨山路",
                rawText: "地铁",
                merchantBrandID: "metro_transit",
                category: .transport,
                date: date(19),
                historyItems: [],
                calendar: calendar
            )
        )
    }
}

final class PhotoMemoryFactBindingTests: XCTestCase {
    private var date: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 22,
            hour: 20,
            minute: 43
        ))!
    }

    func testUnknownCoffeeAndRoutineTransitPhotosStayUnclassified() {
        let coffee = HomeItem(
            title: "可乐喝咖啡",
            amount: 18,
            category: .dining,
            createdAt: date,
            emotionTag: "体验现场",
            memoryImageData: Data([0x01])
        )
        let legacyTransit = HomeItem(
            title: "地铁刷卡",
            amount: 5.7,
            category: .transport,
            createdAt: date,
            emotionTag: "刷卡进站",
            memoryImageData: Data([0x02]),
            memoryAnchorRole: .receipt,
            memoryAnchorSceneHint: .vehicleCare,
            memoryAnchorCaption: "这张图以后查起来更清楚。",
            memoryAnchorCreatedAt: date
        )

        XCTAssertNil(PhotoMemoryPromptPolicy.anchorReason(for: coffee))
        XCTAssertFalse(PhotoMemoryPromptPolicy.resolvedAnchorRole(for: coffee).isQualified)
        XCTAssertNil(PhotoMemoryPromptPolicy.anchorReason(for: legacyTransit))
        XCTAssertFalse(PhotoMemoryPromptPolicy.resolvedAnchorRole(for: legacyTransit).isQualified)
    }

    func testReceiptAndExperienceRolesRequireMatchingEvidence() {
        let vehiclePhoto = HomeItem(
            title: "停车费",
            amount: 20,
            category: .transport,
            createdAt: date,
            memoryImageData: Data([0x01])
        )
        let receiptPhoto = HomeItem(
            title: "停车费小票",
            amount: 20,
            category: .transport,
            createdAt: date,
            memoryImageData: Data([0x02])
        )
        let experiencePhoto = HomeItem(
            title: "看电影和展览",
            amount: 88,
            category: .entertainment,
            createdAt: date,
            memoryImageData: Data([0x03])
        )

        XCTAssertEqual(PhotoMemoryPromptPolicy.anchorReason(for: vehiclePhoto)?.assetRole, .object)
        XCTAssertEqual(PhotoMemoryPromptPolicy.anchorReason(for: vehiclePhoto)?.sceneHint, .vehicleCare)
        XCTAssertEqual(PhotoMemoryPromptPolicy.anchorReason(for: receiptPhoto)?.assetRole, .receipt)
        XCTAssertEqual(PhotoMemoryPromptPolicy.anchorReason(for: experiencePhoto)?.assetRole, .moment)
        XCTAssertEqual(PhotoMemoryPromptPolicy.anchorReason(for: experiencePhoto)?.sceneHint, .experience)
    }

    func testTollPhotoUsesRouteRelationshipWithoutInventingItsContents() {
        let toll = HomeItem(
            title: "过路费",
            amount: 96,
            category: .transport,
            createdAt: date,
            memoryImageData: Data(repeating: 0x01, count: 140_000),
            memoryAnchorRole: .object,
            memoryAnchorSceneHint: .importantPurchase,
            memoryAnchorCaption: "这次买的东西。",
            memoryAnchorCreatedAt: date
        )
        let reason = PhotoMemoryPromptPolicy.anchorReason(for: toll)
        let resolution = PhotoMemoryPromptPolicy.resolvedAnchorRole(for: toll)
        let anchors = MemoryAnchorSelectionPolicy.selectAnchors(
            from: [toll],
            range: .month,
            limit: 1,
            label: { _, sceneHint in sceneHint == .travelTransport ? "出门" : "记录" },
            caption: PhotoMemoryPromptPolicy.automaticAnchorCaption(role:sceneHint:)
        )

        XCTAssertTrue(PhotoMemoryPromptPolicy.isAutomaticallyAssignedAnchor(toll))
        XCTAssertTrue(PhotoMemoryPromptPolicy.isAutomaticAnchorCaption("这次买的东西"))
        XCTAssertEqual(reason?.assetRole, .place)
        XCTAssertEqual(reason?.sceneHint, .travelTransport)
        XCTAssertEqual(resolution.role, .place)
        XCTAssertEqual(resolution.sceneHint, .travelTransport)
        XCTAssertEqual(anchors.first?.caption, "和这段路一起留下。")
        if let anchor = anchors.first {
            XCTAssertEqual(
                lifeSliceSafeSharePhotoCaption(for: anchor, fallback: "这次买的东西"),
                "和这段路一起留下。"
            )
        }
        XCTAssertFalse(anchors.first?.caption.contains("买") == true)
        XCTAssertFalse(anchors.first?.caption.contains("家人") == true)
        XCTAssertEqual(
            PhotoMemoryPromptPolicy.resolvedAnchorCaption(
                storedCaption: "这次买的东西。",
                role: .place,
                sceneHint: .travelTransport
            ),
            "和这段路一起留下。"
        )
        XCTAssertEqual(
            PhotoMemoryPromptPolicy.resolvedAnchorCaption(
                storedCaption: "离开家时拍的照片",
                role: .place,
                sceneHint: .travelTransport
            ),
            "离开家时拍的照片"
        )
    }

    func testEditingReevaluatesAutomaticRoleButPreservesExplicitMetadata() {
        let automatic = HomeItem(
            title: "地铁刷卡",
            amount: 5.7,
            category: .transport,
            createdAt: date,
            memoryImageData: Data([0x01]),
            memoryAnchorRole: .receipt,
            memoryAnchorSceneHint: .vehicleCare,
            memoryAnchorCaption: "这张图以后查起来更清楚。",
            memoryAnchorCreatedAt: date
        )
        var ordinary = automatic
        ordinary.title = "可乐喝咖啡"
        ordinary.category = .dining
        let cleared = PhotoMemoryPromptPolicy.refreshedAutomaticAnchorMetadata(
            original: automatic,
            updated: ordinary
        )
        XCTAssertNil(cleared.memoryAnchorRole)
        XCTAssertNil(cleared.memoryAnchorSceneHint)
        XCTAssertNil(cleared.memoryAnchorCaption)

        var movie = automatic
        movie.title = "下班后看电影"
        movie.category = .entertainment
        let reassigned = PhotoMemoryPromptPolicy.refreshedAutomaticAnchorMetadata(
            original: automatic,
            updated: movie
        )
        XCTAssertEqual(reassigned.memoryAnchorRole, .moment)
        XCTAssertEqual(reassigned.memoryAnchorSceneHint, .experience)

        let explicit = HomeItem(
            title: "旅行记录",
            amount: 120,
            category: .lodging,
            createdAt: date,
            memoryImageData: Data([0x02]),
            memoryAnchorRole: .place,
            memoryAnchorSceneHint: .travel,
            memoryAnchorCaption: "我自己选的路上照片",
            memoryAnchorCreatedAt: date
        )
        var changed = explicit
        changed.title = "普通记录"
        changed.category = .other
        let preserved = PhotoMemoryPromptPolicy.refreshedAutomaticAnchorMetadata(
            original: explicit,
            updated: changed
        )
        XCTAssertEqual(preserved.memoryAnchorRole, .place)
        XCTAssertEqual(preserved.memoryAnchorSceneHint, .travel)
        XCTAssertEqual(preserved.memoryAnchorCaption, "我自己选的路上照片")
    }

    func testPrimaryPhotoCategoryAndClueEvidenceUseTheExactItemID() {
        let transport = HomeItem(
            title: "地铁",
            amount: 5,
            category: .transport,
            createdAt: date
        )
        let meal = HomeItem(
            title: "周记主图里的晚饭",
            amount: 36,
            category: .dining,
            createdAt: date,
            memoryImageData: Data([0x01])
        )
        let anchor = SummaryMemoryAnchor(
            id: meal.id,
            itemID: meal.id,
            title: meal.displayTitle,
            amount: meal.amount,
            createdAt: meal.createdAt,
            imageData: Data([0x01]),
            imageReference: nil,
            imageByteCount: 1,
            role: .moment,
            sceneHint: .gathering,
            label: "见面",
            caption: "和朋友的一次聚会。"
        )

        XCTAssertEqual(
            TracePhotoEvidenceBindingPolicy.primaryCategory(
                anchor: anchor,
                items: [transport, meal]
            ),
            .dining
        )
        XCTAssertEqual(
            TracePhotoEvidenceBindingPolicy.item(for: meal.id, in: [transport, meal])?.id,
            meal.id
        )
    }

    func testUnclassifiedPhotoInsightNamesTheRecordWithoutInventingAScene() {
        let item = HomeItem(
            title: "可乐喝咖啡",
            amount: 18,
            category: .dining,
            createdAt: date,
            emotionTag: "体验现场",
            memoryImageData: Data([0x01])
        )

        let insight = LifeInsightService().buildTraceInsight(
            items: [item],
            historyItems: [item],
            periodLabel: "本周",
            now: date
        )

        XCTAssertEqual(insight.highlightedItemID, item.id)
        XCTAssertTrue(insight.leadQuestion.contains(item.displayTitle))
        XCTAssertFalse(insight.leadQuestion.contains("现场"))
        XCTAssertTrue(insight.previewLine.contains(item.displayTitle))
    }
}

final class TrustedUserMomentNarrativeTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 22,
            hour: 20,
            minute: 43
        ))!
    }

    private func commutePhoto() -> HomeItem {
        HomeItem(
            title: "下班路上拍了张照片",
            amount: 5.7,
            category: .transport,
            source: .manual,
            createdAt: now,
            emotionTag: "晚间一段路",
            userEditedTitle: true,
            scenePackId: "commute",
            memoryImageData: Data(repeating: 0x01, count: 800_000)
        )
    }

    func testDownWorkPhotoUsesTheRealMomentBeforeTheLateNightThreshold() {
        let narrative = TrustedUserMomentNarrativePolicy.narrative(for: commutePhoto())

        XCTAssertEqual(narrative?.line, "下班路上，也把这一刻留了下来。")
        XCTAssertEqual(narrative?.emotionTag, "下班路上，留住这一刻")
    }

    func testMomentProjectionRequiresManualUserTextAndAnActualPhoto() {
        var noPhoto = commutePhoto()
        noPhoto.memoryImageData = nil
        noPhoto.memoryImageDatas = []
        noPhoto.memoryImageReferences = []
        XCTAssertNil(TrustedUserMomentNarrativePolicy.line(for: noPhoto))

        var imported = commutePhoto()
        imported.source = .ocr
        imported.userEditedTitle = nil
        XCTAssertNil(TrustedUserMomentNarrativePolicy.line(for: imported))

        var defaultTitle = commutePhoto()
        defaultTitle.title = defaultTitle.category.defaultRecordTitle
        XCTAssertNil(TrustedUserMomentNarrativePolicy.line(for: defaultTitle))
    }

    func testTodayMomentOutranksStableCoffeeWithoutChangingLifeMarkPriority() {
        let moment = commutePhoto()
        let coffee = HomeItem(
            title: "瑞幸咖啡",
            amount: 18,
            category: .dining,
            createdAt: calendar.date(byAdding: .minute, value: -20, to: now)!,
            merchantBrandId: "luckin"
        )
        let key = HomeLifeMarkSnapshotKey(
            ledgerRevision: 12,
            dayKey: HomeDashboardSnapshotComputation.dayKey(for: now, calendar: calendar),
            isMember: true
        )

        let snapshot = HomeDashboardSnapshotComputation.lifeMarkSnapshot(
            HomeLifeMarkPreparationInput(
                key: key,
                visibleItems: [coffee, moment],
                weekItems: [coffee, moment],
                allItems: [coffee, moment],
                isMember: true,
                frequentSuggestionLine: nil
            )
        )

        XCTAssertEqual(snapshot.todayPrimaryLine, "下班路上，也把这一刻留了下来。")
        XCTAssertEqual(
            TrustedUserMomentNarrativePolicy.preferredNarrative(in: [coffee, moment])?.itemID,
            moment.id
        )
    }

    func testTrustedMomentBecomesTheNarrativeLeadInsteadOfRoutineCoffee() {
        let moment = commutePhoto()
        let coffee = HomeItem(
            title: "瑞幸咖啡",
            amount: 18,
            category: .dining,
            createdAt: calendar.date(byAdding: .minute, value: -20, to: now)!,
            merchantBrandId: "luckin"
        )
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 13,
                items: [coffee, moment],
                previousItems: [coffee],
                now: now,
                recentLeadSignalIDs: ["scene:coffee"]
            )
        )

        XCTAssertEqual(plan.leadSignalID, "user:\(moment.id.uuidString)")
        XCTAssertEqual(plan.headline, "下班路上，也把这一刻留了下来")
    }

    func testPhotoAnchorUsesMomentCopyInsteadOfGenericUtilityCaption() {
        let moment = commutePhoto()
        let anchors = MemoryAnchorSelectionPolicy.selectAnchors(
            from: [moment],
            range: .week,
            limit: 1,
            label: { _, _ in "旧标签" },
            caption: { _, _ in "这张图以后查起来更清楚。" }
        )

        XCTAssertEqual(anchors.first?.itemID, moment.id)
        XCTAssertEqual(anchors.first?.label, "照片")
        XCTAssertEqual(anchors.first?.caption, "下班路上，也把这一刻留了下来。")
    }
}

@MainActor
final class TodayPlaybackContentSnapshotTests: XCTestCase {
    func testSnapshotFreezesTodayItemsMomentsAndDurationForPlayback() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 21
        ))!
        var items = [
            HomeItem(
                title: "早餐",
                amount: 12,
                category: .dining,
                createdAt: calendar.date(bySettingHour: 8, minute: 10, second: 0, of: now)!
            ),
            HomeItem(
                title: "午餐",
                amount: 28,
                category: .dining,
                createdAt: calendar.date(bySettingHour: 12, minute: 20, second: 0, of: now)!
            ),
            HomeItem(
                title: "下班地铁",
                amount: 3,
                category: .transport,
                createdAt: calendar.date(bySettingHour: 18, minute: 30, second: 0, of: now)!
            ),
            HomeItem(
                title: "昨天",
                amount: 20,
                category: .other,
                createdAt: calendar.date(byAdding: .day, value: -1, to: now)!
            )
        ]

        let first = BillPlaybackSheet.makeContentSnapshot(
            allItems: items,
            sourceRevision: 7,
            now: now,
            calendar: calendar
        )
        let second = BillPlaybackSheet.makeContentSnapshot(
            allItems: items,
            sourceRevision: 7,
            now: now,
            calendar: calendar
        )
        items.append(
            HomeItem(
                title: "夜宵",
                amount: 16,
                category: .dining,
                createdAt: calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now)!
            )
        )

        XCTAssertEqual(first.sourceRevision, 7)
        XCTAssertEqual(first.todayItems.map(\.title), ["早餐", "午餐", "下班地铁"])
        XCTAssertEqual(first.playbackMoments, second.playbackMoments)
        XCTAssertEqual(first.playbackMoments.count, 4)
        XCTAssertEqual(first.playbackDuration, 10.4, accuracy: 0.001)
        XCTAssertEqual(first.todayItems.count, 3)
        XCTAssertEqual(first.narrativePlan?.sourceRevision, 7)
    }

    func testRepeatedCoffeeDoesNotSurroundTodayPlaybackButRemainsInItemCards() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 22
        ))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let previous = [8, 11, 14, 17].map { hour in
            HomeItem(
                title: "咖啡",
                amount: 16,
                category: .dining,
                createdAt: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: yesterday)!
            )
        }
        let current = [8, 11, 14, 17].map { hour in
            HomeItem(
                title: "咖啡",
                amount: 16,
                category: .dining,
                createdAt: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now)!
            )
        }

        let snapshot = BillPlaybackSheet.makeContentSnapshot(
            allItems: previous + current,
            sourceRevision: 21,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.playbackMoments.first?.id, "summary-opening")
        XCTAssertEqual(snapshot.playbackMoments.last?.id, "summary-close")
        XCTAssertFalse(snapshot.playbackMoments.first?.body.contains("咖啡") == true)
        XCTAssertFalse(snapshot.playbackMoments.last?.title.contains("咖啡") == true)
        XCTAssertFalse(snapshot.playbackMoments.last?.body.contains("咖啡") == true)
        XCTAssertTrue(snapshot.playbackMoments.dropFirst().dropLast().contains { $0.title.contains("咖啡") })
        XCTAssertTrue(snapshot.narrativePlan?.markLabels.contains("咖啡饮品") == true)
    }

    func testDenseSnapshotBuildsTimeBlocksOnceFromImmutableInput() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 22
        ))!
        let hours = [8, 9, 10, 12, 13, 14, 18, 19, 20]
        let items = hours.enumerated().map { index, hour in
            HomeItem(
                title: "记录 \(index)",
                amount: Double(index + 1),
                category: index.isMultiple(of: 2) ? .dining : .transport,
                createdAt: calendar.date(bySettingHour: hour, minute: index, second: 0, of: now)!
            )
        }

        let snapshot = BillPlaybackSheet.makeContentSnapshot(
            allItems: items,
            sourceRevision: 9,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.todayItems.count, 9)
        XCTAssertEqual(snapshot.playbackMoments.map(\.id), [
            "summary-opening",
            "time-morning",
            "time-afternoon",
            "time-evening",
            "summary-close"
        ])
        XCTAssertEqual(snapshot.playbackDuration, 13, accuracy: 0.001)
    }

    func testPresentationRequiresPreparedSnapshotAndOnlyAcceptsOneActivePayload() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 22
        ))!
        let item = HomeItem(title: "晚餐", amount: 28, category: .dining, createdAt: now)
        let prepared = TodayPlaybackPresentationPayload(contentSnapshot: BillPlaybackSheet.makeContentSnapshot(
            allItems: [item],
            sourceRevision: 11,
            now: now,
            calendar: calendar
        ))
        let unprepared = TodayPlaybackPresentationPayload(contentSnapshot: .empty)

        XCTAssertTrue(TodayPlaybackPresentationPolicy.accepts(prepared, while: nil))
        XCTAssertFalse(TodayPlaybackPresentationPolicy.accepts(prepared, while: prepared))
        XCTAssertFalse(TodayPlaybackPresentationPolicy.accepts(unprepared, while: nil))
        XCTAssertTrue(TodayPlaybackPresentationPolicy.consumesQuota(prepared))
        XCTAssertFalse(TodayPlaybackPresentationPolicy.consumesQuota(unprepared))
    }

    func testValidEmptyDayCanPresentWithoutConsumingQuota() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 8
        ))!
        let payload = TodayPlaybackPresentationPayload(contentSnapshot: BillPlaybackSheet.makeContentSnapshot(
            allItems: [],
            sourceRevision: 12,
            now: now,
            calendar: calendar
        ))

        XCTAssertTrue(payload.contentSnapshot.isPrepared)
        XCTAssertTrue(TodayPlaybackPresentationPolicy.accepts(payload, while: nil))
        XCTAssertFalse(TodayPlaybackPresentationPolicy.consumesQuota(payload))
    }
}

final class LifetimeArchiveSnapshotComputationTests: XCTestCase {
    func testArchiveSnapshotUsesCommittedRecordsAndPreservesExistingCopyRules() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 12
        ))!
        let items = [
            HomeItem(
                title: "今天午餐",
                amount: 28,
                category: .dining,
                createdAt: now
            ),
            HomeItem(
                title: "昨天午餐",
                amount: 26,
                category: .dining,
                createdAt: calendar.date(byAdding: .day, value: -1, to: now)!
            ),
            HomeItem(
                title: "上月地铁",
                amount: 3,
                category: .transport,
                createdAt: calendar.date(byAdding: .month, value: -1, to: now)!
            ),
            HomeItem(
                title: "待整理草稿",
                amount: 88,
                category: .other,
                createdAt: now,
                draftMeta: .init(batchId: "archive-qa", importedAt: now, status: .pending)
            )
        ]
        let input = LifetimeArchivePreparationInput(
            revision: 12,
            items: items,
            now: now,
            calendar: calendar
        )

        let first = LifetimeArchiveSnapshotComputation.make(input)
        let second = LifetimeArchiveSnapshotComputation.make(input)

        XCTAssertEqual(first.sourceRevision, 12)
        XCTAssertTrue(first.proofLine.contains("3 笔记录"))
        XCTAssertTrue(first.proofLine.contains("2 个月"))
        XCTAssertEqual(first.metrics[1].value, "3条")
        XCTAssertEqual(first.metrics[3].value, "2个月")
        XCTAssertEqual(first.title, second.title)
        XCTAssertEqual(first.subtitle, second.subtitle)
        XCTAssertEqual(first.metrics.map(\.value), second.metrics.map(\.value))
        XCTAssertEqual(first.stages.map(\.value), second.stages.map(\.value))
        XCTAssertEqual(first.primaryLine, second.primaryLine)
        XCTAssertEqual(first.closingLine, second.closingLine)
    }

    func testArchiveEmptySnapshotDoesNotRequireLedgerScanningInViewBody() {
        let snapshot = LifetimeArchiveSnapshotComputation.make(
            LifetimeArchivePreparationInput(
                revision: 2,
                items: [],
                now: Date(timeIntervalSince1970: 1_784_240_000),
                calendar: Calendar(identifier: .gregorian)
            )
        )

        XCTAssertEqual(snapshot.sourceRevision, 2)
        XCTAssertEqual(snapshot.metrics[1].value, "0条")
        XCTAssertEqual(snapshot.proofLine, "先从第一笔开始，后面会自动整理出周记和月章。")
    }

    func testArchiveDiskCacheSurvivesRecreationAndRejectsAnotherLedgerOrDay() {
        let suiteName = "LifetimeArchiveSnapshotComputationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let storageKey = "archive-test"
        let context = LifetimeArchiveCacheContext(
            ledgerFingerprint: "ledger-a",
            dayKey: "2026-07-23"
        )
        let snapshot = LifetimeArchiveSnapshot.preparedEmpty(sourceRevision: 3)
        LifetimeArchiveCacheStore(defaults: defaults, storageKey: storageKey).store(
            snapshot,
            context: context
        )

        let relaunched = LifetimeArchiveCacheStore(
            defaults: defaults,
            storageKey: storageKey
        )
        XCTAssertEqual(relaunched.snapshot(for: context), snapshot)
        XCTAssertNil(
            relaunched.snapshot(
                for: LifetimeArchiveCacheContext(
                    ledgerFingerprint: "ledger-b",
                    dayKey: context.dayKey
                )
            )
        )
        XCTAssertNil(
            relaunched.snapshot(
                for: LifetimeArchiveCacheContext(
                    ledgerFingerprint: context.ledgerFingerprint,
                    dayKey: "2026-07-24"
                )
            )
        )

        defaults.set(Data([0xFF]), forKey: storageKey)
        XCTAssertNil(relaunched.snapshot(for: context))
        XCTAssertNil(defaults.data(forKey: storageKey))
    }

    @MainActor
    func testSharedArchiveStorePublishesARealPreparedEmptySnapshot() async {
        let suiteName = "LifetimeArchiveSnapshotStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = LifetimeArchiveSnapshotStore(
            cacheStore: LifetimeArchiveCacheStore(
                defaults: defaults,
                storageKey: "archive-store-test"
            )
        )
        store.prepareIfNeeded(
            revision: 7,
            items: [],
            now: Date(timeIntervalSince1970: 1_790_000_000),
            calendar: Calendar(identifier: .gregorian)
        )
        for _ in 0..<50 where store.snapshot == nil {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }

        XCTAssertEqual(store.snapshot?.sourceRevision, 7)
        XCTAssertEqual(store.snapshot?.metrics[1].value, "0条")
        XCTAssertFalse(store.isPreparing)
    }
}

final class AccountMemoryStatsComputationTests: XCTestCase {
    func testAccountStatsReuseOneLedgerRevisionSnapshot() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let base = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 1,
            hour: 12
        ))!
        var items = [0, 1, 2, 9].map { dayOffset in
            HomeItem(
                title: "记录 \(dayOffset)",
                amount: Double(dayOffset + 1),
                category: .other,
                createdAt: calendar.date(byAdding: .day, value: dayOffset, to: base)!
            )
        }
        items.append(
            HomeItem(
                title: "上月记录",
                amount: 20,
                category: .dining,
                createdAt: calendar.date(byAdding: .month, value: -1, to: base)!
            )
        )
        items.append(
            HomeItem(
                title: "零金额",
                amount: 0,
                category: .other,
                createdAt: base
            )
        )

        let input = AccountMemoryStatsPreparationInput(
            items: items,
            sourceRevision: 18,
            calendar: calendar
        )
        let first = AccountMemoryStatsComputation.make(input)
        let second = AccountMemoryStatsComputation.make(input)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.sourceRevision, 18)
        XCTAssertEqual(first.traceCount, 5)
        XCTAssertEqual(first.recordStreakDays, 3)
        XCTAssertEqual(first.weeklyStoryCount, 3)
        XCTAssertEqual(first.monthlyStoryCount, 2)
    }

    func testAccountStatsEmptySnapshotKeepsZeroValues() {
        let stats = AccountMemoryStatsComputation.make(
            items: [],
            sourceRevision: 3,
            calendar: Calendar(identifier: .gregorian)
        )

        XCTAssertEqual(stats.sourceRevision, 3)
        XCTAssertEqual(stats.traceCount, 0)
        XCTAssertEqual(stats.recordStreakDays, 0)
        XCTAssertEqual(stats.weeklyStoryCount, 0)
        XCTAssertEqual(stats.monthlyStoryCount, 0)
    }
}

final class TraceCustomRangePolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12
    ) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }

    func testCustomRangeLabelUsesOneDateForSingleDay() {
        let morning = date(year: 2026, month: 8, day: 6, hour: 8)
        let evening = date(year: 2026, month: 8, day: 6, hour: 21)

        XCTAssertEqual(
            TraceCustomRangePresentationPolicy.label(
                startDate: morning,
                endDate: evening,
                calendar: calendar
            ),
            "8月6日"
        )
    }

    func testCustomRangeLabelUsesMonthAndDayForSameYearRange() {
        XCTAssertEqual(
            TraceCustomRangePresentationPolicy.label(
                startDate: date(year: 2026, month: 8, day: 6),
                endDate: date(year: 2026, month: 9, day: 4),
                calendar: calendar
            ),
            "8月6日 - 9月4日"
        )
    }

    func testCustomRangeLabelIncludesYearsAcrossYearBoundary() {
        XCTAssertEqual(
            TraceCustomRangePresentationPolicy.label(
                startDate: date(year: 2025, month: 12, day: 31),
                endDate: date(year: 2026, month: 1, day: 2),
                calendar: calendar
            ),
            "2025年12月31日 - 2026年1月2日"
        )
    }

    func testCustomRangeNormalizationOrdersReverseDatesAtDayBoundaries() {
        let later = date(year: 2026, month: 9, day: 4, hour: 22)
        let earlier = date(year: 2026, month: 8, day: 6, hour: 9)
        let range = TraceCustomRangePresentationPolicy.normalized(
            startDate: later,
            endDate: earlier,
            calendar: calendar
        )

        XCTAssertEqual(range.startDate, calendar.startOfDay(for: earlier))
        XCTAssertEqual(range.endDate, calendar.startOfDay(for: later))
        XCTAssertEqual(
            TraceCustomRangePresentationPolicy.label(
                startDate: later,
                endDate: earlier,
                calendar: calendar
            ),
            "8月6日 - 9月4日"
        )
    }

    func testCustomRangeDraftEditingDoesNotMutateCommittedRange() {
        let committedStart = date(year: 2026, month: 7, day: 1)
        let committedEnd = date(year: 2026, month: 7, day: 31)
        var state = StatsTabState()
        state.customStartDate = committedStart
        state.customEndDate = committedEnd

        state.beginCustomRangeEditing()
        state.customStartDateDraft = date(year: 2026, month: 8, day: 6)
        state.customEndDateDraft = date(year: 2026, month: 9, day: 4)

        XCTAssertTrue(state.showsCustomDatePanel)
        XCTAssertEqual(state.customStartDate, committedStart)
        XCTAssertEqual(state.customEndDate, committedEnd)
    }

    func testCancellingCustomRangeEditingRestoresCommittedRange() {
        let committedStart = date(year: 2026, month: 7, day: 1)
        let committedEnd = date(year: 2026, month: 7, day: 31)
        var state = StatsTabState()
        state.customStartDate = committedStart
        state.customEndDate = committedEnd
        state.beginCustomRangeEditing()
        state.customStartDateDraft = date(year: 2026, month: 8, day: 6)
        state.customEndDateDraft = date(year: 2026, month: 9, day: 4)

        state.cancelCustomRangeEditing()

        XCTAssertFalse(state.showsCustomDatePanel)
        XCTAssertEqual(state.customStartDate, committedStart)
        XCTAssertEqual(state.customEndDate, committedEnd)
        XCTAssertEqual(state.customStartDateDraft, committedStart)
        XCTAssertEqual(state.customEndDateDraft, committedEnd)
    }

    func testCommittingCustomRangePublishesBothEndpointsOnce() {
        let range = TraceCustomDateRange(
            startDate: date(year: 2026, month: 8, day: 6, hour: 0),
            endDate: date(year: 2026, month: 9, day: 4, hour: 0)
        )
        var state = StatsTabState()
        state.beginCustomRangeEditing()

        state.commitCustomRange(range)

        XCTAssertEqual(state.customStartDate, range.startDate)
        XCTAssertEqual(state.customEndDate, range.endDate)
        XCTAssertEqual(state.customStartDateDraft, range.startDate)
        XCTAssertEqual(state.customEndDateDraft, range.endDate)
        XCTAssertTrue(state.useCustomRange)
        XCTAssertFalse(state.showsCustomDatePanel)
    }

    func testCustomRangePublicationRejectsStaleSnapshotKey() {
        let expected = snapshotKey(revision: 8)
        let stale = snapshotKey(revision: 7)

        XCTAssertFalse(TraceDetailListSnapshotPublicationPolicy.accepts(
            candidateKey: stale,
            expectedKey: expected,
            requestMatches: true
        ))
    }

    func testCustomRangePublicationRejectsInvalidatedRequest() {
        let key = snapshotKey(revision: 8)

        XCTAssertFalse(TraceDetailListSnapshotPublicationPolicy.accepts(
            candidateKey: key,
            expectedKey: key,
            requestMatches: false
        ))
        XCTAssertTrue(TraceDetailListSnapshotPublicationPolicy.accepts(
            candidateKey: key,
            expectedKey: key,
            requestMatches: true
        ))
    }

    private func snapshotKey(revision: Int) -> TraceDetailListSnapshotKey {
        TraceDetailListSnapshotKey(
            ledgerRevision: revision,
            periodKey: "本周",
            categoryKey: nil,
            usesCustomRange: true,
            customStartDate: date(year: 2026, month: 8, day: 6, hour: 0),
            customEndDate: date(year: 2026, month: 9, day: 4, hour: 0)
        )
    }
}

final class TraceDetailListSnapshotComputationTests: XCTestCase {
    private func snapshotKey(revision: Int, date: Date) -> TraceDetailListSnapshotKey {
        TraceDetailListSnapshotKey(
            ledgerRevision: revision,
            periodKey: "本月",
            categoryKey: nil,
            usesCustomRange: false,
            customStartDate: date,
            customEndDate: date
        )
    }

    func testDetailSnapshotSharesItemsIDsTotalAndDayGroupsFromOneFilterPass() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let start = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 1
        ))!
        let end = calendar.date(byAdding: .day, value: 3, to: start)!
        let diningMorning = HomeItem(
            title: "早餐",
            amount: 12,
            category: .dining,
            createdAt: calendar.date(byAdding: .hour, value: 8, to: start)!
        )
        let diningNextDay = HomeItem(
            title: "午餐",
            amount: 28,
            category: .dining,
            createdAt: calendar.date(byAdding: .hour, value: 36, to: start)!
        )
        let zeroDining = HomeItem(
            title: "零金额",
            amount: 0,
            category: .dining,
            createdAt: calendar.date(byAdding: .hour, value: 37, to: start)!
        )
        let transport = HomeItem(
            title: "地铁",
            amount: 3,
            category: .transport,
            createdAt: calendar.date(byAdding: .hour, value: 12, to: start)!
        )
        let outside = HomeItem(
            title: "范围外",
            amount: 50,
            category: .dining,
            createdAt: calendar.date(byAdding: .day, value: 5, to: start)!
        )
        let key = TraceDetailListSnapshotKey(
            ledgerRevision: 4,
            periodKey: "本月",
            categoryKey: HomeItem.Category.dining.rawValue,
            usesCustomRange: true,
            customStartDate: start,
            customEndDate: calendar.date(byAdding: .day, value: 2, to: start)!
        )
        let input = TraceDetailListPreparationInput(
            key: key,
            sourceItems: [outside, diningMorning, transport, zeroDining, diningNextDay],
            dateInterval: DateInterval(start: start, end: end),
            category: .dining,
            calendar: calendar
        )

        let first = TraceDetailListSnapshotComputation.make(input)
        let second = TraceDetailListSnapshotComputation.make(input)

        XCTAssertEqual(first.key, key)
        XCTAssertEqual(first.items.map(\.title), ["零金额", "午餐", "早餐"])
        XCTAssertEqual(first.itemIDs, first.items.map(\.id))
        XCTAssertEqual(first.totalExpense, 40, accuracy: 0.001)
        XCTAssertEqual(first.dayGroups.count, 2)
        XCTAssertEqual(first.dayGroups.first?.items.map(\.title) ?? [], ["零金额", "午餐"])
        XCTAssertEqual(first.items.map(\.id), second.items.map(\.id))
        XCTAssertEqual(first.dayGroups.map(\.id), second.dayGroups.map(\.id))
    }

    func testDirectLedgerSeedIsRenderableBeforeBackgroundRefresh() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let date = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 8,
            hour: 12
        ))!
        let item = HomeItem(
            title: "午餐",
            amount: 28,
            category: .dining,
            createdAt: date
        )
        let snapshot = TraceDetailListSnapshotComputation.make(
            TraceDetailListPreparationInput(
                key: snapshotKey(revision: 9, date: date),
                sourceItems: [item],
                dateInterval: nil,
                category: nil,
                calendar: calendar
            )
        )

        XCTAssertEqual(snapshot.items.map(\.id), [item.id])
        XCTAssertEqual(snapshot.dayGroups.flatMap(\.items).map(\.id), [item.id])
        XCTAssertEqual(snapshot.totalExpense, 28, accuracy: 0.001)
    }

    func testDetailSnapshotKeyChangesOnlyForLedgerOrFilterInput() {
        let date = Date(timeIntervalSince1970: 1_784_240_000)
        let first = TraceDetailListSnapshotKey(
            ledgerRevision: 2,
            periodKey: "本周",
            categoryKey: nil,
            usesCustomRange: false,
            customStartDate: date,
            customEndDate: date
        )

        XCTAssertEqual(first, first)
        XCTAssertNotEqual(first, TraceDetailListSnapshotKey(
            ledgerRevision: 3,
            periodKey: first.periodKey,
            categoryKey: first.categoryKey,
            usesCustomRange: first.usesCustomRange,
            customStartDate: first.customStartDate,
            customEndDate: first.customEndDate
        ))
        XCTAssertNotEqual(first, TraceDetailListSnapshotKey(
            ledgerRevision: first.ledgerRevision,
            periodKey: first.periodKey,
            categoryKey: HomeItem.Category.dining.rawValue,
            usesCustomRange: first.usesCustomRange,
            customStartDate: first.customStartDate,
            customEndDate: first.customEndDate
        ))
    }

    func testRapidStableIDDeletionUpdatesCountTotalAndDayGroupsWithoutResurrection() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let firstDay = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 1
        ))!
        let items = (0..<20).map { index in
            HomeItem(
                title: "连续删除 \(index + 1)",
                amount: Double(index + 1),
                category: .dining,
                createdAt: calendar.date(
                    byAdding: .hour,
                    value: index < 10 ? index : index + 14,
                    to: firstDay
                )!
            )
        }
        var snapshot = TraceDetailListSnapshotComputation.make(
            TraceDetailListPreparationInput(
                key: snapshotKey(revision: 0, date: firstDay),
                sourceItems: items,
                dateInterval: nil,
                category: nil,
                calendar: calendar
            )
        )
        var deletedIDs = Set<UUID>()

        for index in items.indices {
            let deletedID = items[index].id
            deletedIDs.insert(deletedID)
            snapshot = TraceDetailListSnapshotComputation.deleting(
                itemIDs: Set([deletedID]),
                from: snapshot,
                nextKey: snapshotKey(revision: index + 1, date: firstDay),
                calendar: calendar
            )

            XCTAssertEqual(snapshot.items.count, items.count - index - 1)
            XCTAssertFalse(snapshot.itemIDs.contains(deletedID))
            XCTAssertTrue(Set(snapshot.itemIDs).intersection(deletedIDs).isEmpty)
            XCTAssertEqual(
                snapshot.totalExpense,
                items.dropFirst(index + 1).reduce(0) { $0 + $1.amount },
                accuracy: 0.001
            )
            XCTAssertEqual(snapshot.dayGroups.flatMap(\.items).count, snapshot.items.count)

            let repeatedDeletion = TraceDetailListSnapshotComputation.deleting(
                itemIDs: Set([deletedID]),
                from: snapshot,
                nextKey: snapshot.key,
                calendar: calendar
            )
            XCTAssertEqual(repeatedDeletion.itemIDs, snapshot.itemIDs)
            XCTAssertEqual(repeatedDeletion.totalExpense, snapshot.totalExpense, accuracy: 0.001)
        }

        XCTAssertTrue(snapshot.items.isEmpty)
        XCTAssertTrue(snapshot.dayGroups.isEmpty)
        XCTAssertEqual(snapshot.totalExpense, 0, accuracy: 0.001)
    }

    func testDeletingLastRecordInDayRemovesDayGroup() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let firstDay = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 1,
            hour: 12
        ))!
        let secondDay = calendar.date(byAdding: .day, value: 1, to: firstDay)!
        let first = HomeItem(title: "第一天", amount: 10, category: .dining, createdAt: firstDay)
        let second = HomeItem(title: "第二天", amount: 20, category: .transport, createdAt: secondDay)
        let initial = TraceDetailListSnapshotComputation.make(
            TraceDetailListPreparationInput(
                key: snapshotKey(revision: 1, date: firstDay),
                sourceItems: [second, first],
                dateInterval: nil,
                category: nil,
                calendar: calendar
            )
        )

        let updated = TraceDetailListSnapshotComputation.deleting(
            itemIDs: Set([second.id]),
            from: initial,
            nextKey: snapshotKey(revision: 2, date: firstDay),
            calendar: calendar
        )

        XCTAssertEqual(initial.dayGroups.count, 2)
        XCTAssertEqual(updated.dayGroups.count, 1)
        XCTAssertEqual(updated.dayGroups.first?.items.map(\.id), [first.id])
        XCTAssertEqual(updated.itemIDs, [first.id])
        XCTAssertEqual(updated.totalExpense, 10, accuracy: 0.001)
    }

    func testStaleDerivedPeriodItemsCannotBeStampedWithNewLedgerRevision() {
        XCTAssertFalse(TraceDetailListSourcePolicy.canReuseDerivedPeriodItems(
            ledgerRevision: 12,
            derivedRevision: 11,
            usesCustomRange: false
        ))
    }

    func testCurrentDerivedPeriodItemsRemainReusableOutsideCustomRange() {
        XCTAssertTrue(TraceDetailListSourcePolicy.canReuseDerivedPeriodItems(
            ledgerRevision: 12,
            derivedRevision: 12,
            usesCustomRange: false
        ))
        XCTAssertFalse(TraceDetailListSourcePolicy.canReuseDerivedPeriodItems(
            ledgerRevision: 12,
            derivedRevision: 12,
            usesCustomRange: true
        ))
    }

    func testPresentationCarriesInitialSnapshotAndRejectsDuplicateSheetRequest() {
        let date = Date(timeIntervalSince1970: 1_784_240_000)
        let key = TraceDetailListSnapshotKey(
            ledgerRevision: 2,
            periodKey: "本周",
            categoryKey: nil,
            usesCustomRange: false,
            customStartDate: date,
            customEndDate: date
        )
        let item = HomeItem(title: "午餐", amount: 28, category: .dining, createdAt: date)
        let snapshot = TraceDetailListSnapshot(
            key: key,
            items: [item],
            itemIDs: [item.id],
            totalExpense: 28,
            dayGroups: [TraceDayGroup(id: "day", date: date, items: [item])]
        )
        let payload = TraceDetailPresentationPayload(initialSnapshot: snapshot)

        XCTAssertTrue(TraceDetailPresentationPolicy.accepts(payload, while: nil))
        XCTAssertFalse(TraceDetailPresentationPolicy.accepts(payload, while: payload))
        XCTAssertEqual(payload.initialSnapshot.items.map(\.id), [item.id])
        XCTAssertEqual(payload.initialSnapshot.totalExpense, 28, accuracy: 0.001)
    }
}

final class LedgerCloudUploadCompletionPolicyTests: XCTestCase {
    func testLateUploadRequiresCompensatingDeleteAfterLocalRecordWasDeleted() {
        let uploadedID = UUID()

        XCTAssertTrue(LedgerCloudUploadCompletionPolicy.requiresCompensatingDelete(
            uploadedItemID: uploadedID,
            currentItemIDs: Set([UUID()])
        ))
    }

    func testCompletedUploadRemainsWhenRecordStillExistsLocally() {
        let uploadedID = UUID()

        XCTAssertFalse(LedgerCloudUploadCompletionPolicy.requiresCompensatingDelete(
            uploadedItemID: uploadedID,
            currentItemIDs: Set([uploadedID, UUID()])
        ))
    }
}

final class TraceChapterCoverPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: day,
            hour: hour
        ))!
    }

    private func anchor(for item: HomeItem, id: UUID = UUID()) -> SummaryMemoryAnchor {
        SummaryMemoryAnchor(
            id: id,
            itemID: item.id,
            title: item.title,
            amount: item.amount,
            createdAt: item.createdAt,
            imageData: Data([1, 2, 3]),
            imageReference: "images/\(item.id.uuidString).jpg",
            imageByteCount: 3,
            role: .moment,
            sceneHint: .experience,
            label: "现场",
            caption: "这条记录的照片。"
        )
    }

    func testWeekCoverUsesRepresentativePhotoRecordAndFactualSupport() {
        let dining = HomeItem(
            title: "巧婆红汤馄饨（云密城店）",
            amount: 18,
            category: .dining,
            createdAt: date(day: 15, hour: 19)
        )
        let morningCommute = HomeItem(
            title: "上班地铁",
            amount: 4.75,
            category: .transport,
            createdAt: date(day: 16, hour: 8)
        )
        let eveningCommute = HomeItem(
            title: "下班地铁",
            amount: 4.75,
            category: .transport,
            createdAt: date(day: 16, hour: 19)
        )
        let photoAnchor = anchor(for: dining)

        let facts = TraceChapterCoverPolicy.make(
            range: .week,
            items: [eveningCommute, morningCommute, dining],
            anchors: [photoAnchor],
            now: date(day: 18),
            calendar: calendar
        )

        XCTAssertEqual(facts.title, "7月15日，巧婆红汤馄饨")
        XCTAssertEqual(facts.supportLine, "3笔记录分布在2天，交通最多，共2笔。")
        XCTAssertEqual(facts.representativeItemID, dining.id)
        XCTAssertEqual(facts.coverCaption, "7/15 · 巧婆红汤馄饨")
        XCTAssertNil(facts.coverAnchorID)
        XCTAssertFalse(facts.title.contains("被留下"))
    }

    func testMonthCoverExplainsCountShareAndBuildsRecordRhythm() {
        let commute1 = HomeItem(title: "上班地铁", amount: 4, category: .transport, createdAt: date(day: 1, hour: 8))
        let commute2 = HomeItem(title: "下班地铁", amount: 4, category: .transport, createdAt: date(day: 2, hour: 18))
        let commute3 = HomeItem(title: "上班公交", amount: 3, category: .transport, createdAt: date(day: 3, hour: 8))
        let breakfast = HomeItem(title: "早餐", amount: 12, category: .dining, createdAt: date(day: 10, hour: 8))
        let dinner = HomeItem(title: "晚饭", amount: 28, category: .dining, createdAt: date(day: 10, hour: 19))
        let coverAnchor = anchor(for: breakfast)

        let facts = TraceChapterCoverPolicy.make(
            range: .month,
            items: [dinner, breakfast, commute3, commute2, commute1],
            anchors: [coverAnchor],
            now: date(day: 18),
            calendar: calendar
        )

        XCTAssertEqual(facts.title, "7月，交通出现得最多")
        XCTAssertEqual(facts.supportLine, "5笔记录分布在4天，交通共3笔，占本月记录60%。")
        XCTAssertEqual(facts.activeDays, 4)
        XCTAssertEqual(facts.longestStreak, 3)
        XCTAssertEqual(facts.topCategory, .transport)
        XCTAssertEqual(facts.topCategoryRecordSharePercent, 60)
        XCTAssertEqual(facts.coverAnchorID, coverAnchor.id)
        XCTAssertEqual(facts.coverItemID, breakfast.id)
        XCTAssertEqual(facts.monthDayCounts.count, 31)
        XCTAssertEqual(facts.monthDayCounts[9], 2)
        XCTAssertEqual(facts.currentMonthDay, 18)
    }

    func testMonthWithoutPhotoUsesValidEmptyRhythmInsteadOfPhotoPlaceholder() {
        let facts = TraceChapterCoverPolicy.make(
            range: .month,
            items: [],
            anchors: [],
            now: date(day: 18),
            calendar: calendar
        )

        XCTAssertEqual(facts.title, "7月还没有记录")
        XCTAssertEqual(facts.supportLine, "记下第一笔后，这里会按日期和分类整理。")
        XCTAssertNil(facts.coverAnchorID)
        XCTAssertNil(facts.coverCaption)
        XCTAssertEqual(facts.monthDayCounts, Array(repeating: 0, count: 31))
        XCTAssertEqual(facts.activeDays, 0)
        XCTAssertEqual(facts.longestStreak, 0)
    }

    func testTopCategoryTieUsesAmountThenStableCategoryOrder() {
        let items = [
            HomeItem(title: "早餐", amount: 8, category: .dining, createdAt: date(day: 1, hour: 8)),
            HomeItem(title: "晚饭", amount: 12, category: .dining, createdAt: date(day: 2, hour: 19)),
            HomeItem(title: "上班地铁", amount: 18, category: .transport, createdAt: date(day: 3, hour: 8)),
            HomeItem(title: "下班地铁", amount: 18, category: .transport, createdAt: date(day: 4, hour: 19))
        ]

        let facts = TraceChapterCoverPolicy.make(
            range: .month,
            items: items,
            anchors: [],
            now: date(day: 18),
            calendar: calendar
        )

        XCTAssertEqual(facts.topCategory, .transport)
        XCTAssertEqual(facts.title, "7月，交通出现得最多")
        XCTAssertEqual(facts.topCategoryCount, 2)
        XCTAssertEqual(facts.topCategoryRecordSharePercent, 50)
    }

    func testMonthDiaryExcludesEveryAnchorFromTheCoverRecord() {
        let coverItem = HomeItem(title: "早餐", amount: 12, category: .dining, createdAt: date(day: 10))
        let otherItem = HomeItem(title: "地铁", amount: 4, category: .transport, createdAt: date(day: 11))
        let cover = anchor(for: coverItem)
        let duplicateCover = anchor(for: coverItem)
        let other = anchor(for: otherItem)

        let diaryAnchors = TraceMonthDiaryPolicy.anchors(
            from: [cover, duplicateCover, other],
            excludingCoverItemID: coverItem.id
        )

        XCTAssertEqual(diaryAnchors.map(\.id), [other.id])
    }

    func testMonthSnapshotPreparesSixDiaryPhotosWithoutChangingTheThreeCoverAnchors() {
        let items = (1...8).map { index in
            HomeItem(
                title: "第\(index)次朋友聚会",
                amount: Double(20 + index),
                category: .social,
                createdAt: date(day: index),
                userEditedTitle: true,
                memoryImageData: Data([UInt8(index)]),
                memoryAnchorRole: .moment,
                memoryAnchorSceneHint: .gathering
            )
        }
        let snapshot = TraceSnapshotComputation.buildChapter(
            TraceChapterComputationInput(
                range: .month,
                items: items,
                allItems: items,
                isMember: true,
                prioritizeRecurringMarks: true,
                periodKey: "2026-07",
                usesEchoAnchor: false,
                sourceRevision: 82,
                now: date(day: 18)
            )
        )

        XCTAssertEqual(snapshot.memoryAnchors.count, 3)
        XCTAssertEqual(snapshot.monthDiaryAnchors.count, 6)
        guard let coverItemID = snapshot.coverFacts.coverItemID else {
            return XCTFail("month snapshot should select one cover photo")
        }
        XCTAssertFalse(snapshot.monthDiaryAnchors.contains { $0.itemID == coverItemID })
        XCTAssertEqual(Set(snapshot.monthDiaryAnchors.map(\.itemID)).count, 6)
    }
}

final class WeeklyShareCardPhotoPreparationPolicyTests: XCTestCase {
    func testResolutionKeepsSourceOrderAndCountsOnlyDecodedPhotos() {
        let first = UUID()
        let missing = UUID()
        let third = UUID()
        let ignoredFourth = UUID()

        let resolution = WeeklyShareCardPhotoPreparationPolicy.resolve(
            requestedAnchorIDs: [first, missing, third, ignoredFourth],
            loadedAnchorIDs: [third, first, ignoredFourth]
        )

        XCTAssertEqual(resolution.availableAnchorIDs, [first, third])
        XCTAssertEqual(resolution.unavailablePhotoCount, 1)
    }

    func testResolutionDowngradesAllMissingPhotosWithoutInventingAvailability() {
        let requested = [UUID(), UUID(), UUID()]

        let resolution = WeeklyShareCardPhotoPreparationPolicy.resolve(
            requestedAnchorIDs: requested,
            loadedAnchorIDs: []
        )

        XCTAssertTrue(resolution.availableAnchorIDs.isEmpty)
        XCTAssertEqual(resolution.unavailablePhotoCount, 3)
    }

    func testResolutionIgnoresLoadedIDsOutsideTheLockedRequest() {
        let requested = UUID()

        let resolution = WeeklyShareCardPhotoPreparationPolicy.resolve(
            requestedAnchorIDs: [requested],
            loadedAnchorIDs: [UUID()]
        )

        XCTAssertTrue(resolution.availableAnchorIDs.isEmpty)
        XCTAssertEqual(resolution.unavailablePhotoCount, 1)
    }
}

final class WeeklyShareCardTemplateCapabilityPolicyTests: XCTestCase {
    func testAutomaticTemplateFollowsTheNumberOfActuallyAvailablePhotos() {
        XCTAssertEqual(
            WeeklyShareCardTemplateCapabilityPolicy.recommended(photoCount: 0),
            .recordSummary
        )
        XCTAssertEqual(
            WeeklyShareCardTemplateCapabilityPolicy.recommended(photoCount: 1),
            .singleMemory
        )
        XCTAssertEqual(
            WeeklyShareCardTemplateCapabilityPolicy.recommended(photoCount: 2),
            .weeklyCollage
        )
        XCTAssertEqual(
            WeeklyShareCardTemplateCapabilityPolicy.recommended(photoCount: 8),
            .weeklyCollage
        )
    }

    func testEveryAvailablePhotoCountGetsThreeSafeBuiltInLayouts() {
        XCTAssertEqual(
            WeeklyShareCardTemplateCapabilityPolicy.allowed(photoCount: 0),
            [.recordSummary, .recordJournal, .recordMagazine]
        )
        XCTAssertEqual(
            WeeklyShareCardTemplateCapabilityPolicy.allowed(photoCount: 1),
            [.singleMemory, .recordJournal, .recordSummary]
        )
        XCTAssertEqual(
            WeeklyShareCardTemplateCapabilityPolicy.allowed(photoCount: 3),
            [.weeklyCollage, .recordMagazine, .recordSummary]
        )
        XCTAssertEqual(WeeklyShareCardTemplateCapabilityPolicy.allowed(photoCount: 2).count, 3)
        XCTAssertEqual(WeeklyShareCardTemplateCapabilityPolicy.allowed(photoCount: 8).count, 3)
    }

    func testSensitivePhotoCaptionsStayCategoryNeutralInTheShareCard() {
        let healthAnchor = SummaryMemoryAnchor(
            id: UUID(),
            itemID: UUID(),
            title: "某医院复诊",
            amount: 100,
            createdAt: Date(),
            imageData: Data(),
            imageReference: nil,
            imageByteCount: nil,
            role: .careRecord,
            sceneHint: .healthRecord,
            label: "健康",
            caption: "具体检查结果"
        )
        let careAnchor = SummaryMemoryAnchor(
            id: UUID(),
            itemID: UUID(),
            title: "家人用药",
            amount: 30,
            createdAt: Date(),
            imageData: Data(),
            imageReference: nil,
            imageByteCount: nil,
            role: .careRecord,
            sceneHint: .careRecord,
            label: "照护",
            caption: "具体用药内容"
        )

        XCTAssertEqual(
            lifeSliceSafeSharePhotoCaption(for: healthAnchor, fallback: "记录"),
            "一条健康记录"
        )
        XCTAssertEqual(
            lifeSliceSafeSharePhotoCaption(for: careAnchor, fallback: "记录"),
            "一条照护记录"
        )
    }
}

#if canImport(UIKit)
final class ShareBackgroundDecodedImageTests: XCTestCase {
    func testNormalizedShareBackgroundReturnsDataAndReusableDecodedImage() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 40), format: format)
        let source = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 40))
        }
        let sourceData = source.pngData()!

        guard let normalized = normalizedShareBackground(sourceData) else {
            XCTFail("Expected normalized background")
            return
        }

        XCTAssertFalse(normalized.data.isEmpty)
        XCTAssertEqual(normalized.image.size.width, 80, accuracy: 0.5)
        XCTAssertEqual(normalized.image.size.height, 40, accuracy: 0.5)
    }

    func testNormalizedShareBackgroundDownsamplesLargeImageOnce() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1000), format: format)
        let source = renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2000, height: 1000))
        }
        let sourceData = source.jpegData(compressionQuality: 0.9)!

        guard let normalized = normalizedShareBackground(sourceData) else {
            XCTFail("Expected downsampled background")
            return
        }

        XCTAssertEqual(normalized.image.size.width, 1600, accuracy: 1)
        XCTAssertEqual(normalized.image.size.height, 800, accuracy: 1)
        XCTAssertNotNil(UIImage(data: normalized.data))
    }
}
#endif

final class InsightBackgroundComputationTests: XCTestCase {
    private func makeItems(count: Int, now: Date) -> [HomeItem] {
        let categories = HomeItem.Category.allCases
        return (0..<count).map { index in
            let idText = String(format: "00000000-0000-0000-0000-%012X", index + 1)
            let category = categories[index % categories.count]
            return HomeItem(
                id: UUID(uuidString: idText)!,
                title: index % 4 == 0 ? "工作日午餐" : category.defaultRecordTitle,
                amount: Double((index % 97) + 1) + Double(index % 3) * 0.5,
                category: category,
                createdAt: now.addingTimeInterval(TimeInterval(-index * 3 * 60 * 60)),
                updatedAt: now.addingTimeInterval(TimeInterval(-index * 2 * 60 * 60)),
                userEditedTitle: index % 4 == 0
            )
        }
    }

    func testThousandRecordReviewAndAIComputationAreDeterministic() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let items = makeItems(count: 1_000, now: now)
        let input = InsightComputationInput(items: items, isMember: true, now: now)

        let firstSnapshot = InsightComputationService.weeklyPageSnapshot(input)
        let secondSnapshot = InsightComputationService.weeklyPageSnapshot(input)
        XCTAssertEqual(firstSnapshot.journalText, secondSnapshot.journalText)
        XCTAssertEqual(firstSnapshot.journalClosing, secondSnapshot.journalClosing)
        XCTAssertEqual(firstSnapshot.rhythmText, secondSnapshot.rhythmText)
        XCTAssertEqual(firstSnapshot.keywords, secondSnapshot.keywords)
        XCTAssertEqual(firstSnapshot.reviewOverview, secondSnapshot.reviewOverview)

        let firstDigest = InsightWebView.aiCommandComputationDigestForTesting(
            command: "最近 90 天餐饮花了多少",
            items: items,
            hasMemberAccess: true,
            now: now
        )
        let secondDigest = InsightWebView.aiCommandComputationDigestForTesting(
            command: "最近 90 天餐饮花了多少",
            items: items,
            hasMemberAccess: true,
            now: now
        )
        XCTAssertEqual(firstDigest, secondDigest)
        XCTAssertFalse(firstDigest.isEmpty)
    }

    func testLatestAIRequestGateNeverAcceptsOlderCompletion() {
        var gate = LatestRequestGate()
        let earlier = gate.begin()
        let latest = gate.begin()

        XCTAssertFalse(gate.accepts(earlier))
        XCTAssertTrue(gate.accepts(latest))

        gate.invalidate()
        XCTAssertFalse(gate.accepts(latest))
    }

    func testSnapshotPublicationAndPreparedQuestionRotationRejectStaleWork() {
        XCTAssertTrue(
            LedgerSnapshotPublicationPolicy.accepts(
                preparedRevision: 18,
                currentRevision: 18
            )
        )
        XCTAssertFalse(
            LedgerSnapshotPublicationPolicy.accepts(
                preparedRevision: 17,
                currentRevision: 18
            )
        )

        let questions = ["第一问", "第二问", "第三问"]
        XCTAssertEqual(
            TraceInsightQuestionFocusPolicy.nextQuestion(in: questions, after: nil),
            "第一问"
        )
        XCTAssertEqual(
            TraceInsightQuestionFocusPolicy.nextQuestion(in: questions, after: "第一问"),
            "第二问"
        )
        XCTAssertEqual(
            TraceInsightQuestionFocusPolicy.nextQuestion(in: questions, after: "第三问"),
            "第一问"
        )
        XCTAssertNil(TraceInsightQuestionFocusPolicy.nextQuestion(in: [], after: nil))
    }

    func testWeeklyShareExportPreparesImmutableSessionBeforeRendering() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let result = WeeklyShareExportPreparationComputation.build(
            WeeklyShareExportPreparationInput(
                items: makeItems(count: 8, now: now),
                sourceRevision: 91,
                now: now,
                paletteID: .quietCream
            )
        )

        guard case let .ready(sourceRevision, session) = result else {
            XCTFail("Expected a prepared weekly share session")
            return
        }
        XCTAssertEqual(sourceRevision, 91)
        XCTAssertEqual(session.identity.sourceRevision, 91)
    }

    func testReviewOverviewMakesCurrentAndPreviousSevenDaysDirectlyComparable() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 12
        ))!
        func date(_ day: Int, _ hour: Int) -> Date {
            calendar.date(from: DateComponents(
                timeZone: calendar.timeZone,
                year: 2026,
                month: 7,
                day: day,
                hour: hour
            ))!
        }
        let items = [
            HomeItem(title: "午餐", amount: 10, category: .dining, createdAt: date(13, 12)),
            HomeItem(title: "今天地铁", amount: 20, category: .transport, createdAt: date(16, 8)),
            HomeItem(title: "前七天地铁", amount: 40, category: .transport, createdAt: date(9, 8)),
        ]

        let overview = InsightComputationService.weeklyPageSnapshot(
            InsightComputationInput(items: items, isMember: true, now: now)
        ).reviewOverview

        XCTAssertEqual(overview.currentTotal, 30, accuracy: 0.001)
        XCTAssertEqual(overview.currentCount, 2)
        XCTAssertEqual(overview.previousTotal, 40, accuracy: 0.001)
        XCTAssertEqual(overview.previousCount, 1)
        XCTAssertEqual(overview.amountDelta, -10, accuracy: 0.001)
        XCTAssertEqual(overview.countDelta, 1)
        XCTAssertEqual(overview.activeDayCount, 2)
        XCTAssertEqual(overview.todayCount, 1)
        XCTAssertEqual(overview.topCategoryLabel, HomeItem.Category.transport.rawValue)
        XCTAssertEqual(overview.topCategoryAmount, 20, accuracy: 0.001)
        XCTAssertEqual(overview.days.count, 7)
        XCTAssertEqual(overview.days.last?.label, "今天")
        XCTAssertEqual(overview.days.last?.count, 1)
    }

    func testAICommandSuggestionsPrepareAllTasksFromOneImmutableSnapshot() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 19
        ))!
        func date(_ day: Int, _ hour: Int) -> Date {
            calendar.date(from: DateComponents(
                timeZone: calendar.timeZone,
                year: 2026,
                month: 7,
                day: day,
                hour: hour
            ))!
        }
        let items = [
            HomeItem(title: "今天午餐", amount: 28, category: .dining, createdAt: date(16, 12)),
            HomeItem(title: "昨天晚餐", amount: 32, category: .dining, createdAt: date(15, 18)),
            HomeItem(title: "前七天早餐", amount: 18, category: .dining, createdAt: date(9, 8)),
            HomeItem(
                title: "早高峰地铁",
                amount: 6,
                category: .transport,
                createdAt: date(15, 8),
                memoryContext: HomeItem.MemoryContext(
                    weatherKind: "rain",
                    temperatureCelsius: 25,
                    cityName: nil,
                    semanticPlace: nil
                )
            ),
            HomeItem(title: "晚高峰公交", amount: 4, category: .transport, createdAt: date(14, 18)),
        ]
        let input = AICommandSuggestionPreparationInput(
            items: items,
            isMember: true,
            now: now,
            weatherKind: "rain"
        )

        let first = InsightComputationService.aiCommandSuggestions(input)
        let second = InsightComputationService.aiCommandSuggestions(input)

        XCTAssertEqual(first, second)
        XCTAssertTrue(first.query.contains("上一次雨天通勤是什么时候？"))
        XCTAssertTrue(first.compare.contains("最近 7 天餐饮和前 7 天比呢？"))
        XCTAssertTrue(first.backfill.contains("补记过去一周工作日通勤，早晚各一次"))
        XCTAssertLessThanOrEqual(first.query.count, 3)
        XCTAssertLessThanOrEqual(first.compare.count, 3)
        XCTAssertLessThanOrEqual(first.backfill.count, 3)
    }

    func testAICommandSuggestionFallbacksStayNeutralAndAllowNoBackfill() {
        let forbiddenAssumptions = ["通勤", "上班", "交通", "餐饮", "兴趣", "爱好"]
        for task in [ReviewTaskIntent.query, ReviewTaskIntent.compare] {
            let fallbacks = AICommandSuggestionSnapshot.fallbacks(for: task)
            XCTAssertFalse(fallbacks.isEmpty)
            XCTAssertLessThanOrEqual(fallbacks.count, 3)
            for fallback in fallbacks {
                XCTAssertFalse(
                    forbiddenAssumptions.contains(where: { fallback.contains($0) }),
                    "Unexpected lifestyle assumption in fallback: \(fallback)"
                )
            }
        }
        XCTAssertTrue(AICommandSuggestionSnapshot.fallbacks(for: .backfill).isEmpty)
    }

    func testEmptyAndParkingOnlyLedgersDoNotInventCommuteRecommendations() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 19
        ))!
        let inputs = [
            AICommandSuggestionPreparationInput(
                items: [],
                isMember: true,
                now: now,
                weatherKind: "rain"
            ),
            AICommandSuggestionPreparationInput(
                items: [
                    HomeItem(
                        title: "停车费",
                        amount: 6,
                        category: .transport,
                        createdAt: now.addingTimeInterval(-3_600)
                    )
                ],
                isMember: true,
                now: now,
                weatherKind: "rain"
            )
        ]

        for input in inputs {
            let snapshot = InsightComputationService.aiCommandSuggestions(input)
            XCTAssertTrue(snapshot.backfill.isEmpty)
            XCTAssertFalse(snapshot.query.contains(where: { $0.contains("雨天通勤") }))
            XCTAssertFalse(snapshot.compare.contains(where: {
                $0.contains("交通") || $0.contains("通勤")
            }))
        }
    }

    func testRepeatedRealCategoryEvidenceProducesFocusedSuggestionsOnly() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 19
        ))!
        func date(_ day: Int, _ hour: Int) -> Date {
            calendar.date(from: DateComponents(
                timeZone: calendar.timeZone,
                year: 2026,
                month: 7,
                day: day,
                hour: hour
            ))!
        }
        let snapshot = InsightComputationService.aiCommandSuggestions(
            AICommandSuggestionPreparationInput(
                items: [
                    HomeItem(title: "午餐", amount: 30, category: .dining, createdAt: date(16, 12)),
                    HomeItem(title: "晚餐", amount: 24, category: .dining, createdAt: date(15, 18)),
                    HomeItem(title: "前七天早餐", amount: 16, category: .dining, createdAt: date(9, 8)),
                ],
                isMember: true,
                now: now,
                weatherKind: nil
            )
        )

        XCTAssertTrue(snapshot.query.contains("看看最近 7 天餐饮记录"))
        XCTAssertTrue(snapshot.compare.contains("最近 7 天餐饮和前 7 天比呢？"))
        XCTAssertFalse(snapshot.compare.contains(where: {
            $0.contains("交通") || $0.contains("通勤")
        }))
        XCTAssertTrue(snapshot.backfill.isEmpty)
    }

    func testStrongCommuteEvidenceNeedsTwoDatesBeforeSuggestingBackfill() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 19
        ))!
        func date(_ day: Int, _ hour: Int) -> Date {
            calendar.date(from: DateComponents(
                timeZone: calendar.timeZone,
                year: 2026,
                month: 7,
                day: day,
                hour: hour
            ))!
        }
        let sameDay = InsightComputationService.aiCommandSuggestions(
            AICommandSuggestionPreparationInput(
                items: [
                    HomeItem(title: "上班地铁", amount: 6, category: .transport, createdAt: date(15, 8)),
                    HomeItem(title: "下班公交", amount: 5, category: .transport, createdAt: date(15, 18)),
                ],
                isMember: true,
                now: now,
                weatherKind: nil
            )
        )
        let twoDates = InsightComputationService.aiCommandSuggestions(
            AICommandSuggestionPreparationInput(
                items: [
                    HomeItem(title: "上班地铁", amount: 6, category: .transport, createdAt: date(15, 8)),
                    HomeItem(title: "晚高峰公交", amount: 5, category: .transport, createdAt: date(14, 18)),
                ],
                isMember: true,
                now: now,
                weatherKind: nil
            )
        )

        XCTAssertTrue(sameDay.backfill.isEmpty)
        XCTAssertEqual(twoDates.backfill, ["补记过去一周工作日通勤，早晚各一次"])
    }

    func testCurrentRainNeedsAnActualHistoricalRainyCommuteForLookup() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 19
        ))!
        let dryCommute = HomeItem(
            title: "上班地铁",
            amount: 6,
            category: .transport,
            createdAt: now.addingTimeInterval(-86_400)
        )
        let snapshot = InsightComputationService.aiCommandSuggestions(
            AICommandSuggestionPreparationInput(
                items: [dryCommute],
                isMember: true,
                now: now,
                weatherKind: "rain"
            )
        )

        XCTAssertFalse(snapshot.query.contains("上一次雨天通勤是什么时候？"))
    }

    func testAICommandComparisonKeepsBothPeriodsAndCategoryChanges() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 12
        ))!
        func date(_ day: Int, _ hour: Int) -> Date {
            calendar.date(from: DateComponents(
                timeZone: calendar.timeZone,
                year: 2026,
                month: 7,
                day: day,
                hour: hour
            ))!
        }
        let items = [
            HomeItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                title: "本周午餐",
                amount: 10,
                category: .dining,
                createdAt: date(13, 12)
            ),
            HomeItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
                title: "本周地铁",
                amount: 20,
                category: .transport,
                createdAt: date(14, 8)
            ),
            HomeItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
                title: "上周午餐",
                amount: 30,
                category: .dining,
                createdAt: date(6, 12)
            ),
            HomeItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
                title: "上周日用",
                amount: 20,
                category: .shopping,
                createdAt: date(7, 18)
            ),
        ]

        let digest = InsightWebView.aiCommandComputationDigestForTesting(
            command: "对比本周和上周的消费",
            items: items,
            hasMemberAccess: true,
            now: now
        )

        XCTAssertTrue(digest.hasPrefix("compare#本周 对比 上周同期#"))
        XCTAssertTrue(digest.contains("本周:30.0:2"))
        XCTAssertTrue(digest.contains("上周同期:50.0:2"))
        XCTAssertTrue(digest.contains("餐饮:10.0:30.0:1:1"))
        XCTAssertTrue(digest.contains("00000000-0000-0000-0000-000000000201"))
    }

    func testOmittedComparisonSubjectDefaultsToTheCurrentWeekOrMonth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 12
        ))!

        func digest(_ command: String) -> String {
            InsightWebView.aiCommandComputationDigestForTesting(
                command: command,
                items: [],
                hasMemberAccess: true,
                now: now,
                reviewTaskIntent: .compare
            )
        }

        for command in ["对比上周", "和上周比", "比比上周", "这周对比上周"] {
            XCTAssertTrue(digest(command).hasPrefix("compare#本周 对比 上周同期#"), command)
        }
        XCTAssertTrue(digest("对比上月").hasPrefix("compare#本月 对比 上月同期#"))
        XCTAssertTrue(digest("本月对比上月").hasPrefix("compare#本月 对比 上月同期#"))
    }

    func testExplicitHistoricalComparisonAndHistoricalQueryKeepTheirLiteralPeriods() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 12
        ))!

        func digest(_ command: String, task: ReviewTaskIntent = .compare) -> String {
            InsightWebView.aiCommandComputationDigestForTesting(
                command: command,
                items: [],
                hasMemberAccess: true,
                now: now,
                reviewTaskIntent: task
            )
        }

        XCTAssertTrue(digest("上周对比前一周").hasPrefix("compare#上周 对比 前一周#"))
        XCTAssertTrue(digest("比较上周和前一周").hasPrefix("compare#上周 对比 前一周#"))
        XCTAssertTrue(digest("上月对比前一个月").hasPrefix("compare#上个月 对比 前一个月#"))
        XCTAssertTrue(digest("查上周记录", task: .query).hasPrefix("query#"))
        XCTAssertTrue(digest("查上月记录", task: .query).hasPrefix("query#"))
    }

    func testRollingSevenDayComparisonCommandUsesThePreviousSevenDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 12
        ))!
        func date(_ day: Int, _ hour: Int) -> Date {
            calendar.date(from: DateComponents(
                timeZone: calendar.timeZone,
                year: 2026,
                month: 7,
                day: day,
                hour: hour
            ))!
        }
        let digest = InsightWebView.aiCommandComputationDigestForTesting(
            command: "对比最近 7 天和前 7 天的消费",
            items: [
                HomeItem(title: "最近午餐", amount: 20, category: .dining, createdAt: date(16, 12)),
                HomeItem(title: "前段午餐", amount: 10, category: .dining, createdAt: date(9, 12)),
            ],
            hasMemberAccess: true,
            now: now,
            reviewTaskIntent: .compare
        )

        XCTAssertTrue(digest.hasPrefix("compare#最近 7 天 对比 前 7 天#"))
        XCTAssertTrue(digest.contains("最近 7 天:20.0:1"))
        XCTAssertTrue(digest.contains("前 7 天:10.0:1"))
    }

    func testUnsupportedAICommandDoesNotInventFactsOutsideTheLedger() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let items = [
            HomeItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                title: "午餐",
                amount: 28,
                category: .dining,
                createdAt: now
            )
        ]
        let digest = InsightWebView.aiCommandComputationDigestForTesting(
            command: "告诉我老板今天心情怎么样",
            items: items,
            hasMemberAccess: true,
            now: now
        )

        XCTAssertTrue(digest.hasPrefix("unsupported#"))
        XCTAssertFalse(digest.contains("老板今天"))
        XCTAssertFalse(digest.contains("心情很好"))
    }
}

final class AICommandRecognitionPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func digest(_ command: String) -> String {
        InsightWebView.aiCommandRecognitionDigestForTesting(command: command, now: now)
    }

    func testNaturalQueryExpressionsShareTheSameSupportedIntent() {
        let weekDining = digest("这礼拜吃饭用了多少")
        let recentTransport = digest("最近坐车花销")
        let recentCoffee = digest("前仨月咖啡花费")

        XCTAssertTrue(weekDining.hasPrefix("query#"))
        XCTAssertTrue(weekDining.contains("#餐饮#"))
        XCTAssertTrue(recentTransport.hasPrefix("query#"))
        XCTAssertTrue(recentTransport.contains("#交通#"))
        XCTAssertTrue(recentCoffee.hasPrefix("query#"))
        XCTAssertTrue(recentCoffee.contains("前三个月咖啡花费"))
        XCTAssertTrue(recentCoffee.contains("#咖啡#"))
    }

    func testTraditionalChineseAndColloquialTimeAreNormalizedBeforeRecognition() {
        let traditionalQuery = digest("這週吃飯花了多少錢？")
        let traditionalCompare = digest("這個月跟上個月差在哪？")

        XCTAssertTrue(traditionalQuery.hasPrefix("query#"))
        XCTAssertTrue(traditionalQuery.contains("这周吃饭花了多少钱"))
        XCTAssertTrue(traditionalQuery.contains("#餐饮#"))
        XCTAssertTrue(traditionalCompare.hasPrefix("compare#"))
        XCTAssertTrue(traditionalCompare.contains("这个月跟上个月差在哪"))
    }

    func testComparisonCanBeImplicitButStillRequiresComparableEvidence() {
        XCTAssertTrue(digest("本月比上月多多少").hasPrefix("compare#"))
        XCTAssertTrue(digest("这个月跟上个月差在哪").hasPrefix("compare#"))
        XCTAssertTrue(digest("今天怎么样").hasPrefix("unsupported#"))
    }

    func testMatchedRollingDayPeriodsResolveCompareFromAQueryTask() {
        let arabic = digest("最近 7 天餐饮和前 7 天比呢")
        let chinese = digest("最近七天餐饮跟前七天相比")

        XCTAssertTrue(arabic.hasPrefix("compare#"))
        XCTAssertTrue(arabic.contains("action:compare"))
        XCTAssertTrue(chinese.hasPrefix("compare#"))
        XCTAssertEqual(
            InsightWebView.aiCommandResolvedReviewTaskForTesting(
                command: "最近 7 天餐饮和前 7 天比呢",
                now: now,
                reviewTaskIntent: .query
            ),
            .compare
        )
    }

    func testFinalRecognitionOwnsTaskStateInsteadOfThePreviousSelection() {
        XCTAssertEqual(
            InsightWebView.aiCommandResolvedReviewTaskForTesting(
                command: "最近 7 天餐饮和前 7 天比呢",
                now: now,
                reviewTaskIntent: .query
            ),
            .compare
        )
        XCTAssertEqual(
            InsightWebView.aiCommandResolvedReviewTaskForTesting(
                command: "查一下最近 7 天餐饮记录",
                now: now,
                reviewTaskIntent: .compare
            ),
            .query
        )
        XCTAssertNil(
            InsightWebView.aiCommandResolvedReviewTaskForTesting(
                command: "老板今天心情怎么样",
                now: now,
                reviewTaskIntent: .compare
            )
        )
        XCTAssertEqual(ReviewTaskIntent.compare.presetCommand, "对比最近 7 天和前 7 天的消费")
    }

    func testRollingDayComparisonUsesCurrentAndImmediatelyPreviousWindows() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let current = HomeItem(
            title: "午餐",
            amount: 20,
            category: .dining,
            createdAt: calendar.date(byAdding: .day, value: -1, to: today)!
        )
        let previous = HomeItem(
            title: "晚餐",
            amount: 10,
            category: .dining,
            createdAt: calendar.date(byAdding: .day, value: -8, to: today)!
        )

        let computation = InsightWebView.aiCommandComputationDigestForTesting(
            command: "最近 7 天餐饮和前 7 天比呢",
            items: [current, previous],
            hasMemberAccess: true,
            now: now,
            reviewTaskIntent: .query
        )

        XCTAssertTrue(computation.hasPrefix("compare#"))
        XCTAssertTrue(computation.contains("最近 7 天"))
        XCTAssertTrue(computation.contains("前 7 天"))
    }

    func testYearPhrasesResolveAsExplicitQueryRanges() {
        XCTAssertTrue(digest("过去一年餐饮花了多少").hasPrefix("query#"))
        XCTAssertTrue(digest("近一年交通记录").hasPrefix("query#"))
        XCTAssertTrue(digest("最近一年购物记录").hasPrefix("query#"))
        XCTAssertTrue(digest("今年餐饮花了多少").hasPrefix("query#"))
        XCTAssertTrue(digest("去年交通花了多少").hasPrefix("query#"))
    }

    func testRollingAndNaturalYearRangesUseTheirOwnCalendarBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Calendar.current.timeZone
        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
            calendar.date(from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour
            ))!
        }

        let now = date(2026, 7, 23)
        let rollingBoundary = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000071")!,
            title: "滚动年边界内",
            amount: 71,
            category: .dining,
            createdAt: date(2025, 7, 24, 0)
        )
        let beforeRollingBoundary = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000072")!,
            title: "滚动年边界外",
            amount: 72,
            category: .dining,
            createdAt: date(2025, 7, 23, 23)
        )
        let currentYear = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000073")!,
            title: "今年第一天",
            amount: 73,
            category: .dining,
            createdAt: date(2026, 1, 1, 0)
        )
        let previousYear = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000074")!,
            title: "去年最后一天",
            amount: 74,
            category: .dining,
            createdAt: date(2025, 12, 31, 23)
        )

        let items = [rollingBoundary, beforeRollingBoundary, currentYear, previousYear]
        let rolling = InsightWebView.aiCommandComputationDigestForTesting(
            command: "过去一年餐饮记录",
            items: items,
            hasMemberAccess: true,
            now: now
        )
        let thisYear = InsightWebView.aiCommandComputationDigestForTesting(
            command: "今年餐饮记录",
            items: items,
            hasMemberAccess: true,
            now: now
        )
        let lastYear = InsightWebView.aiCommandComputationDigestForTesting(
            command: "去年餐饮记录",
            items: items,
            hasMemberAccess: true,
            now: now
        )

        XCTAssertTrue(rolling.hasPrefix("query#最近一年的餐饮记录#"))
        XCTAssertTrue(rolling.contains(rollingBoundary.id.uuidString))
        XCTAssertFalse(rolling.contains(beforeRollingBoundary.id.uuidString))
        XCTAssertTrue(thisYear.hasPrefix("query#今年的餐饮记录#"))
        XCTAssertTrue(thisYear.contains(currentYear.id.uuidString))
        XCTAssertFalse(thisYear.contains(previousYear.id.uuidString))
        XCTAssertTrue(lastYear.hasPrefix("query#去年的餐饮记录#"))
        XCTAssertTrue(lastYear.contains(previousYear.id.uuidString))
        XCTAssertFalse(lastYear.contains(currentYear.id.uuidString))
    }

    func testBackfillRequiresStrongAffirmativeWriteLanguage() {
        XCTAssertTrue(digest("补上昨天上下班通勤").hasPrefix("commuteDraft#"))
        XCTAssertTrue(digest("昨天通勤花了多少").hasPrefix("query#"))

        let negated = digest("不要补记今天通勤")
        XCTAssertTrue(negated.hasPrefix("unsupported#"))
        XCTAssertTrue(negated.contains("guard:negatedWrite"))
        let negatedResult = InsightWebView.aiCommandComputationDigestForTesting(
            command: "不要补记今天通勤",
            items: [],
            hasMemberAccess: true,
            amountText: "10",
            now: now
        )
        XCTAssertTrue(negatedResult.hasPrefix("unsupported#"))
        XCTAssertFalse(negatedResult.contains("早高峰"))
        XCTAssertFalse(negatedResult.contains("晚高峰"))

        let genericGeneration = digest("生成今天通勤")
        XCTAssertTrue(genericGeneration.hasPrefix("unsupported#"))
        XCTAssertTrue(genericGeneration.contains("guard:unsupportedWrite"))

        XCTAssertTrue(digest("生成一份今天通勤统计").hasPrefix("query#"))
        XCTAssertTrue(digest("不要补记，查一下今天通勤花了多少").hasPrefix("query#"))
        XCTAssertTrue(digest("减少这周餐饮记录").hasPrefix("unsupported#"))
        XCTAssertTrue(digest("这周餐饮减少了多少").hasPrefix("compare#"))
    }

    func testSubjectiveAndOutsideLedgerQuestionsDoNotBorrowWeakLedgerWords() {
        let transportOpinion = digest("交通不错吗")
        let bossState = digest("老板今天怎么样")
        let causalGuess = digest("为什么这个月比上个月多")

        XCTAssertTrue(transportOpinion.hasPrefix("unsupported#"))
        XCTAssertTrue(transportOpinion.contains("guard:subjective"))
        XCTAssertTrue(bossState.hasPrefix("unsupported#"))
        XCTAssertTrue(bossState.contains("guard:outsideSubject"))
        XCTAssertTrue(causalGuess.hasPrefix("unsupported#"))
        XCTAssertTrue(causalGuess.contains("guard:subjective"))
    }

    func testIntentPriorityKeepsReadOnlyTasksDistinct() {
        XCTAssertTrue(digest("查一下本周有没有重复账单").hasPrefix("duplicateCheck#"))
        XCTAssertTrue(digest("这月最贵的一笔").hasPrefix("largestRecord#"))
        XCTAssertTrue(digest("本月比上月多多少").hasPrefix("compare#"))
        XCTAssertTrue(digest("上次买可乐是哪天").hasPrefix("lastRecordLookup#"))
        XCTAssertTrue(digest("这周打车是哪天").hasPrefix("query#"))
        XCTAssertTrue(digest("这个月消费怎么样").hasPrefix("lifestyleSummary#"))
    }
}

final class AICommandTrustedSemanticFacetTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 18,
            hour: 20
        ))!
    }

    private func date(_ hour: Int) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 18,
            hour: hour
        ))!
    }

    private func recognition(_ command: String, task: ReviewTaskIntent = .query) -> String {
        InsightWebView.aiCommandRecognitionDigestForTesting(
            command: command,
            now: now,
            reviewTaskIntent: task
        )
    }

    func testQueryTaskAcceptsTrustedWeatherCommuteNounPhrases() {
        for command in ["高温通勤", "热天通勤", "酷热天上班"] {
            let digest = recognition(command)
            XCTAssertTrue(digest.hasPrefix("query#"), command)
            XCTAssertTrue(digest.contains("#hot_commute#"), command)
            XCTAssertTrue(digest.contains("action:nounQuery"), command)
        }

        XCTAssertTrue(recognition("冷天通勤").contains("#cold_commute#"))
        XCTAssertTrue(recognition("雨天通勤").contains("#rainy_commute#"))
        XCTAssertTrue(recognition("雪天通勤").contains("#snowy_commute#"))
    }

    func testBackfillTaskDoesNotTurnTheSameNounPhraseIntoAWrite() {
        XCTAssertTrue(recognition("高温通勤", task: .backfill).hasPrefix("unsupported#"))
        XCTAssertTrue(recognition("爱好类消费", task: .backfill).hasPrefix("unsupported#"))
        XCTAssertTrue(recognition("补记高温通勤", task: .backfill).hasPrefix("commuteDraft#"))
    }

    func testHotCommuteRequiresBothStructuredWeatherAndCommuteEvidence() {
        let hotCommute = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000401")!,
            title: "上班",
            amount: 4.75,
            category: .transport,
            createdAt: date(13),
            memoryContext: .init(weatherKind: "hot", temperatureCelsius: 34, cityName: nil, semanticPlace: nil),
            scenePackId: "commute"
        )
        let hotDining = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000402")!,
            title: "午饭",
            amount: 28,
            category: .dining,
            createdAt: date(12),
            memoryContext: .init(weatherKind: "hot", temperatureCelsius: 34, cityName: nil, semanticPlace: nil)
        )
        let normalCommute = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000403")!,
            title: "下班",
            amount: 4.75,
            category: .transport,
            createdAt: date(18),
            memoryContext: .init(weatherKind: "clear", temperatureCelsius: 25, cityName: nil, semanticPlace: nil),
            scenePackId: "commute"
        )
        let hotTaxi = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000404")!,
            title: "机场打车",
            amount: 58,
            category: .transport,
            createdAt: date(15),
            memoryContext: .init(weatherKind: "hot", temperatureCelsius: 34, cityName: nil, semanticPlace: nil)
        )

        let digest = InsightWebView.aiCommandComputationDigestForTesting(
            command: "高温通勤",
            items: [hotCommute, hotDining, normalCommute, hotTaxi],
            hasMemberAccess: true,
            now: now
        )

        XCTAssertTrue(digest.hasPrefix("query#"))
        XCTAssertTrue(digest.contains(hotCommute.id.uuidString))
        XCTAssertFalse(digest.contains(hotDining.id.uuidString))
        XCTAssertFalse(digest.contains(normalCommute.id.uuidString))
        XCTAssertFalse(digest.contains(hotTaxi.id.uuidString))
        XCTAssertTrue(digest.contains("匹配维度：高温天气 · 通勤"))
    }

    func testInterestConsumptionRequiresAConcreteInterestObjectOrActivity() {
        let fishing = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000411")!,
            title: "路亚鱼竿",
            amount: 268,
            category: .shopping,
            createdAt: date(10)
        )
        let ordinaryShopping = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000412")!,
            title: "日常外套",
            amount: 268,
            category: .shopping,
            createdAt: date(11),
            emotionTag: "爱好里的小投入"
        )

        let digest = InsightWebView.aiCommandComputationDigestForTesting(
            command: "爱好类消费",
            items: [fishing, ordinaryShopping],
            hasMemberAccess: true,
            now: now
        )

        XCTAssertTrue(digest.hasPrefix("query#"))
        XCTAssertTrue(digest.contains(fishing.id.uuidString))
        XCTAssertFalse(digest.contains(ordinaryShopping.id.uuidString))
        XCTAssertTrue(digest.contains("明确兴趣物件或活动"))
    }

    func testWeakEmotionAndValuePhrasesRemainOutsideLedgerFactQueries() {
        for command in ["辛苦了", "热天辛苦", "今天很热吗", "小投入", "爱好值得吗", "买这个划算吗"] {
            XCTAssertTrue(recognition(command).hasPrefix("unsupported#"), command)
        }
    }

    func testRecognizedFacetWithoutRowsIsNotReportedAsUnrecognized() {
        let digest = InsightWebView.aiCommandComputationDigestForTesting(
            command: "高温通勤",
            items: [],
            hasMemberAccess: true,
            now: now
        )

        XCTAssertTrue(digest.hasPrefix("query#"))
        XCTAssertTrue(digest.contains("已识别为高温天气 · 通勤"))
        XCTAssertTrue(digest.contains("不会用当前天气或暖文案补写历史事实"))
    }

    func testWeatherAndAwayFacetsKeepTheExistingMemberBoundary() {
        let locked = InsightWebView.aiCommandComputationDigestForTesting(
            command: "高温通勤",
            items: [],
            hasMemberAccess: false,
            now: now
        )
        let away = recognition("外地消费")

        XCTAssertTrue(locked.hasPrefix("unsupported#会员可看「高温通勤」"))
        XCTAssertTrue(away.hasPrefix("query#"))
        XCTAssertTrue(away.contains("#away_spending#"))
    }
}

final class AICommandQueryMetricScopeTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 23
        ))!
    }

    private func date(day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: day,
            hour: hour
        ))!
    }

    func testExplicitSingleCategoryUsesAverageAndHighestRecordMetrics() {
        let items = [
            HomeItem(title: "午餐", amount: 12, category: .dining, createdAt: date(day: 16, hour: 12)),
            HomeItem(title: "晚餐", amount: 30, category: .dining, createdAt: date(day: 17, hour: 19)),
            HomeItem(title: "地铁", amount: 8, category: .transport, createdAt: date(day: 17, hour: 8)),
        ]

        let digest = InsightWebView.aiCommandQueryMetricDigestForTesting(
            command: "最近 7 天餐饮记录",
            items: items,
            now: now
        )

        XCTAssertEqual(digest, "single:餐饮#2#21.0#30.0#餐饮#42.0")
    }

    func testUnfilteredQueryKeepsCrossCategoryMetricsEvenWhenResultsContainOneCategory() {
        let items = [
            HomeItem(title: "午餐", amount: 12, category: .dining, createdAt: date(day: 16, hour: 12)),
            HomeItem(title: "晚餐", amount: 30, category: .dining, createdAt: date(day: 17, hour: 19)),
        ]

        let digest = InsightWebView.aiCommandQueryMetricDigestForTesting(
            command: "最近 7 天记录",
            items: items,
            now: now
        )

        XCTAssertEqual(digest, "cross#2#21.0#30.0#餐饮#42.0")
    }

    func testSingleCategoryEmptyAndOneRecordBoundariesStayExplicit() {
        let empty = InsightWebView.aiCommandQueryMetricDigestForTesting(
            command: "最近 7 天餐饮记录",
            items: [],
            now: now
        )
        let one = InsightWebView.aiCommandQueryMetricDigestForTesting(
            command: "最近 7 天餐饮记录",
            items: [
                HomeItem(title: "午餐", amount: 18, category: .dining, createdAt: date(day: 17, hour: 12))
            ],
            now: now
        )

        XCTAssertEqual(empty, "single:餐饮#0#none#none#none#0.0")
        XCTAssertEqual(one, "single:餐饮#1#18.0#18.0#餐饮#18.0")
    }

    func testSingleCategoryLifeMarkUsesFocusedMetricsWithoutRepeatingBaseCategory() {
        let items = [
            HomeItem(title: "瑞幸咖啡", amount: 9.9, category: .dining, createdAt: date(day: 16, hour: 17)),
            HomeItem(title: "冰美式", amount: 9.9, category: .dining, createdAt: date(day: 17, hour: 9)),
            HomeItem(title: "午餐", amount: 28, category: .dining, createdAt: date(day: 17, hour: 12)),
        ]

        let digest = InsightWebView.aiCommandQueryMetricDigestForTesting(
            command: "这周咖啡饮品几次？",
            items: items,
            now: now
        )

        XCTAssertEqual(digest, "single:餐饮#2#9.9#9.9#餐饮#19.8")
    }

    func testMultiCategoryLifeMarkAndExplicitBreakdownKeepCrossCategoryMetrics() {
        let items = [
            HomeItem(title: "运动鞋", amount: 399, category: .shopping, createdAt: date(day: 16, hour: 17)),
            HomeItem(title: "健身房月卡", amount: 299, category: .health, createdAt: date(day: 17, hour: 9)),
            HomeItem(title: "瑞幸咖啡", amount: 9.9, category: .dining, createdAt: date(day: 17, hour: 12)),
        ]

        let multi = InsightWebView.aiCommandQueryMetricDigestForTesting(
            command: "这周健身恢复花了多少？",
            items: items,
            now: now
        )
        let breakdown = InsightWebView.aiCommandQueryMetricDigestForTesting(
            command: "这周咖啡饮品按分类看",
            items: items,
            now: now
        )

        XCTAssertTrue(multi.hasPrefix("cross#"))
        XCTAssertTrue(breakdown.hasPrefix("cross#"))
    }
}

final class AICommandDailyBarWindowPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func date(year: Int = 2026, month: Int, day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testWindowFollowsMatchedRecordsInsteadOfQueryEnd() {
        let dates = AICommandDailyBarWindowPolicy.dates(
            rangeStart: date(month: 8, day: 9, hour: 0),
            rangeEnd: date(month: 9, day: 9, hour: 0),
            requestedDays: 31,
            itemDates: [date(month: 8, day: 21), date(month: 8, day: 23)],
            calendar: calendar
        )

        XCTAssertEqual(dates.count, 7)
        XCTAssertEqual(dates.first, date(month: 8, day: 17, hour: 0))
        XCTAssertEqual(dates.last, date(month: 8, day: 23, hour: 0))
        XCTAssertFalse(dates.contains(date(month: 9, day: 2, hour: 0)))
    }

    func testWindowStaysInsideShortRangeAndPreservesEmptyFallback() {
        let shortRange = AICommandDailyBarWindowPolicy.dates(
            rangeStart: date(month: 8, day: 20, hour: 0),
            rangeEnd: date(month: 8, day: 24, hour: 0),
            requestedDays: 7,
            itemDates: [date(month: 8, day: 21)],
            calendar: calendar
        )
        XCTAssertEqual(shortRange.map { calendar.component(.day, from: $0) }, [20, 21, 22, 23])

        let empty = AICommandDailyBarWindowPolicy.dates(
            rangeStart: date(month: 8, day: 9, hour: 0),
            rangeEnd: date(month: 9, day: 9, hour: 0),
            requestedDays: 31,
            itemDates: [],
            calendar: calendar
        )
        XCTAssertEqual(empty.first, date(month: 9, day: 2, hour: 0))
        XCTAssertEqual(empty.last, date(month: 9, day: 8, hour: 0))
    }
}

final class AICommandComparisonPresentationPolicyTests: XCTestCase {
    func testChangeKindsUseExistingAmountsAndCountsWithoutFuzzyPairing() {
        XCTAssertEqual(
            AICommandComparisonPresentationPolicy.changeKind(
                currentAmount: 0,
                previousAmount: 96,
                currentCount: 0,
                previousCount: 3
            ),
            .disappeared
        )
        XCTAssertEqual(
            AICommandComparisonPresentationPolicy.changeKind(
                currentAmount: 32,
                previousAmount: 0,
                currentCount: 2,
                previousCount: 0
            ),
            .appeared
        )
        XCTAssertEqual(
            AICommandComparisonPresentationPolicy.changeKind(
                currentAmount: 40,
                previousAmount: 20,
                currentCount: 4,
                previousCount: 2
            ),
            .increased
        )
        XCTAssertEqual(
            AICommandComparisonPresentationPolicy.changeKind(
                currentAmount: 20,
                previousAmount: 40,
                currentCount: 2,
                previousCount: 4
            ),
            .decreased
        )
        XCTAssertEqual(
            AICommandComparisonPresentationPolicy.changeKind(
                currentAmount: 33.25,
                previousAmount: 33.25,
                currentCount: 7,
                previousCount: 7
            ),
            .steady
        )
    }

    func testChangeShareUsesAbsoluteCategoryMovementInsteadOfNetDifference() {
        XCTAssertEqual(
            AICommandComparisonPresentationPolicy.changeSharePercent(
                delta: -96,
                categoryDeltas: [-96, -18.82, 0]
            ),
            84
        )
        XCTAssertEqual(
            AICommandComparisonPresentationPolicy.changeSharePercent(
                delta: 100,
                categoryDeltas: [100, -100]
            ),
            50
        )
        XCTAssertEqual(
            AICommandComparisonPresentationPolicy.changeSharePercent(
                delta: 0,
                categoryDeltas: [0, 0]
            ),
            0
        )
    }
}

final class MembershipQuotaBoundaryTests: XCTestCase {
    func testDisplaySimplificationDoesNotChangeExistingQuotaConstants() {
        XCTAssertEqual(MembershipQuotaBaseline.todayPlaybackDaily, 3)
        XCTAssertEqual(MembershipQuotaBaseline.ocrDaily, 3)
        XCTAssertEqual(MembershipQuotaBaseline.weeklyJournal, 3)
        XCTAssertEqual(MembershipQuotaBaseline.lifetimeMonthChapter, 10)
        XCTAssertEqual(MembershipQuotaBaseline.monthlyLifeClue, 5)
        XCTAssertEqual(MembershipQuotaBaseline.monthlyInsightTrialTotal, 5)
    }
}

final class AccessibilityLayoutPolicyTests: XCTestCase {
    func testCoreTapTargetNeverDropsBelowFortyFourPoints() {
        XCTAssertGreaterThanOrEqual(AccessibilityLayoutPolicy.minimumTapTarget, 44)
    }

    func testPrimaryActionsStackForAccessibilityTextOrNarrowWidths() {
        XCTAssertTrue(
            AccessibilityLayoutPolicy.shouldStackPrimaryActions(
                isAccessibilityTextSize: true,
                availableWidth: 390,
                actionCount: 2
            )
        )
        XCTAssertTrue(
            AccessibilityLayoutPolicy.shouldStackPrimaryActions(
                isAccessibilityTextSize: false,
                availableWidth: 240,
                actionCount: 2
            )
        )
        XCTAssertFalse(
            AccessibilityLayoutPolicy.shouldStackPrimaryActions(
                isAccessibilityTextSize: false,
                availableWidth: 390,
                actionCount: 2
            )
        )
    }

    func testReduceMotionDisablesDecorativeMotion() {
        XCTAssertFalse(AccessibilityLayoutPolicy.allowsDecorativeMotion(reduceMotion: true))
        XCTAssertTrue(AccessibilityLayoutPolicy.allowsDecorativeMotion(reduceMotion: false))
    }

    func testReadableTextOpacityFloorRemainsLegible() {
        XCTAssertGreaterThanOrEqual(AccessibilityLayoutPolicy.minimumReadableTextOpacity, 0.72)
    }
}

@MainActor
final class DarkModeReadabilityPolicyTests: XCTestCase {
    func testDarkModeHighlightOpacityIsLowerThanLight() {
        XCTAssertEqual(
            AppColors.highlightOpacity(isDarkMode: false, light: 0.48, dark: 0.10),
            0.48
        )
        XCTAssertEqual(
            AppColors.highlightOpacity(isDarkMode: true, light: 0.48, dark: 0.10),
            0.10
        )
    }

    func testPrimaryAccentActionsUseThemeForeground() {
        let foreground = ResolvedThemeTokens.foregroundToken(
            on: TokenColor("#78AE9E"),
            preferred: TokenColor("#ECF1FF")
        )
        XCTAssertEqual(foreground.hex, "#000000")
        XCTAssertNotEqual(ResolvedThemeTokens.fallback.onAccent, Color.white)
    }

    func testAllThemesFollowingSystemDarkMatchExplicitDark() {
        let resolver = ThemeResolver()
        XCTAssertEqual(resolver.themes.count, 31)
        for theme in resolver.themes {
            let automatic = resolver.resolve(themeId: theme.id, appearance: .system, systemColorScheme: .dark)
            let explicit = resolver.resolve(themeId: theme.id, appearance: .dark, systemColorScheme: .light)
            XCTAssertEqual(automatic.mode, .dark, theme.id)
            assertSameTheme(automatic, explicit)
        }
    }

    func testAllThemesFollowingSystemLightMatchExplicitLight() {
        let resolver = ThemeResolver()
        XCTAssertEqual(resolver.themes.count, 31)
        for theme in resolver.themes {
            let automatic = resolver.resolve(themeId: theme.id, appearance: .system, systemColorScheme: .light)
            let explicit = resolver.resolve(themeId: theme.id, appearance: .light, systemColorScheme: .dark)
            XCTAssertEqual(automatic.mode, .light, theme.id)
            assertSameTheme(automatic, explicit)
        }
    }

    func testExplicitAppearanceIgnoresOppositeSystemScheme() {
        let resolver = ThemeResolver()
        for theme in resolver.themes {
            for appearance in [AppSettings.Appearance.light, .dark] {
                assertSameTheme(
                    resolver.resolve(themeId: theme.id, appearance: appearance, systemColorScheme: .light),
                    resolver.resolve(themeId: theme.id, appearance: appearance, systemColorScheme: .dark)
                )
            }
        }
    }

    func testSystemThemeTracksBothSchemeChangesAndIdempotentRefresh() {
        let resolver = ThemeResolver()
        resolver.apply(themeId: ThemeResolver.defaultThemeId, appearance: .system, systemColorScheme: .dark)
        XCTAssertEqual(resolver.colors.mode, .dark)
        withObservationTracking {
            _ = resolver.colors.mode
        } onChange: {
            XCTFail("An unchanged appearance refresh must not republish theme colors.")
        }
        resolver.apply(themeId: ThemeResolver.defaultThemeId, appearance: .system, systemColorScheme: .dark)
        // Use a separate resolver below so the one-shot unchanged-value guard
        // above never observes an intentionally different appearance.
        let changingResolver = ThemeResolver()
        for scheme in [ColorScheme.dark, .light, .dark] {
            changingResolver.apply(themeId: ThemeResolver.defaultThemeId, appearance: .system, systemColorScheme: scheme)
            XCTAssertEqual(changingResolver.colors.mode, scheme == .dark ? .dark : .light)
        }
    }

    func testThemeChangesAndDefaultRestoreKeepSystemDark() {
        let resolver = ThemeResolver()
        for theme in resolver.themes {
            resolver.apply(themeId: theme.id, appearance: .system, systemColorScheme: .dark)
            XCTAssertEqual(resolver.colors.id, theme.id)
            XCTAssertEqual(resolver.colors.mode, .dark)
        }
        resolver.apply(themeId: ThemeResolver.defaultThemeId, appearance: .system, systemColorScheme: .dark)
        XCTAssertEqual(resolver.colors.id, ThemeResolver.defaultThemeId)
        XCTAssertEqual(resolver.colors.mode, .dark)
    }

    func testUnknownThemeFallbackPreservesEffectiveDarkAppearance() {
        let resolver = ThemeResolver()
        assertSameTheme(
            resolver.resolve(themeId: "missing_theme", appearance: .system, systemColorScheme: .dark),
            resolver.resolve(themeId: ThemeResolver.defaultThemeId, appearance: .dark, systemColorScheme: .light)
        )
    }

    func testStaticAppColorReadsRegisterThemeObservation() {
        let resolver = ThemeResolver.shared
        let previous = resolver.colors
        defer {
            resolver.apply(
                themeId: previous.id,
                appearance: previous.mode == .dark ? .dark : .light,
                systemColorScheme: previous.mode == .dark ? .dark : .light
            )
        }
        resolver.apply(themeId: ThemeResolver.defaultThemeId, appearance: .light, systemColorScheme: .light)
        let changed = expectation(description: "AppColors readers observe theme changes without resetting view identity")
        withObservationTracking {
            _ = AppColors.text
            _ = AppColors.isDarkMode
        } onChange: {
            changed.fulfill()
        }
        resolver.apply(themeId: ThemeResolver.defaultThemeId, appearance: .system, systemColorScheme: .dark)
        wait(for: [changed], timeout: 0.1)
        XCTAssertTrue(AppColors.isDarkMode)
    }

    func testDarkHomeTotalPillsAreOpaqueAndReadableForEveryTheme() {
        let resolver = ThemeResolver()
        XCTAssertEqual(resolver.themes.count, 31)
        for theme in resolver.themes {
            let resolved = resolver.resolve(themeId: theme.id, appearance: .system, systemColorScheme: .dark)
            let palette = HomeNarrativePillColors(theme: resolved)
            XCTAssertEqual(palette.background, resolved.surfaceMuted, theme.id)
            XCTAssertEqual(palette.foreground, resolved.textPrimary, theme.id)
            XCTAssertEqual(palette.border, resolved.stroke, theme.id)
#if canImport(UIKit)
            XCTAssertGreaterThanOrEqual(
                opaqueContrastRatio(palette.foreground, palette.background),
                4.5,
                theme.id
            )
#endif
        }
    }

    func testLightHomeTotalPillsKeepOriginalAppearance() {
        let resolver = ThemeResolver()
        for theme in resolver.themes {
            let resolved = resolver.resolve(themeId: theme.id, appearance: .light, systemColorScheme: .dark)
            let palette = HomeNarrativePillColors(theme: resolved)
            XCTAssertEqual(palette.foreground, resolved.textSecondary, theme.id)
            XCTAssertEqual(palette.background, Color.white.opacity(0.58), theme.id)
            XCTAssertEqual(palette.border, Color.white.opacity(0.46), theme.id)
        }
    }

    private func assertSameTheme(_ lhs: ResolvedThemeTokens, _ rhs: ResolvedThemeTokens) {
        XCTAssertEqual(lhs.id, rhs.id)
        XCTAssertEqual(lhs.mode, rhs.mode)
        func colors(_ theme: ResolvedThemeTokens) -> [Color] {
            [
                theme.background, theme.backgroundGradientEnd, theme.surface,
                theme.surfaceWarm, theme.surfaceMuted, theme.stroke,
                theme.textPrimary, theme.textSecondary, theme.textTertiary,
                theme.accent, theme.accentDark, theme.readableAccent, theme.onAccent,
                theme.lockGold, theme.heroGradientPink, theme.heroGradientTeal,
                theme.panel, theme.panelStrong, theme.line, theme.paperWarm,
                theme.paperMist, theme.paperBorder, theme.paperCrease,
                theme.tabActiveBg, theme.tabInactiveBg, theme.tabInactiveGlyph,
                theme.floatingPetPanel, theme.settingsIdentityPanel,
                theme.settingsChapterPanel, theme.tracePlaybackButtonBg,
                theme.traceAppendixBg, theme.monthlyInsightBg,
                theme.settingsEnvelopeIvory, theme.settingsEnvelopeWarm,
                theme.settingsEnvelopeMint, theme.settingsEnvelopeSage,
                theme.settingsEnvelopeDeepSage
            ] + theme.categoryColors
        }
        XCTAssertEqual(colors(lhs), colors(rhs), lhs.id)
    }

#if canImport(UIKit)
    private func opaqueContrastRatio(_ foreground: Color, _ background: Color) -> Double {
        func luminance(_ color: Color) -> Double {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            XCTAssertTrue(UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha))
            XCTAssertEqual(alpha, 1, accuracy: 0.0001)
            func linear(_ value: CGFloat) -> Double {
                let component = Double(value)
                return component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
            }
            return linear(red) * 0.2126 + linear(green) * 0.7152 + linear(blue) * 0.0722
        }
        let first = luminance(foreground)
        let second = luminance(background)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }
#endif
}

final class PixelPetAnimationPolicyTests: XCTestCase {
    func testEachSequenceKeepsEightValidatedFrameDurations() {
        XCTAssertEqual(
            PixelPetAnimationPolicy.durationsMilliseconds(for: .idle),
            [800, 120, 90, 90, 100, 120, 180, 800]
        )
        XCTAssertEqual(
            PixelPetAnimationPolicy.durationsMilliseconds(for: .tap),
            [120, 80, 80, 80, 140, 100, 80, 180]
        )
        XCTAssertEqual(
            PixelPetAnimationPolicy.durationsMilliseconds(for: .speak),
            [160, 90, 90, 90, 110, 90, 100, 240]
        )
    }

    func testNewTapTakesPriorityOverVisibleSpeakingBubble() {
        let plan = PixelPetAnimationPolicy.plan(
            tapPending: true,
            bubbleVisible: true,
            sceneIsActive: true,
            reduceMotion: false,
            lowPowerMode: false
        )

        XCTAssertEqual(plan.sequence, .tap)
        XCTAssertTrue(plan.animates)
    }

    func testConsumedTapFollowsBubbleState() {
        XCTAssertEqual(
            PixelPetAnimationPolicy.followUpSequence(bubbleVisible: true),
            .speak
        )
        XCTAssertEqual(
            PixelPetAnimationPolicy.followUpSequence(bubbleVisible: false),
            .idle
        )
    }

    func testMotionPowerAndSceneBoundariesReturnStaticPlans() {
        let reducedMotion = PixelPetAnimationPolicy.plan(
            tapPending: true,
            bubbleVisible: true,
            sceneIsActive: true,
            reduceMotion: true,
            lowPowerMode: false
        )
        let lowPower = PixelPetAnimationPolicy.plan(
            tapPending: true,
            bubbleVisible: false,
            sceneIsActive: true,
            reduceMotion: false,
            lowPowerMode: true
        )
        let inactive = PixelPetAnimationPolicy.plan(
            tapPending: true,
            bubbleVisible: true,
            sceneIsActive: false,
            reduceMotion: false,
            lowPowerMode: false
        )

        XCTAssertFalse(reducedMotion.animates)
        XCTAssertEqual(reducedMotion.sequence, .speak)
        XCTAssertFalse(lowPower.animates)
        XCTAssertEqual(lowPower.sequence, .idle)
        XCTAssertFalse(inactive.animates)
        XCTAssertEqual(inactive.stableFrameIndex, 0)
    }
}

final class HomePetOverlayPositionPolicyTests: XCTestCase {
    func testDefaultPlacementMatchesTheLegacyLowerRightAnchor() {
        let viewport = CGSize(width: 390, height: 700)

        XCTAssertEqual(HomePetOverlayPlacement.defaultPlacement.side, .right)
        XCTAssertEqual(HomePetOverlayPlacement.defaultPlacement.verticalFraction, 0)
        XCTAssertEqual(
            HomePetOverlayPositionPolicy.bottomInset(
                for: .defaultPlacement,
                viewportHeight: viewport.height
            ),
            102,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            HomePetOverlayPositionPolicy.committedPlacement(
                from: .defaultPlacement,
                translation: .zero,
                viewport: viewport
            ),
            .defaultPlacement
        )
    }

    func testTapJitterDoesNotQualifyAsADrag() {
        XCTAssertFalse(
            HomePetOverlayPositionPolicy.isMeaningfulDrag(CGSize(width: 5, height: 5))
        )
        XCTAssertTrue(
            HomePetOverlayPositionPolicy.isMeaningfulDrag(CGSize(width: 8, height: 1))
        )
    }

    func testDragTranslationTracksViewportSamplesWithoutFeedbackOscillation() {
        let viewport = CGSize(width: 390, height: 700)
        let proposedSamples: [CGSize] = [
            .zero,
            CGSize(width: -24, height: -18),
            CGSize(width: -72, height: -54),
            CGSize(width: -140, height: -110)
        ]
        let resolved = proposedSamples.map {
            HomePetOverlayPositionPolicy.clampedDragTranslation(
                placement: .defaultPlacement,
                proposed: $0,
                viewport: viewport
            )
        }

        XCTAssertEqual(resolved, proposedSamples)
        XCTAssertTrue(zip(resolved, resolved.dropFirst()).allSatisfy { pair in
            let (previous, current) = pair
            return current.width <= previous.width && current.height <= previous.height
        })
    }

    func testDragCommitsToNearestEdgeAndKeepsVerticalPositionInBounds() {
        let viewport = CGSize(width: 390, height: 700)
        let movedLeft = HomePetOverlayPositionPolicy.committedPlacement(
            from: .defaultPlacement,
            translation: CGSize(width: -330, height: -220),
            viewport: viewport
        )
        XCTAssertEqual(movedLeft.side, .left)
        XCTAssertGreaterThan(movedLeft.verticalFraction, 0)
        XCTAssertLessThanOrEqual(movedLeft.verticalFraction, 1)

        let movedRight = HomePetOverlayPositionPolicy.committedPlacement(
            from: movedLeft,
            translation: CGSize(width: 500, height: 900),
            viewport: viewport
        )
        XCTAssertEqual(movedRight.side, .right)
        XCTAssertEqual(movedRight.verticalFraction, 0, accuracy: 0.0001)
    }

    func testStoredPlacementNormalizesCorruptFractionsAndRestoresTheSide() {
        let suiteName = "HomePetOverlayPositionPolicyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        HomePetOverlayPositionStore.save(
            HomePetOverlayPlacement(side: .left, verticalFraction: 4.2),
            defaults: defaults
        )
        let restored = HomePetOverlayPositionStore.load(defaults: defaults)
        XCTAssertEqual(restored.side, .left)
        XCTAssertEqual(restored.verticalFraction, 1, accuracy: 0.0001)
    }

    func testSmallViewportFallsBackWithoutProducingAnInvalidPlacement() {
        let original = HomePetOverlayPlacement(side: .right, verticalFraction: 0.4)
        let result = HomePetOverlayPositionPolicy.committedPlacement(
            from: original,
            translation: CGSize(width: -500, height: -500),
            viewport: CGSize(width: 60, height: 100)
        )
        XCTAssertEqual(result, original)
    }
}

final class PetCompanionMessagePolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 18,
            hour: hour,
            minute: minute
        ))!
    }

    func testClickUsesCommuteAndCoffeeFactsBeforeCurrentRain() {
        let commute = HomeItem(
            title: "上班",
            amount: 4.75,
            category: .transport,
            createdAt: date(13, 48),
            memoryContext: .init(weatherKind: "hot", temperatureCelsius: 34, cityName: nil, semanticPlace: nil),
            scenePackId: "commute"
        )
        let coffee = HomeItem(
            title: "冰美式",
            amount: 9.9,
            category: .dining,
            createdAt: date(17, 32)
        )

        let messages = PetCompanionMessagePolicy.candidates(
            focusRecord: nil,
            todayItems: [commute, coffee],
            currentWeather: WeatherSnapshot(temp: 24, weatherCode: 61, ts: date(20)),
            now: date(20),
            calendar: calendar
        )

        XCTAssertTrue(messages.allSatisfy { $0.text.contains("通勤") })
        XCTAssertTrue(messages.allSatisfy { $0.text.contains("现在外面在下雨") })
        XCTAssertFalse(messages.contains { $0.text.contains("家里") || $0.text.contains("居家") })
    }

    func testSavedRecordUsesItsOwnWeatherInsteadOfCurrentWeather() {
        let commute = HomeItem(
            title: "上班",
            amount: 4.75,
            category: .transport,
            createdAt: date(15),
            memoryContext: .init(weatherKind: "hot", temperatureCelsius: 34, cityName: nil, semanticPlace: nil),
            scenePackId: "commute"
        )

        let messages = PetCompanionMessagePolicy.candidates(
            focusRecord: commute,
            todayItems: [commute],
            currentWeather: WeatherSnapshot(temp: 24, weatherCode: 61, ts: date(20)),
            now: date(20),
            calendar: calendar
        )

        XCTAssertEqual(messages.map(\.text), ["下午这趟通勤是在热天里记下的。"])
    }

    func testSystemWarmTagDoesNotBecomeAClaimAboutTheUser() {
        let item = HomeItem(
            title: "普通记录",
            amount: 12,
            category: .other,
            createdAt: date(12),
            emotionTag: "辛苦了，今天很治愈"
        )

        let messages = PetCompanionMessagePolicy.candidates(
            focusRecord: item,
            todayItems: [item],
            currentWeather: nil,
            now: date(20),
            calendar: calendar
        )

        XCTAssertFalse(messages.contains { $0.text.contains("辛苦") || $0.text.contains("治愈") })
    }

    func testExplicitSafeUserLineRequiresUserEditedTitleAndSensitiveRecordsStayNeutral() {
        let safe = HomeItem(
            title: "终于到家",
            amount: 8,
            category: .transport,
            createdAt: date(22),
            userEditedTitle: true
        )
        let sensitive = HomeItem(
            title: "今天好累",
            amount: 50,
            category: .health,
            createdAt: date(22),
            userEditedTitle: true
        )

        let safeMessage = PetCompanionMessagePolicy.candidates(
            focusRecord: safe,
            todayItems: [safe],
            currentWeather: nil,
            now: date(22),
            calendar: calendar
        )
        let sensitiveMessages = PetCompanionMessagePolicy.candidates(
            focusRecord: sensitive,
            todayItems: [sensitive],
            currentWeather: nil,
            now: date(22),
            calendar: calendar
        )

        XCTAssertEqual(safeMessage.first?.id, "saved.user.arrived_home")
        XCTAssertFalse(sensitiveMessages.contains { $0.text.contains("今天好累") })
    }

    func testZeroOneAndSeveralRecordFallbacksAreDeterministic() {
        let first = HomeItem(title: "午饭", amount: 20, category: .dining, createdAt: date(12))
        let second = HomeItem(title: "纸巾", amount: 12, category: .daily, createdAt: date(18))

        let empty = PetCompanionMessagePolicy.candidates(
            focusRecord: nil,
            todayItems: [],
            currentWeather: nil,
            now: date(12),
            calendar: calendar
        )
        let one = PetCompanionMessagePolicy.candidates(
            focusRecord: nil,
            todayItems: [first],
            currentWeather: nil,
            now: date(12),
            calendar: calendar
        )
        let several = PetCompanionMessagePolicy.candidates(
            focusRecord: nil,
            todayItems: [first, second],
            currentWeather: nil,
            now: date(18),
            calendar: calendar
        )

        XCTAssertTrue(empty.allSatisfy { $0.id.hasPrefix("day.empty") })
        XCTAssertTrue(one.allSatisfy { $0.id.hasPrefix("day.one") })
        XCTAssertTrue(several.allSatisfy { $0.id.hasPrefix("day.several") })
    }

    func testHotWeatherCoffeeAddsCareWithoutCallingCoffeeAColdDrink() {
        let coffee = HomeItem(
            title: "拿铁",
            amount: 18,
            category: .dining,
            createdAt: date(15)
        )

        let messages = PetCompanionMessagePolicy.candidates(
            focusRecord: nil,
            todayItems: [coffee],
            currentWeather: WeatherSnapshot(temp: 34, weatherCode: 1, ts: date(16)),
            now: date(16),
            calendar: calendar
        )

        XCTAssertTrue(messages.allSatisfy { $0.text.contains("咖啡") })
        XCTAssertTrue(messages.allSatisfy { $0.text.contains("防晒") && $0.text.contains("补水") })
        XCTAssertFalse(messages.contains { $0.text.contains("冷饮") || $0.text.contains("清凉") })
    }

    func testHotWeatherOnlyUsesColdDrinkCopyForExplicitDiningEvidence() {
        let coldDrink = HomeItem(
            title: "冰美式",
            amount: 12,
            category: .dining,
            createdAt: date(15)
        )
        let merchandise = HomeItem(
            title: "冰美式随行杯",
            amount: 68,
            category: .shopping,
            createdAt: date(15)
        )
        let weather = WeatherSnapshot(temp: 35, weatherCode: 1, ts: date(16))

        let coldDrinkMessages = PetCompanionMessagePolicy.candidates(
            focusRecord: nil,
            todayItems: [coldDrink],
            currentWeather: weather,
            now: date(16),
            calendar: calendar
        )
        let merchandiseMessages = PetCompanionMessagePolicy.candidates(
            focusRecord: nil,
            todayItems: [merchandise],
            currentWeather: weather,
            now: date(16),
            calendar: calendar
        )

        XCTAssertTrue(coldDrinkMessages.allSatisfy { $0.text.contains("冷饮") })
        XCTAssertFalse(merchandiseMessages.contains { $0.text.contains("冷饮") || $0.text.contains("咖啡") })
    }

    func testSavedSameDayCoffeeCanAddCurrentCareButHistoricalRecordCannot() {
        let todayCoffee = HomeItem(
            title: "咖啡",
            amount: 16,
            category: .dining,
            createdAt: date(15)
        )
        let yesterday = calendar.date(byAdding: .day, value: -1, to: todayCoffee.createdAt)!
        let historicalCoffee = HomeItem(
            title: "咖啡",
            amount: 16,
            category: .dining,
            createdAt: yesterday
        )
        let weather = WeatherSnapshot(temp: 34, weatherCode: 1, ts: date(16))

        let todayMessages = PetCompanionMessagePolicy.candidates(
            focusRecord: todayCoffee,
            todayItems: [todayCoffee],
            currentWeather: weather,
            now: date(16),
            calendar: calendar
        )
        let historicalMessages = PetCompanionMessagePolicy.candidates(
            focusRecord: historicalCoffee,
            todayItems: [],
            currentWeather: weather,
            now: date(16),
            calendar: calendar
        )

        XCTAssertTrue(todayMessages.allSatisfy { $0.text.contains("防晒") && $0.text.contains("补水") })
        XCTAssertTrue(historicalMessages.allSatisfy { !$0.text.contains("防晒") && !$0.text.contains("补水") })
    }

    func testStaleWeatherDoesNotBecomeCurrentCare() {
        let coffee = HomeItem(
            title: "咖啡",
            amount: 16,
            category: .dining,
            createdAt: date(15)
        )
        let staleTimestamp = calendar.date(byAdding: .hour, value: -2, to: date(16))!

        let messages = PetCompanionMessagePolicy.candidates(
            focusRecord: nil,
            todayItems: [coffee],
            currentWeather: WeatherSnapshot(temp: 34, weatherCode: 1, ts: staleTimestamp),
            now: date(16),
            calendar: calendar
        )

        XCTAssertTrue(messages.allSatisfy { $0.id.hasPrefix("day.one") })
        XCTAssertFalse(messages.contains { $0.text.contains("防晒") || $0.text.contains("补水") })
    }

    func testInteractionHintOnlyPresentsBeforeItHasBeenSeen() {
        XCTAssertTrue(PetCompanionInteractionHintPolicy.shouldPresent(hasPresented: false))
        XCTAssertFalse(PetCompanionInteractionHintPolicy.shouldPresent(hasPresented: true))
    }

    func testAutomaticSpeechRequiresAnUnblockedVisibleActiveHome() {
        XCTAssertTrue(PetCompanionAutomaticSpeechPolicy.shouldSchedule(
            isHomeVisible: true,
            isSceneActive: true,
            isPetEnabled: true,
            isPresentationBlocked: false,
            hasBubble: false,
            hasMessageRequest: false,
            hasPendingSavedMessage: false
        ))

        let blockedStates: [(Bool, Bool, Bool, Bool, Bool, Bool, Bool)] = [
            (false, true, true, false, false, false, false),
            (true, false, true, false, false, false, false),
            (true, true, false, false, false, false, false),
            (true, true, true, true, false, false, false),
            (true, true, true, false, true, false, false),
            (true, true, true, false, false, true, false),
            (true, true, true, false, false, false, true),
        ]
        for state in blockedStates {
            XCTAssertFalse(PetCompanionAutomaticSpeechPolicy.shouldSchedule(
                isHomeVisible: state.0,
                isSceneActive: state.1,
                isPetEnabled: state.2,
                isPresentationBlocked: state.3,
                hasBubble: state.4,
                hasMessageRequest: state.5,
                hasPendingSavedMessage: state.6
            ))
        }
    }

    func testAutomaticSpeechStartsWithTheInteractionHintThenUsesBoundedIdleCadence() {
        XCTAssertEqual(
            PetCompanionAutomaticSpeechPolicy.nextStep(
                hasPresentedInteractionHint: false,
                automaticPresentationCount: 0,
                hasPresentedIdleMessageInSession: false,
                voiceOverEnabled: false
            ),
            .init(kind: .interactionHint, delayNanoseconds: 5_000_000_000)
        )
        XCTAssertEqual(
            PetCompanionAutomaticSpeechPolicy.nextStep(
                hasPresentedInteractionHint: true,
                automaticPresentationCount: 1,
                hasPresentedIdleMessageInSession: false,
                voiceOverEnabled: false
            ),
            .init(kind: .idle, delayNanoseconds: 25_000_000_000)
        )
        XCTAssertEqual(
            PetCompanionAutomaticSpeechPolicy.nextStep(
                hasPresentedInteractionHint: true,
                automaticPresentationCount: 2,
                hasPresentedIdleMessageInSession: true,
                voiceOverEnabled: false
            ),
            .init(kind: .idle, delayNanoseconds: 150_000_000_000)
        )
        XCTAssertNil(PetCompanionAutomaticSpeechPolicy.nextStep(
            hasPresentedInteractionHint: true,
            automaticPresentationCount: PetCompanionAutomaticSpeechPolicy.maximumPresentationsPerSession,
            hasPresentedIdleMessageInSession: true,
            voiceOverEnabled: false
        ))
    }

    func testVoiceOverAutomaticSpeechUsesLongerDelays() {
        let hint = PetCompanionAutomaticSpeechPolicy.nextStep(
            hasPresentedInteractionHint: false,
            automaticPresentationCount: 0,
            hasPresentedIdleMessageInSession: false,
            voiceOverEnabled: true
        )
        let firstIdle = PetCompanionAutomaticSpeechPolicy.nextStep(
            hasPresentedInteractionHint: true,
            automaticPresentationCount: 1,
            hasPresentedIdleMessageInSession: false,
            voiceOverEnabled: true
        )
        let repeatedIdle = PetCompanionAutomaticSpeechPolicy.nextStep(
            hasPresentedInteractionHint: true,
            automaticPresentationCount: 2,
            hasPresentedIdleMessageInSession: true,
            voiceOverEnabled: true
        )

        XCTAssertEqual(hint?.delayNanoseconds, 9_000_000_000)
        XCTAssertEqual(firstIdle?.delayNanoseconds, 45_000_000_000)
        XCTAssertEqual(repeatedIdle?.delayNanoseconds, 240_000_000_000)
    }

    func testEmptyPetCopyOffersCompanyWithoutRepeatingRecordingInstructions() {
        XCTAssertTrue(PetCompanionCopy.noRecords.allSatisfy { $0.text.contains("我") })
        XCTAssertFalse(PetCompanionCopy.noRecords.contains {
            $0.text.contains("硬凑") || $0.text.contains("先记") || $0.text.contains("想起一笔")
        })
    }
}

final class HomeEmptyTodayCopyPolicyTests: XCTestCase {
    func testSuggestionAndSceneRemainObservationsInsteadOfRecordingCommands() {
        let suggestion = HomeEmptyTodayCopyPolicy.copy(
            frequentSuggestionLine: "往常这个时间，你常记的是 ¥12 · 餐饮。",
            dominantSceneLine: "这周「通勤」出现得比较多。"
        )
        let scene = HomeEmptyTodayCopyPolicy.copy(
            frequentSuggestionLine: nil,
            dominantSceneLine: "这周「通勤」出现得比较多。"
        )
        let plain = HomeEmptyTodayCopyPolicy.copy(
            frequentSuggestionLine: nil,
            dominantSceneLine: nil
        )

        XCTAssertEqual(suggestion.title, "今天还没有记录")
        XCTAssertEqual(suggestion.subtitle, "往常这个时间，你常记的是 ¥12 · 餐饮。")
        XCTAssertEqual(scene.subtitle, "这周「通勤」出现得比较多。")
        XCTAssertEqual(plain.subtitle, "今天这一页暂时还是空的。")
        for copy in [suggestion, scene, plain] {
            XCTAssertFalse(copy.title.contains("从这里开始"))
            XCTAssertFalse(copy.subtitle.contains("只输金额"))
            XCTAssertFalse(copy.subtitle.contains("先放进账本"))
        }
    }
}

final class RecordTimeSelectionPolicyTests: XCTestCase {
    private func calendar(timeZone: TimeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func date(
        year: Int = 2026,
        month: Int = 7,
        day: Int = 18,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: 37
        ))!
    }

    func testLargeTimeChangeCommitsOneNormalizedDateWithoutChangingDay() {
        let calendar = calendar()
        let source = date(hour: 22, minute: 55, calendar: calendar)
        let result = RecordTimeSelectionPolicy.applyingTime(
            hour: 8,
            minute: 5,
            to: source,
            calendar: calendar
        )
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: result)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 18)
        XCTAssertEqual(components.hour, 8)
        XCTAssertEqual(components.minute, 5)
        XCTAssertEqual(components.second, 0)
    }

    func testMidnightAndEndOfDayRemainOnTheSelectedDate() {
        let calendar = calendar()
        let source = date(year: 2028, month: 2, day: 29, hour: 12, minute: 30, calendar: calendar)
        let midnight = RecordTimeSelectionPolicy.applyingTime(hour: 0, minute: 0, to: source, calendar: calendar)
        let endOfDay = RecordTimeSelectionPolicy.applyingTime(hour: 23, minute: 59, to: source, calendar: calendar)

        XCTAssertTrue(calendar.isDate(midnight, inSameDayAs: source))
        XCTAssertTrue(calendar.isDate(endOfDay, inSameDayAs: source))
        XCTAssertEqual(calendar.component(.hour, from: midnight), 0)
        XCTAssertEqual(calendar.component(.minute, from: midnight), 0)
        XCTAssertEqual(calendar.component(.hour, from: endOfDay), 23)
        XCTAssertEqual(calendar.component(.minute, from: endOfDay), 59)
    }

    func testOutOfRangeValuesAreClampedInsteadOfRollingTheDate() {
        let calendar = calendar()
        let source = date(hour: 12, minute: 30, calendar: calendar)
        let result = RecordTimeSelectionPolicy.applyingTime(
            hour: 99,
            minute: -8,
            to: source,
            calendar: calendar
        )

        XCTAssertTrue(calendar.isDate(result, inSameDayAs: source))
        XCTAssertEqual(calendar.component(.hour, from: result), 23)
        XCTAssertEqual(calendar.component(.minute, from: result), 0)
    }

    func testDSTGapUsesAValidTimeOnTheSameLocalDay() {
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
        let calendar = calendar(timeZone: losAngeles)
        let source = date(year: 2026, month: 3, day: 8, hour: 1, minute: 30, calendar: calendar)
        let result = RecordTimeSelectionPolicy.applyingTime(
            hour: 2,
            minute: 30,
            to: source,
            calendar: calendar
        )

        XCTAssertTrue(calendar.isDate(result, inSameDayAs: source))
        XCTAssertEqual(calendar.component(.minute, from: result), 30)
        XCTAssertGreaterThanOrEqual(calendar.component(.hour, from: result), 3)
    }
}

final class MembershipDetailPresentationPolicyTests: XCTestCase {
    func testProspectSeesOneSalesComparisonAndPricing() {
        let policy = MembershipDetailPresentationPolicy.resolve(
            isMember: false,
            isLifetimeMember: false
        )

        XCTAssertEqual(policy.state, .prospect)
        XCTAssertTrue(policy.showsSalesHero)
        XCTAssertTrue(policy.showsPricing)
        XCTAssertTrue(policy.showsValueComparison)
        XCTAssertFalse(policy.showsMemberStatus)
        XCTAssertFalse(policy.showsUnlockedSummary)
        XCTAssertFalse(policy.showsSubscriptionActions)
        XCTAssertFalse(policy.showsMemberDataBoundary)
        XCTAssertFalse(policy.showsLifetimeUpgrade)
        XCTAssertFalse(policy.showsLifetimeManagement)
        for planID in ["monthly", "yearly", "lifetime"] {
            XCTAssertTrue(policy.allowsPurchase(planID: planID))
        }
    }

    func testSubscriptionSeesStatusUnlockedSummaryAndManagementWithoutSalesComparison() {
        let policy = MembershipDetailPresentationPolicy.resolve(
            isMember: true,
            isLifetimeMember: false
        )

        XCTAssertEqual(policy.state, .subscription)
        XCTAssertFalse(policy.showsSalesHero)
        XCTAssertFalse(policy.showsPricing)
        XCTAssertFalse(policy.showsValueComparison)
        XCTAssertTrue(policy.showsMemberStatus)
        XCTAssertTrue(policy.showsUnlockedSummary)
        XCTAssertTrue(policy.showsSubscriptionActions)
        XCTAssertTrue(policy.showsMemberDataBoundary)
        XCTAssertTrue(policy.showsLifetimeUpgrade)
        XCTAssertFalse(policy.showsLifetimeManagement)
        XCTAssertTrue(policy.allowsPurchase(planID: "lifetime"))
        XCTAssertFalse(policy.allowsPurchase(planID: "monthly"))
        XCTAssertFalse(policy.allowsPurchase(planID: "yearly"))
    }

    func testLifetimeMemberGoesFromStatusToArchiveWithoutRepeatedValueCards() {
        let policy = MembershipDetailPresentationPolicy.resolve(
            isMember: true,
            isLifetimeMember: true
        )

        XCTAssertEqual(policy.state, .lifetime)
        XCTAssertFalse(policy.showsSalesHero)
        XCTAssertFalse(policy.showsPricing)
        XCTAssertFalse(policy.showsValueComparison)
        XCTAssertTrue(policy.showsMemberStatus)
        XCTAssertFalse(policy.showsUnlockedSummary)
        XCTAssertFalse(policy.showsSubscriptionActions)
        XCTAssertTrue(policy.showsMemberDataBoundary)
        XCTAssertFalse(policy.showsLifetimeUpgrade)
        XCTAssertTrue(policy.showsLifetimeManagement)
        for planID in ["monthly", "yearly", "lifetime"] {
            XCTAssertFalse(policy.allowsPurchase(planID: planID))
        }
    }
}

final class AnalyticsPrivacyBoundaryTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "AnalyticsPrivacyBoundaryTests")!
        defaults.removePersistentDomain(forName: "AnalyticsPrivacyBoundaryTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "AnalyticsPrivacyBoundaryTests")
        defaults = nil
        super.tearDown()
    }

    @MainActor
    func testLegacyEventsWithSensitivePropertiesAreRemoved() {
        defaults.set(Data("legacy-sensitive-event".utf8), forKey: "ios_analytics_events_v1")
        _ = AnalyticsService(defaults: defaults)
        XCTAssertNil(defaults.data(forKey: "ios_analytics_events_v1"))
    }

    @MainActor
    func testOnlyAllowlistedAnonymousPropertiesArePersisted() {
        let service = AnalyticsService(defaults: defaults)
        service.track(
            .recordSaved,
            props: [
                .source: "manual",
                .ledgerSizeBucket: "10_49",
                .countBucket: "42",
                .scene: "用户备注",
            ]
        )

        let event = try! XCTUnwrap(service.loadEvents().first)
        XCTAssertEqual(event.name, .recordSaved)
        XCTAssertEqual(event.props["source"], "manual")
        XCTAssertEqual(event.props["ledger_size_bucket"], "10_49")
        XCTAssertNil(event.props["count_bucket"])
        XCTAssertNil(event.props["scene"])
        XCTAssertNil(event.props["amount"])
        XCTAssertNil(event.props["title"])
        XCTAssertNil(event.props["merchant"])
    }

    @MainActor
    func testCountsAndDurationsUseCoarseBuckets() {
        XCTAssertEqual(AnalyticsService.countBucket(for: 0), "0")
        XCTAssertEqual(AnalyticsService.countBucket(for: 37), "10_49")
        XCTAssertEqual(AnalyticsService.countBucket(for: 1_000), "1000_4999")
        XCTAssertEqual(AnalyticsService.countBucket(for: 5_000), "5000_plus")
        XCTAssertEqual(AnalyticsService.durationBucket(for: 49), "under_50ms")
        XCTAssertEqual(AnalyticsService.durationBucket(for: 150), "150_399ms")
        XCTAssertEqual(AnalyticsService.durationBucket(for: 3_000), "3s_plus")
    }

    @MainActor
    func testEventsExpireAfterThirtyDaysAndHaveNoStableUserIdentifier() {
        let service = AnalyticsService(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        service.track(.appOpened, props: [.ledgerSizeBucket: "100_999"], at: now.addingTimeInterval(-31 * 86_400))
        service.track(.appOpened, props: [.ledgerSizeBucket: "100_999"], at: now)

        let events = service.loadEvents(referenceDate: now)
        XCTAssertEqual(events.count, 1)
        XCTAssertFalse(events[0].props.keys.contains("user_id"))
        XCTAssertFalse(events[0].props.keys.contains("device_id"))
    }
}

#if DEBUG && canImport(UIKit)
final class ReleaseScaleFixtureTests: XCTestCase {
    private struct Manifest: Decodable {
        let fixtureSetDigestSha256: String
        let fixtures: [FixtureEntry]
    }

    private struct FixtureEntry: Decodable {
        let file: String
        let recordCount: Int
        let amountMinorUnitTotal: Int
        let imageCount: Int
        let photoRecordCount: Int
        let recordDigestSha256: String
        let ocrDraftCounts: OCRDraftCounts
    }

    private struct OCRDraftCounts: Decodable {
        let pending: Int
        let resolved: Int
        let total: Int
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func loadManifest() throws -> Manifest {
        let url = try fixtureURL(named: "manifest.json")
        return try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
    }

    private func loadFixture(file: String) throws -> [HomeItem] {
        let url = try fixtureURL(named: file)
        return try JSONDecoder().decode([HomeItem].self, from: Data(contentsOf: url))
    }

    private func fixtureURL(named file: String) throws -> URL {
        let repositoryURL = repositoryRoot.appendingPathComponent("qa/release_fixtures/\(file)")
        if FileManager.default.fileExists(atPath: repositoryURL.path) {
            return repositoryURL
        }
        if let bundleURL = Bundle(for: ReleaseScaleFixtureTests.self)
            .url(forResource: file.replacingOccurrences(of: ".json", with: ""),
                 withExtension: "json",
                 subdirectory: "release_fixtures") {
            return bundleURL
        }
        throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: repositoryURL.path])
    }

    private func minorUnitTotal(_ items: [HomeItem]) -> Int {
        items.reduce(0) { $0 + Int(($1.amount * 100).rounded()) }
    }

    func testReleaseFixtureLaunchConfigurationRejectsUnsupportedOrMissingCounts() {
        XCTAssertNil(ReleaseFixtureLaunchConfiguration.resolve(arguments: [], environment: [:]))
        XCTAssertNil(
            ReleaseFixtureLaunchConfiguration.resolve(
                arguments: ["app", "-QAReleaseFixtureCount", "999"],
                environment: [:]
            )
        )
        XCTAssertEqual(
            ReleaseFixtureLaunchConfiguration.resolve(
                arguments: ["app", "-QAReleaseFixtureCount", "1000", "-QAReleaseFixtureReset"],
                environment: [:]
            ),
            ReleaseFixtureLaunchConfiguration(count: 1_000, reset: true)
        )
        XCTAssertEqual(
            ReleaseFixtureLaunchConfiguration.resolve(
                arguments: [
                    "app", "-QAReleaseFixtureCount", "1000",
                    "-QAReleasePhotoProfile", "realistic",
                ],
                environment: [:]
            ),
            ReleaseFixtureLaunchConfiguration(
                count: 1_000,
                reset: false,
                photoProfile: .realistic
            )
        )
    }

    func testRealisticPhotoFixtureUsesPhoneSizedJPEGResources() throws {
        let items = ReleaseFixtureFactory.makeItems(count: 1_000, photoProfile: .realistic)
        let photos = items.flatMap(\.memoryImages)
        XCTAssertFalse(photos.isEmpty)
        var uniquePhotos: [Data] = []
        for data in photos where !uniquePhotos.contains(data) {
            uniquePhotos.append(data)
            if uniquePhotos.count == 3 { break }
        }
        XCTAssertEqual(uniquePhotos.count, 3)
        for data in uniquePhotos {
            let image = try XCTUnwrap(UIImage(data: data))
            XCTAssertGreaterThanOrEqual(Int(image.size.width * image.scale) * Int(image.size.height * image.scale), 12_000_000)
            XCTAssertGreaterThanOrEqual(data.count, 2_000_000)
        }
    }

    func testGeneratedReleaseFixturesMatchSwiftFactoryAndDecodeValidImages() throws {
        let manifest = try loadManifest()
        XCTAssertEqual(manifest.fixtures.map(\.recordCount), [100, 1_000, 5_000])
        XCTAssertEqual(manifest.fixtureSetDigestSha256.count, 64)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        for entry in manifest.fixtures {
            let actual = try loadFixture(file: entry.file)
            let expected = ReleaseFixtureFactory.makeItems(count: entry.recordCount)
            XCTAssertEqual(actual.count, entry.recordCount)
            XCTAssertEqual(actual.count, expected.count)
            XCTAssertEqual(minorUnitTotal(actual), entry.amountMinorUnitTotal)
            XCTAssertEqual(Set(actual.map(\.category)), Set(HomeItem.Category.allCases))
            XCTAssertEqual(
                Set(actual.map { calendar.component(.year, from: $0.createdAt) }),
                Set([2024, 2025, 2026])
            )

            var imageCount = 0
            var photoRecordCount = 0
            var pendingCount = 0
            var resolvedCount = 0
            for (index, pair) in zip(actual, expected).enumerated() {
                XCTAssertEqual(pair.0, pair.1, "release fixture mismatch at \(entry.recordCount)#\(index)")
                if !pair.0.memoryImages.isEmpty {
                    photoRecordCount += 1
                }
                imageCount += pair.0.memoryImages.count
                for imageData in pair.0.memoryImages {
                    XCTAssertNotNil(UIImage(data: imageData), "invalid image at \(entry.recordCount)#\(index)")
                }
                if let coverIndex = pair.0.normalizedCoverMemoryImageIndex {
                    XCTAssertTrue(pair.0.memoryImages.indices.contains(coverIndex))
                    XCTAssertEqual(pair.0.coverMemoryImageData, pair.0.memoryImages[coverIndex])
                }
                switch pair.0.draftMeta?.status {
                case .pending: pendingCount += 1
                case .resolved: resolvedCount += 1
                case nil: break
                }
            }

            XCTAssertEqual(imageCount, entry.imageCount)
            XCTAssertEqual(photoRecordCount, entry.photoRecordCount)
            XCTAssertEqual(pendingCount, entry.ocrDraftCounts.pending)
            XCTAssertEqual(resolvedCount, entry.ocrDraftCounts.resolved)
            XCTAssertEqual(pendingCount + resolvedCount, entry.ocrDraftCounts.total)
            XCTAssertEqual(entry.recordDigestSha256.count, 64)
        }
    }

    func testReleaseScaleMigrationPreservesCountAmountImagesOrderAndCover() throws {
        for count in [100, 1_000, 5_000] {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("ReleaseScaleFixtureTests-\(count)-\(UUID().uuidString)", isDirectory: true)
            let suiteName = "ReleaseScaleFixtureTests.\(count).\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
            defer {
                defaults.removePersistentDomain(forName: suiteName)
                try? FileManager.default.removeItem(at: root)
            }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

            let sourceItems = ReleaseFixtureFactory.makeItems(count: count)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let legacyData = try encoder.encode(sourceItems)
            try legacyData.write(to: root.appendingPathComponent("home_items_v1.json"), options: .atomic)
            defaults.set(legacyData, forKey: "home_items_v1_backup")

            let repository = LedgerHomeItemsRepository(documentsURL: root, defaults: defaults)
            let result = repository.load()
            XCTAssertFalse(result.writesBlocked)
            XCTAssertEqual(result.items.count, count)
            XCTAssertEqual(minorUnitTotal(result.items), minorUnitTotal(sourceItems))
            XCTAssertTrue(
                FileManager.default.fileExists(
                    atPath: root.appendingPathComponent("home_items_v1.pre_image_migration.json").path
                )
            )

            let sourceByID = Dictionary(uniqueKeysWithValues: sourceItems.map { ($0.id, $0) })
            let loadedByID = Dictionary(uniqueKeysWithValues: result.items.map { ($0.id, $0) })
            XCTAssertEqual(Set(sourceByID.keys), Set(loadedByID.keys))
            for id in sourceByID.keys {
                let source = try XCTUnwrap(sourceByID[id])
                let loaded = try XCTUnwrap(loadedByID[id])
                XCTAssertEqual(loaded.amount, source.amount)
                XCTAssertEqual(loaded.category, source.category)
                XCTAssertEqual(loaded.draftMeta, source.draftMeta)
                XCTAssertEqual(loaded.memoryImageCount, source.memoryImageCount)
                XCTAssertTrue(loaded.memoryImages.allSatisfy(\.isEmpty))
                XCTAssertEqual(loaded.normalizedCoverMemoryImageIndex, source.normalizedCoverMemoryImageIndex)
                XCTAssertEqual(loaded.memoryImageReferences.count, source.memoryImages.count)
                for index in 0..<loaded.memoryImageCount {
                    let reference = try XCTUnwrap(loaded.memoryImageReference(at: index))
                    XCTAssertEqual(
                        repository.loadImageData(reference: reference, variant: .original),
                        source.memoryImageData(at: index)
                    )
                }
            }
        }
    }

    func testReviewAndAIStayDeterministicAtAllReleaseScales() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        for count in [100, 1_000, 5_000] {
            let items = ReleaseFixtureFactory.makeItems(count: count)
            let input = InsightComputationInput(items: items, isMember: true, now: now)
            let firstSnapshot = InsightComputationService.weeklyPageSnapshot(input)
            let secondSnapshot = InsightComputationService.weeklyPageSnapshot(input)
            XCTAssertEqual(firstSnapshot.journalText, secondSnapshot.journalText)
            XCTAssertEqual(firstSnapshot.journalClosing, secondSnapshot.journalClosing)
            XCTAssertEqual(firstSnapshot.rhythmText, secondSnapshot.rhythmText)
            XCTAssertEqual(firstSnapshot.keywords, secondSnapshot.keywords)
            XCTAssertEqual(firstSnapshot.reviewOverview, secondSnapshot.reviewOverview)

            let firstDigest = InsightWebView.aiCommandComputationDigestForTesting(
                command: "最近 90 天餐饮花了多少",
                items: items,
                hasMemberAccess: true,
                now: now
            )
            let secondDigest = InsightWebView.aiCommandComputationDigestForTesting(
                command: "最近 90 天餐饮花了多少",
                items: items,
                hasMemberAccess: true,
                now: now
            )
            XCTAssertFalse(firstDigest.isEmpty)
            XCTAssertEqual(firstDigest, secondDigest)
        }
    }

    func testRelationshipDiscoveryStaysDeterministicAtAllReleaseScales() {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!
        let anchor = calendar.date(from: DateComponents(year: 2030, month: 7, day: 23, hour: 12))!
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: anchor)!.start
        let now = calendar.date(byAdding: .hour, value: 71, to: weekStart)!

        func row(_ title: String, category: HomeItem.Category, week: Int, day: Int, hour: Int) -> HomeItem {
            let periodStart = calendar.date(byAdding: .weekOfYear, value: -week, to: weekStart)!
            let date = calendar.date(byAdding: .day, value: day, to: periodStart)!
            return HomeItem(
                title: title,
                amount: 12,
                category: category,
                createdAt: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
            )
        }

        let baseline = (1...4).map {
            row("普通午餐", category: .dining, week: $0, day: 1, hour: 12)
        }
        let current = [0, 1].flatMap { day in
            [
                row("下班通勤", category: .transport, week: 0, day: day, hour: 22),
                row("夜间咖啡", category: .dining, week: 0, day: day, hour: 23),
            ]
        }

        for count in [100, 1_000, 5_000] {
            let items = ReleaseFixtureFactory.makeItems(count: count) + baseline + current
            let input = LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: count,
                items: items,
                now: now,
                recentEchoIDs: []
            )
            let first = LifeNarrativeEchoPolicy.makeEcho(input, calendar: calendar)
            let second = LifeNarrativeEchoPolicy.makeEcho(input, calendar: calendar)

            XCTAssertEqual(first, second)
            XCTAssertEqual(first?.kind, .newContextPair)
            XCTAssertEqual(first?.baselinePeriodCount, 4)
        }
    }
}

final class CloudLedgerOwnershipPolicyTests: XCTestCase {
    func testEmptyLocalLedgerNeverAsksRegardlessOfOwner() {
        XCTAssertEqual(
            CloudLedgerOwnershipPolicy.loginDecision(
                localItemCount: 0,
                localLedgerOwnerUserId: "user-a",
                currentUserId: "user-b",
                accountCloudSyncEnabled: true
            ),
            .none
        )
    }

    func testLocalLedgerSyncedToAnotherAccountAlwaysAsksEvenWhenNewAccountNeverEnabledSync() {
        // 用户复现路径：A 记账并同步 → 登出 → 登录全新的 B（服务端同步为关）。
        XCTAssertEqual(
            CloudLedgerOwnershipPolicy.loginDecision(
                localItemCount: 1,
                localLedgerOwnerUserId: "user-a",
                currentUserId: "user-b",
                accountCloudSyncEnabled: false
            ),
            .localLedgerBelongsToAnotherAccount
        )
    }

    func testLocalLedgerOwnedByCurrentAccountDoesNotAsk() {
        XCTAssertEqual(
            CloudLedgerOwnershipPolicy.loginDecision(
                localItemCount: 5,
                localLedgerOwnerUserId: "user-a",
                currentUserId: "user-a",
                accountCloudSyncEnabled: true
            ),
            .none
        )
    }

    func testNeverSyncedLocalLedgerKeepsLegacyMergePromptOnlyWhenAccountHasSyncOn() {
        XCTAssertEqual(
            CloudLedgerOwnershipPolicy.loginDecision(
                localItemCount: 5,
                localLedgerOwnerUserId: "",
                currentUserId: "user-a",
                accountCloudSyncEnabled: true
            ),
            .mergeUnownedLocalLedger
        )
        XCTAssertEqual(
            CloudLedgerOwnershipPolicy.loginDecision(
                localItemCount: 5,
                localLedgerOwnerUserId: "",
                currentUserId: "user-a",
                accountCloudSyncEnabled: false
            ),
            .none
        )
    }

    func testOwnerFollowsSyncEnableAndClearsWithLocalLedger() {
        XCTAssertEqual(CloudLedgerOwnershipPolicy.ownerAfterEnablingSync(currentUserId: "  user-a "), "user-a")
        XCTAssertEqual(CloudLedgerOwnershipPolicy.ownerAfterClearingLocalLedger(), "")
    }
}

final class ApplicationInstallationSessionPolicyTests: XCTestCase {
    func testFreshInstallWithoutAnyAppDataDiscardsPersistedKeychainSession() {
        XCTAssertTrue(
            ApplicationInstallationSessionPolicy.shouldDiscardPersistedSession(
                hasInstallMarker: false,
                hasExistingInstallationData: false
            )
        )
    }

    func testFirstLaunchAfterUpgradeKeepsAnExistingSessionWithoutMarker() {
        XCTAssertFalse(
            ApplicationInstallationSessionPolicy.shouldDiscardPersistedSession(
                hasInstallMarker: false,
                hasExistingInstallationData: true
            )
        )
    }

    func testRegisteredInstallationAlwaysKeepsItsSession() {
        XCTAssertFalse(
            ApplicationInstallationSessionPolicy.shouldDiscardPersistedSession(
                hasInstallMarker: true,
                hasExistingInstallationData: false
            )
        )
        XCTAssertFalse(
            ApplicationInstallationSessionPolicy.shouldDiscardPersistedSession(
                hasInstallMarker: true,
                hasExistingInstallationData: true
            )
        )
    }
}

final class CloudLedgerMergePolicyTests: XCTestCase {
    private func item(
        _ id: UUID,
        title: String,
        updatedAt: Date,
        images: [Data] = [],
        references: [String] = [],
        cover: Int? = nil,
        scenePackId: String? = nil
    ) -> HomeItem {
        HomeItem(
            id: id,
            title: title,
            amount: 10,
            category: .dining,
            createdAt: updatedAt.addingTimeInterval(-3600),
            updatedAt: updatedAt,
            scenePackId: scenePackId,
            memoryImageDatas: images,
            memoryImageReferences: references,
            coverMemoryImageIndex: cover
        )
    }

    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    func testRemoteTombstoneDeletesLocalRecordAndNeverReuploadsIt() {
        let id = UUID()
        let local = item(id, title: "已在别的设备删除", updatedAt: base)
        let result = CloudLedgerMergePolicy.merge(
            local: [local],
            remote: [],
            tombstones: [.init(id: id, deletedAt: base.addingTimeInterval(60))]
        )
        XCTAssertTrue(result.merged.isEmpty)
        XCTAssertTrue(result.uploads.isEmpty)
        XCTAssertEqual(result.deletedByRemote, [id])
    }

    func testLocalEditNewerThanTombstoneSurvivesAndIsUploaded() {
        let id = UUID()
        let local = item(id, title: "删除后又改过", updatedAt: base.addingTimeInterval(120))
        let result = CloudLedgerMergePolicy.merge(
            local: [local],
            remote: [],
            tombstones: [.init(id: id, deletedAt: base.addingTimeInterval(60))]
        )
        XCTAssertEqual(result.merged.map(\.id), [id])
        XCTAssertEqual(result.uploads.map(\.id), [id])
        XCTAssertTrue(result.deletedByRemote.isEmpty)
    }

    func testRemoteWinnerKeepsLocalPhotosCoverAndScenePack() {
        let id = UUID()
        let photo = Data([0x01, 0x02])
        let local = item(
            id,
            title: "旧标题",
            updatedAt: base,
            images: [photo, photo],
            references: ["ref-a", "ref-b"],
            cover: 1,
            scenePackId: "commute"
        )
        let remote = item(id, title: "新标题", updatedAt: base.addingTimeInterval(60))
        let result = CloudLedgerMergePolicy.merge(local: [local], remote: [remote], tombstones: [])

        XCTAssertEqual(result.merged.count, 1)
        let merged = result.merged[0]
        XCTAssertEqual(merged.title, "新标题")
        XCTAssertEqual(merged.updatedAt, remote.updatedAt)
        XCTAssertEqual(merged.memoryImageReferences, ["ref-a", "ref-b"])
        XCTAssertEqual(merged.memoryImageDatas.count, 2)
        XCTAssertEqual(merged.coverMemoryImageIndex, 1)
        XCTAssertEqual(merged.scenePackId, "commute")
        XCTAssertTrue(result.uploads.isEmpty, "Remote already has the newest version; nothing to re-upload.")
    }

    func testOnlyLocalNewerOrMissingRecordsAreUploaded() {
        let sameID = UUID()
        let localNewerID = UUID()
        let localOnlyID = UUID()
        let remoteOnlyID = UUID()
        let local = [
            item(sameID, title: "same", updatedAt: base),
            item(localNewerID, title: "local newer", updatedAt: base.addingTimeInterval(60)),
            item(localOnlyID, title: "local only", updatedAt: base),
        ]
        let remote = [
            item(sameID, title: "same", updatedAt: base),
            item(localNewerID, title: "remote older", updatedAt: base),
            item(remoteOnlyID, title: "remote only", updatedAt: base),
        ]
        let result = CloudLedgerMergePolicy.merge(local: local, remote: remote, tombstones: [])
        XCTAssertEqual(Set(result.merged.map(\.id)), [sameID, localNewerID, localOnlyID, remoteOnlyID])
        XCTAssertEqual(Set(result.uploads.map(\.id)), [localNewerID, localOnlyID])
        XCTAssertEqual(result.merged.first { $0.id == localNewerID }?.title, "local newer")
    }
}

final class IAPEntitlementSelectionTests: XCTestCase {
    private func payload(
        _ transactionId: String,
        tier: IAPTier,
        expirationDate: Date? = nil
    ) -> IAPPurchaseVerification {
        IAPPurchaseVerification(
            productId: "com.xuzhang.app.member.\(tier.rawValue)",
            transactionId: transactionId,
            signedTransactionInfo: "test-\(transactionId)",
            tier: tier,
            expirationDate: expirationDate
        )
    }

    func testLifetimeRemainsFirstRegardlessOfSubscriptionExpiryOrInputOrder() {
        let distantExpiry = Date(timeIntervalSince1970: 4_070_908_800)
        let monthly = payload("monthly", tier: .monthly, expirationDate: distantExpiry)
        let yearly = payload("yearly", tier: .yearly, expirationDate: distantExpiry)
        let lifetime = payload("lifetime", tier: .lifetime)

        for input in [
            [monthly, yearly, lifetime],
            [yearly, lifetime, monthly],
            [lifetime, monthly, yearly],
        ] {
            XCTAssertEqual(
                IAPEntitlementSelection.prioritized(input),
                [lifetime, yearly, monthly]
            )
        }
    }

    func testMultipleCandidatesPreserveFallbacksAndStableTiesWithinEachTier() {
        let earlier = Date(timeIntervalSince1970: 1_800_000_000)
        let later = earlier.addingTimeInterval(86_400)
        let yearlyEarly = payload("yearly-early", tier: .yearly, expirationDate: earlier)
        let yearlyLate = payload("yearly-late", tier: .yearly, expirationDate: later)
        let yearlyTied = payload("yearly-tied", tier: .yearly, expirationDate: later)
        let yearlyUnknown = payload("yearly-unknown", tier: .yearly)
        let monthly = payload("monthly", tier: .monthly, expirationDate: later)
        let firstLifetime = payload("lifetime-first", tier: .lifetime)
        let secondLifetime = payload("lifetime-second", tier: .lifetime)

        XCTAssertEqual(
            IAPEntitlementSelection.prioritized([
                yearlyEarly, firstLifetime, yearlyLate, monthly,
                secondLifetime, yearlyUnknown, yearlyTied,
            ]),
            [
                firstLifetime, secondLifetime, yearlyLate, yearlyTied,
                yearlyEarly, yearlyUnknown, monthly,
            ]
        )
    }

    func testEmptyEntitlementsHaveNoRestoreCandidate() {
        XCTAssertTrue(IAPEntitlementSelection.prioritized([]).isEmpty)
    }

    @MainActor
    func testRejectedLifetimeContinuesToTheCurrentAccountsSubscription() async {
        let lifetime = payload("other-account-lifetime", tier: .lifetime)
        let yearly = payload("current-account-yearly", tier: .yearly)
        let monthly = payload("monthly", tier: .monthly)
        var attempts: [String] = []

        let result = await IAPEntitlementSelection.verifyFirstAvailable(in: [monthly, yearly, lifetime]) { candidate in
            attempts.append(candidate.transactionId)
            if candidate == lifetime {
                throw AuthServiceError.iapVerifyFailed(code: "TRANSACTION_ALREADY_BOUND", message: "")
            }
        }

        XCTAssertEqual(attempts, [lifetime.transactionId, yearly.transactionId])
        XCTAssertEqual(result.verifiedPayload, yearly)
        XCTAssertEqual(result.firstFailure?.tier, .lifetime)
        guard let firstFailure = result.firstFailure else {
            return XCTFail("The original account-binding rejection must remain available.")
        }
        XCTAssertTrue(IAPRestoreFailureCopy.message(for: firstFailure.error).contains("不能解绑或转移"))
    }

    @MainActor
    func testSuccessfulLifetimeStopsBeforeAnySubscriptionVerification() async {
        let lifetime = payload("lifetime", tier: .lifetime)
        let yearly = payload("yearly", tier: .yearly)
        var attempts: [String] = []

        let result = await IAPEntitlementSelection.verifyFirstAvailable(in: [yearly, lifetime]) { candidate in
            attempts.append(candidate.transactionId)
        }

        XCTAssertEqual(attempts, [lifetime.transactionId])
        XCTAssertEqual(result.verifiedPayload, lifetime)
        XCTAssertNil(result.firstFailure)
    }

    @MainActor
    func testEveryRejectedCandidatePreservesTheFirstFailureAndNoSuccess() async {
        let lifetime = payload("lifetime", tier: .lifetime)
        let yearly = payload("yearly", tier: .yearly)
        let monthly = payload("monthly", tier: .monthly)
        var attempts: [String] = []

        let result = await IAPEntitlementSelection.verifyFirstAvailable(in: [monthly, lifetime, yearly]) { candidate in
            attempts.append(candidate.transactionId)
            if candidate == lifetime {
                throw AuthServiceError.iapVerifyFailed(code: "TRANSACTION_ALREADY_BOUND", message: "")
            }
            throw IAPServiceError.unverifiedTransaction
        }

        XCTAssertEqual(attempts, [lifetime.transactionId, yearly.transactionId, monthly.transactionId])
        XCTAssertNil(result.verifiedPayload)
        XCTAssertEqual(result.firstFailure?.tier, .lifetime)
        guard let firstFailure = result.firstFailure else {
            return XCTFail("All failures must retain the first verification error.")
        }
        XCTAssertTrue(IAPRestoreFailureCopy.message(for: firstFailure.error).contains("不能解绑或转移"))
    }

    @MainActor
    func testCancellationStopsVerificationBeforeAnotherCandidate() async {
        let lifetime = payload("lifetime", tier: .lifetime)
        let yearly = payload("yearly", tier: .yearly)
        var attempts: [String] = []

        let result = await IAPEntitlementSelection.verifyFirstAvailable(in: [yearly, lifetime]) { candidate in
            attempts.append(candidate.transactionId)
            throw CancellationError()
        }

        XCTAssertEqual(attempts, [lifetime.transactionId])
        XCTAssertNil(result.verifiedPayload)
        XCTAssertNil(result.firstFailure)
    }
}

final class IAPRestoreFailureCopyTests: XCTestCase {
    func testBoundToAnotherAccountIsSurfacedInsteadOfGenericNoEntitlement() {
        let message = IAPRestoreFailureCopy.message(
            for: AuthServiceError.iapVerifyFailed(code: "TRANSACTION_ALREADY_BOUND", message: "")
        )
        XCTAssertTrue(message.contains("另一个叙账账号"))
        XCTAssertTrue(message.contains("购买时使用的手机号账号"))
        XCTAssertFalse(message.contains("更换 Apple ID"))
        XCTAssertTrue(message.contains("不能解绑或转移"))
        XCTAssertFalse(message.contains("联系客服"))
        XCTAssertNotEqual(message, IAPRestoreFailureCopy.genericMessage)
    }

    func testLifetimeConflictIsLabeledAsPurchaseNotSubscription() {
        let message = IAPRestoreFailureCopy.message(
            for: AuthServiceError.iapVerifyFailed(code: "TRANSACTION_ALREADY_BOUND", message: ""),
            tier: .lifetime
        )
        XCTAssertTrue(message.contains("App Store 购买"))
        XCTAssertFalse(message.contains("App Store 订阅"))
        XCTAssertFalse(message.contains("解绑"))
    }

    func testYearlyExpirationCopyNamesTheSubscriptionTier() {
        let message = IAPPurchaseFailureCopy.message(
            for: IAPServiceError.transactionExpired,
            tier: .yearly
        )
        XCTAssertTrue(message.contains("年度订阅"))
        XCTAssertFalse(message.contains("购买"))
    }

    func testUnknownOrNetworkFailuresFallBackToGenericMessage() {
        XCTAssertEqual(IAPRestoreFailureCopy.message(for: nil), IAPRestoreFailureCopy.genericMessage)
        XCTAssertEqual(
            IAPRestoreFailureCopy.message(for: URLError(.notConnectedToInternet)),
            IAPRestoreFailureCopy.genericMessage
        )
        XCTAssertEqual(
            IAPRestoreFailureCopy.message(for: AuthServiceError.iapVerifyFailed(code: "APPLE_LOOKUP_FAILED", message: "x")),
            IAPRestoreFailureCopy.genericMessage
        )
    }
}

final class CloudSessionExpirationPolicyTests: XCTestCase {
    func testOnlyUnauthorizedHTTPResponsesInvalidateTheCloudSession() {
        XCTAssertTrue(
            CloudSessionFailurePolicy.shouldInvalidateSession(
                for: AuthServiceError.badStatus(401, #"{"ok":false,"error":"INVALID_TOKEN"}"#)
            )
        )
        XCTAssertTrue(
            CloudSessionFailurePolicy.shouldInvalidateSession(
                for: LedgerSyncError.badStatus(401, #"{"ok":false,"error":"INVALID_TOKEN"}"#)
            )
        )
        XCTAssertFalse(
            CloudSessionFailurePolicy.shouldInvalidateSession(
                for: AuthServiceError.badStatus(400, #"{"ok":false,"error":"INVALID_LEDGER_ITEM"}"#)
            )
        )
        XCTAssertFalse(
            CloudSessionFailurePolicy.shouldInvalidateSession(
                for: LedgerSyncError.badStatus(500, "database unavailable")
            )
        )
        XCTAssertFalse(
            CloudSessionFailurePolicy.shouldInvalidateSession(for: URLError(.notConnectedToInternet))
        )
    }

    func testSessionInvalidationPreservesLocalPreferencesAndClearsOnlyAccountState() {
        var current = AppSettings.default
        current.displayName = "保留的昵称"
        current.syncEnabled = true
        current.cloudUserId = "cloud-user-1"
        current.memberTier = "yearly"
        current.memberExpiresAt = "2026-12-31T00:00:00Z"
        current.petCompanionEnabled = false
        current.weatherCompanionEnabled = false
        current.colorThemeId = "xuzhang_default"

        let invalidated = CloudSessionInvalidationPolicy.invalidatedSettings(from: current)

        XCTAssertFalse(invalidated.syncEnabled)
        XCTAssertEqual(invalidated.cloudUserId, "")
        XCTAssertEqual(invalidated.memberTier, "free")
        XCTAssertNil(invalidated.memberExpiresAt)
        XCTAssertEqual(invalidated.displayName, current.displayName)
        XCTAssertEqual(invalidated.petCompanionEnabled, current.petCompanionEnabled)
        XCTAssertEqual(invalidated.weatherCompanionEnabled, current.weatherCompanionEnabled)
        XCTAssertEqual(invalidated.colorThemeId, current.colorThemeId)
        XCTAssertEqual(invalidated.backendBaseURL, AppSettings.productionBackendBaseURL)
    }
}

final class SettingsBackupCopyPolicyTests: XCTestCase {
    func testAllBackupAndOnlineOrganizationStatesUseNaturalCopy() {
        XCTAssertEqual(
            SettingsBackupSummaryPolicy.summary(syncEnabled: true, remoteOrganizationEnabled: true),
            "自动备份已开启 · 联网整理已开启"
        )
        XCTAssertEqual(
            SettingsBackupSummaryPolicy.summary(syncEnabled: true, remoteOrganizationEnabled: false),
            "自动备份已开启"
        )
        XCTAssertEqual(
            SettingsBackupSummaryPolicy.summary(syncEnabled: false, remoteOrganizationEnabled: true),
            "联网整理已开启"
        )
        XCTAssertEqual(
            SettingsBackupSummaryPolicy.summary(syncEnabled: false, remoteOrganizationEnabled: false),
            "仅保存在本机"
        )
    }
}

final class RecordSemanticDiningBoundaryTests: XCTestCase {
    func testPreciseSoupAndSoupBunPhrasesResolveToDining() {
        let titles = ["鸭血粉丝汤", "鸭血粉丝汤包", "灌汤包", "小笼汤包"]

        for title in titles {
            XCTAssertEqual(RecordSemanticLexicon.bestMatchingCategory(in: title), .dining, title)
            XCTAssertEqual(RecordSemanticLexicon.strongManualNoteCategory(of: title), .dining, title)

            let resolution = RecordDraftResolutionService.resolve(
                RecordDraftResolutionInput(
                    rawTitle: title,
                    fallbackCategory: .other,
                    amount: 18,
                    date: Date(timeIntervalSince1970: 1_784_240_000),
                    merchantBrandId: nil,
                    categoryLockedByUser: false,
                    userEditedTitle: true,
                    source: "test"
                )
            )
            XCTAssertEqual(resolution.category, .dining, title)
            XCTAssertTrue(resolution.trace.contains("category:semantic"), title)
        }
    }

    func testAmbiguousFanAndPackageWordsDoNotResolveToDining() {
        for title in ["明星粉丝见面会", "粉丝增长", "礼包", "文件包"] {
            XCTAssertNotEqual(RecordSemanticLexicon.bestMatchingCategory(in: title), .dining, title)
            XCTAssertNotEqual(RecordSemanticLexicon.strongManualNoteCategory(of: title), .dining, title)
        }
    }

    func testUserLockedNonDiningCategoryStillWinsOverPreciseDiningPhrase() {
        let resolution = RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: "鸭血粉丝汤包",
                fallbackCategory: .shopping,
                amount: 25,
                date: Date(timeIntervalSince1970: 1_784_240_000),
                merchantBrandId: nil,
                categoryLockedByUser: true,
                userEditedTitle: true,
                source: "test"
            )
        )

        XCTAssertEqual(resolution.category, .shopping)
        XCTAssertTrue(resolution.trace.contains("category:userLocked"))
    }

    func testFlowerClamAndChickenFeetPhrasesResolveToDining() {
        let titles = [
            "徐记花甲鸡爪｜宿豫店",
            "花甲",
            "花蛤",
            "蛤蜊拼盘",
            "贝类海鲜",
            "鸡爪",
            "凤爪",
        ]

        for title in titles {
            XCTAssertEqual(RecordSemanticLexicon.bestMatchingCategory(in: title), .dining, title)
            XCTAssertEqual(RecordSemanticLexicon.strongManualNoteCategory(of: title), .dining, title)
        }
    }

    func testManualCategoryChangePreservesTheUsersOriginalTitle() {
        let title = "徐记花甲鸡爪｜宿豫店"
        XCTAssertEqual(
            RecordEditCategoryMutationPolicy.titleAfterSelectingCategory(
                currentTitle: title,
                category: .dining
            ),
            title
        )
    }

    func testSaturdayLateDiningNeedsExplicitWorkEvidenceBeforeSayingOvertime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let saturdayNight = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 8,
            day: 22,
            hour: 23
        ))!

        let neutral = HomeItem.lateNightDiningEmotionTag(
            title: "晚归路上的一口热食",
            date: saturdayNight
        )
        let explicitWork = HomeItem.lateNightDiningEmotionTag(
            title: "加班后的一口热食",
            date: saturdayNight
        )

        XCTAssertEqual(neutral, "晚归时吃点东西")
        XCTAssertFalse(neutral?.contains("加班") == true)
        XCTAssertEqual(explicitWork, "加班后的热食记下")
    }
}

final class InsuranceClassificationBoundaryTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: day,
            hour: hour
        ))!
    }

    func testMedicalInsurancePremiumUsesOtherCategoryAndSpecificCopy() {
        let title = "2026.9月保费缴清-好医保·长期医疗"
        XCTAssertEqual(RecordSemanticLexicon.bestMatchingCategory(in: title), .other)
        XCTAssertEqual(RecordSemanticLexicon.strongManualNoteCategory(of: title), .other)

        let resolution = RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: title,
                fallbackCategory: .daily,
                amount: 32.71,
                date: date(day: 10),
                merchantBrandId: nil,
                categoryLockedByUser: false,
                userEditedTitle: false,
                source: "ocr"
            )
        )
        XCTAssertEqual(resolution.category, .other)
        XCTAssertEqual(resolution.emotionTag, "保障安排记下")
        XCTAssertEqual(
            OCRCategoryEvidencePolicy.resolve(
                title: "保险",
                rawText: title,
                fallback: .daily
            ),
            .other
        )
    }

    func testLegacyInsuranceMisclassifiedAsDailyDoesNotCreateSupplyLifeMark() {
        let legacy = HomeItem(
            title: "保险",
            amount: 32.71,
            category: .daily,
            createdAt: date(day: 10, hour: 10),
            emotionTag: "清洁纸巾一起补"
        )
        XCTAssertEqual(legacy.displayEmotionTag, "保障安排记下")

        let marks = LifeMarkService.aggregates(
            for: [legacy],
            allItems: [legacy],
            isMember: true,
            limit: 12
        )
        XCTAssertFalse(marks.contains { $0.id == "daily_supply" || $0.id == "groceries" })
    }

    func testGenuineDailySupplyStillCreatesTheExistingLifeMark() {
        let supply = HomeItem(
            title: "超市买菜",
            amount: 48,
            category: .daily,
            createdAt: date(day: 11, hour: 18),
            emotionTag: "超市买菜和家用"
        )
        let marks = LifeMarkService.aggregates(
            for: [supply],
            allItems: [supply],
            isMember: true,
            limit: 12
        )
        XCTAssertTrue(marks.contains { $0.id == "daily_supply" })
    }
}

final class DiningCopyEvidencePolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    func testBrandOnlyLawsonUsesNeutralStableVarietyWithoutInventingFood() {
        let outputs = (0..<8).map { index in
            let input = RecordDraftResolutionInput(
                rawTitle: "罗森",
                fallbackCategory: .dining,
                amount: 4.2 + Double(index),
                date: date(day: 20 + index, minute: index),
                merchantBrandId: "lawson",
                categoryLockedByUser: false,
                userEditedTitle: false,
                source: "test"
            )
            let first = RecordDraftResolutionService.resolve(input)
            let relaunched = RecordDraftResolutionService.resolve(input)
            XCTAssertEqual(first.emotionTag, relaunched.emotionTag)
            return first.emotionTag
        }

        XCTAssertGreaterThan(Set(outputs).count, 1)
        let unsupportedClaims = ["热食", "热乎", "一口热的", "饭团", "便当", "关东煮", "咖啡", "饮料", "小食", "拿点吃的"]
        XCTAssertTrue(outputs.allSatisfy { output in
            unsupportedClaims.allSatisfy { !output.contains($0) }
        })
        XCTAssertTrue(outputs.allSatisfy { $0.contains("罗森") || $0 == "便利店这一笔" })
    }

    func testExplicitConvenienceFoodEvidenceKeepsTheSpecificNeutralLabel() {
        let cases = [
            (title: "罗森关东煮", expected: "关东煮"),
            (title: "罗森便当", expected: "便当"),
            (title: "罗森饭团", expected: "饭团"),
            (title: "罗森咖啡", expected: "咖啡"),
        ]

        for (index, sample) in cases.enumerated() {
            let output = NarrativeCopyResolver.resolveEmotionTag(
                context: NarrativeCopyResolver.Context(
                    brandId: "lawson",
                    category: .dining,
                    amount: 12 + Double(index),
                    date: date(day: 20 + index),
                    seed: sample.title,
                    note: sample.title
                )
            )
            XCTAssertTrue(output.contains(sample.expected), "\(sample.title) should retain \(sample.expected): \(output)")
            XCTAssertFalse(output.contains("热食"))
            XCTAssertFalse(output.contains("热乎"))
            XCTAssertFalse(output.contains("一口热的"))
        }
    }

    func testLegacyUnsupportedHeatTagIsCorrectedFromTheRecordEvidence() {
        let item = HomeItem(
            id: UUID(uuidString: "F1000000-0000-0000-0000-000000000001")!,
            title: "罗森",
            amount: 4.2,
            category: .dining,
            createdAt: date(day: 27, hour: 18),
            emotionTag: "一口热食很及时",
            merchantBrandId: "lawson"
        )

        let first = item.displayEmotionTag
        let afterRelaunch = item.displayEmotionTag
        XCTAssertEqual(first, afterRelaunch)
        XCTAssertTrue(first.contains("罗森") || first == "便利店这一笔")
        XCTAssertFalse(first.contains("热食"))
        XCTAssertFalse(first.contains("热乎"))
        XCTAssertFalse(first.contains("饭团"))
        XCTAssertFalse(first.contains("便当"))
    }

    func testConvenienceBrandFallbackPoolsContainOnlyMerchantLevelFacts() {
        let forbiddenClaims = ["热食", "热乎", "一口热的", "饭团", "便当", "关东煮", "咖啡", "饮料", "小食", "拿点吃的"]
        for brandID in ["familymart", "lawson", "bianlifeng", "seveneleven", "meiyijia"] {
            let notes = MerchantBrandCatalog.definition(for: brandID)?.tiers.flatMap { $0.notes } ?? []
            XCTAssertFalse(notes.isEmpty)
            XCTAssertTrue(notes.allSatisfy { note in
                forbiddenClaims.allSatisfy { !note.contains($0) }
            }, "\(brandID) fallback tiers must not invent a product")
        }
    }

    func testDiningBrandFallbackPoolsDoNotAddUnsupportedTemperatureClaims() {
        let unsupportedTemperature = ["热食", "热乎", "口热的", "热餐", "热饭", "顿热的"]
        let diningNotes = MerchantBrandCatalog.definitions
            .filter { $0.category == .dining }
            .flatMap { $0.tiers }
            .flatMap { $0.notes }

        XCTAssertFalse(diningNotes.isEmpty)
        XCTAssertTrue(diningNotes.allSatisfy { note in
            unsupportedTemperature.allSatisfy { !note.contains($0) }
        })
    }
}

final class DiscoverEditorialPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 4, hour: 20))!
    }

    private func item(
        _ title: String,
        day: Int,
        hour: Int = 15,
        id: Int,
        category: HomeItem.Category = .dining,
        month: Int = 8
    ) -> HomeItem {
        HomeItem(
            id: UUID(uuidString: String(format: "E1000000-0000-0000-0000-%012d", id))!,
            title: title,
            amount: 18,
            category: category,
            createdAt: calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
        )
    }

    private func journeyRows() -> [HomeItem] {
        let specs: [(String, HomeItem.Category, Int, Int, String, String)] = [
            ("南京电车充电", .transport, 20, 8, "南京", "本城"),
            ("到宿迁的过路费", .transport, 20, 11, "宿迁", "外地"),
            ("宿迁电车充电", .transport, 21, 9, "宿迁", "外地"),
            ("到连云港的过路费", .transport, 22, 11, "连云港", "外地"),
            ("连云港吃海鲜", .dining, 22, 13, "连云港", "外地"),
            ("徐记花甲鸡爪｜宿豫店", .dining, 22, 22, "宿迁", "外地"),
            ("周日返南京过路费", .transport, 23, 17, "南京", "本城")
        ]
        return specs.enumerated().map { index, row in
            HomeItem(
                id: UUID(uuidString: String(format: "E1000000-0000-0000-0000-%012d", 1_001 + index))!,
                title: row.0,
                amount: 28,
                category: row.1,
                createdAt: calendar.date(from: DateComponents(
                    year: 2026, month: 8, day: row.2, hour: row.3
                ))!,
                memoryContext: HomeItem.MemoryContext(
                    weatherKind: nil,
                    temperatureCelsius: nil,
                    cityName: row.4,
                    semanticPlace: row.5
                )
            )
        }
    }

    func testEmptyDiscoverSnapshotDoesNotInventCards() {
        let snapshot = TraceSnapshotComputation.buildDiscoverSnapshot(
            items: [],
            sourceRevision: 7,
            now: now,
            calendar: calendar
        )

        XCTAssertTrue(snapshot.isEmpty)
        XCTAssertTrue(snapshot.recentDiscoveries.isEmpty)
        XCTAssertTrue(snapshot.lifePatterns.isEmpty)
        XCTAssertTrue(snapshot.sceneAssets.isEmpty)
        XCTAssertTrue(snapshot.echoes.isEmpty)
    }

    func testRecentDiscoveriesOnlyPublishAChangeWithEvidenceAndStableRanking() {
        let previous = [
            item("午后咖啡", day: 10, id: 1, month: 8),
            item("午后咖啡", day: 11, id: 2, month: 8)
        ]
        let recent = [
            item("午后咖啡", day: 27, id: 3, month: 8),
            item("午后咖啡", day: 28, id: 4, month: 8),
            item("午后咖啡", day: 29, id: 5, month: 8),
            item("晚间电影", day: 30, hour: 20, id: 6, category: .entertainment, month: 8)
        ]

        let first = TraceSnapshotComputation.buildDiscoverSnapshot(
            items: previous + recent,
            sourceRevision: 12,
            now: now,
            calendar: calendar
        )
        let second = TraceSnapshotComputation.buildDiscoverSnapshot(
            items: previous + recent,
            sourceRevision: 12,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(first, second)
        XCTAssertFalse(first.recentDiscoveries.isEmpty)
        XCTAssertTrue(first.recentDiscoveries.allSatisfy { $0.hasEvidence })
        XCTAssertTrue(first.recentDiscoveries.allSatisfy { $0.kind == .discovery })
        XCTAssertTrue(first.recentDiscoveries.contains { $0.title.contains("最近") })
        XCTAssertEqual(
            first.recentDiscoveries,
            first.recentDiscoveries.sorted { lhs, rhs in
                if lhs.editorialScore == rhs.editorialScore {
                    if lhs.latestDate == rhs.latestDate { return lhs.id < rhs.id }
                    return lhs.latestDate > rhs.latestDate
                }
                return lhs.editorialScore > rhs.editorialScore
            }
        )
        XCTAssertTrue(first.lifePatterns.contains { $0.title.contains("咖啡") })
        XCTAssertTrue(first.sceneAssets.contains { $0.summary.contains("累计") })
    }

    func testStablePresenceDoesNotBecomeARecentDiscovery() {
        let rows = [
            item("午后咖啡", day: 10, id: 11, month: 8),
            item("午后咖啡", day: 11, id: 12, month: 8),
            item("午后咖啡", day: 27, id: 13, month: 8),
            item("午后咖啡", day: 28, id: 14, month: 8)
        ]
        let snapshot = TraceSnapshotComputation.buildDiscoverSnapshot(
            items: rows,
            sourceRevision: 13,
            now: now,
            calendar: calendar
        )

        XCTAssertFalse(snapshot.recentDiscoveries.contains { $0.title.contains("咖啡") })
        XCTAssertTrue(snapshot.lifePatterns.contains { $0.title.contains("咖啡") })
    }

    func testDiscoverPublishesRecoveryWithCurrentAndHistoricalEvidence() {
        let rows = [
            item("午后咖啡", day: 1, id: 21, month: 8),
            item("午后咖啡", day: 27, id: 22, month: 8),
            item("午后咖啡", day: 28, id: 23, month: 8)
        ]

        let snapshot = TraceSnapshotComputation.buildDiscoverSnapshot(
            items: rows,
            sourceRevision: 14,
            now: now,
            calendar: calendar
        )

        let recovery = try! XCTUnwrap(
            snapshot.recentDiscoveries.first { $0.title.contains("又回来了") }
        )
        XCTAssertTrue(recovery.hasEvidence)
        XCTAssertTrue(recovery.evidenceItemIDs.contains(rows[0].id))
        XCTAssertTrue(recovery.evidenceItemIDs.contains(rows[2].id))
    }

    func testDiscoverPublishesDecreaseAndDisappearanceFromPriorEvidence() {
        let decreaseRows = [
            item("晚间电影", day: 10, hour: 20, id: 31, category: .entertainment, month: 8),
            item("晚间电影", day: 11, hour: 20, id: 32, category: .entertainment, month: 8),
            item("晚间电影", day: 12, hour: 20, id: 33, category: .entertainment, month: 8),
            item("晚间电影", day: 27, hour: 20, id: 34, category: .entertainment, month: 8)
        ]
        let decrease = TraceSnapshotComputation.buildDiscoverSnapshot(
            items: decreaseRows,
            sourceRevision: 15,
            now: now,
            calendar: calendar
        )
        let decreased = try! XCTUnwrap(
            decrease.recentDiscoveries.first { $0.title.contains("少了一些") }
        )
        XCTAssertTrue(decreased.hasEvidence)

        let disappearedRows = [
            item("晚间电影", day: 10, hour: 20, id: 41, category: .entertainment, month: 8),
            item("晚间电影", day: 11, hour: 20, id: 42, category: .entertainment, month: 8),
            item("晚间电影", day: 12, hour: 20, id: 43, category: .entertainment, month: 8)
        ]
        let disappeared = TraceSnapshotComputation.buildDiscoverSnapshot(
            items: disappearedRows,
            sourceRevision: 16,
            now: now,
            calendar: calendar
        )
        let ended = try! XCTUnwrap(
            disappeared.recentDiscoveries.first { $0.title.contains("暂时没再出现") }
        )
        XCTAssertEqual(Set(ended.evidenceItemIDs), Set(disappearedRows.map(\.id)))
    }

    func testDiscoverIgnoresRecordsOutsideTheBoundedRollingWindow() {
        let currentRows = [
            item("午后咖啡", day: 27, id: 51, month: 8),
            item("午后咖啡", day: 28, id: 52, month: 8)
        ]
        let oldRow = item("晚间电影", day: 1, hour: 20, id: 53, category: .entertainment, month: 1)
        let current = TraceSnapshotComputation.buildDiscoverSnapshot(
            items: currentRows,
            sourceRevision: 17,
            now: now,
            calendar: calendar
        )
        let withOld = TraceSnapshotComputation.buildDiscoverSnapshot(
            items: currentRows + [oldRow],
            sourceRevision: 17,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(current, withOld)
    }

    func testWeekendRoadTripDiscoveryIsFeaturedWithOneEvidenceBreakdown() {
        let rows: [HomeItem] = [
            item("南京电车充电", day: 29, hour: 8, id: 61, category: .transport, month: 8),
            item("宿迁过路费", day: 29, hour: 11, id: 62, category: .transport, month: 8),
            item("连云港海鲜", day: 30, hour: 13, id: 63, category: .dining, month: 8),
            item("宿迁夜宵", day: 31, hour: 22, id: 64, category: .dining, month: 8),
            item("返南京过路费", day: 1, hour: 17, id: 65, category: .transport, month: 9)
        ].enumerated().map { index, value in
            var row = value
            let city: String
            let place: String
            switch index {
            case 0:
                city = "南京"
                place = "本城"
            case 1, 3:
                city = "宿迁"
                place = "外地"
            case 2:
                city = "连云港"
                place = "外地"
            default:
                city = "南京"
                place = "本城"
            }
            row.memoryContext = HomeItem.MemoryContext(
                weatherKind: nil,
                temperatureCelsius: nil,
                cityName: city,
                semanticPlace: place
            )
            return row
        }

        let snapshot = TraceSnapshotComputation.buildDiscoverSnapshot(
            items: rows,
            sourceRevision: 61,
            now: now,
            calendar: calendar
        )
        let card = try! XCTUnwrap(
            snapshot.recentDiscoveries.first { $0.title == "周末跨城自驾" }
        )
        XCTAssertEqual(
            (snapshot.recentDiscoveries + snapshot.sceneAssets)
                .filter { $0.id == card.id }
                .count,
            1
        )

        XCTAssertTrue(card.isFeatured)
        XCTAssertEqual(card.evidenceSummary?.total, card.evidenceItemIDs.count)
        // 南京电车充电 is a refuelling node on the route itself, so it belongs to the
        // road evidence: the trip is certified by the tolls, and the charge is part
        // of driving them. Only the two tolls plus that charge are road, the two
        // dining rows are away-from-home activity, and nothing is left over.
        XCTAssertEqual(card.evidenceSummary?.road, 3)
        XCTAssertEqual(card.evidenceSummary?.activity, 2)
        XCTAssertEqual(card.evidenceSummary?.other, 0)
        XCTAssertEqual(card.coreEvidenceItemIDs?.count, 5)
        XCTAssertEqual(card.boundaryEvidenceItemIDs?.count, 0)
        XCTAssertEqual(
            Set((card.coreEvidenceItemIDs ?? []) + (card.boundaryEvidenceItemIDs ?? [])),
            Set(card.evidenceItemIDs)
        )
        XCTAssertTrue(card.evidenceDisplayText.contains("共 5 笔记录"))
        XCTAssertTrue(card.evidenceDisplayText.contains("3 笔道路"))
        XCTAssertTrue(card.evidenceDisplayText.contains("2 笔异地活动"))
        XCTAssertFalse(card.evidenceDisplayText.contains("路线边界记录"))
    }

    func testDiscoverDetailEvidenceResolutionDropsDeletedRecordsAndKeepsOrder() {
        let rows = [
            item("第一笔", day: 27, id: 71),
            item("第二笔", day: 28, id: 72),
            item("第三笔", day: 29, id: 73)
        ]
        let resolved = DiscoverEvidenceResolutionPolicy.resolve(
            evidenceIDs: [rows[2].id, rows[0].id, rows[1].id],
            in: [rows[0], rows[2]]
        )

        XCTAssertEqual(resolved.map(\.id), [rows[2].id, rows[0].id])
        XCTAssertFalse(resolved.contains { $0.id == rows[1].id })
    }

    func testDiscoverMemoryWallExpandsFewPhotosWithEachCoverFirst() {
        let first = HomeItem(
            id: UUID(uuidString: "E1000000-0000-0000-0000-000000000081")!,
            title: "三张照片",
            amount: 18,
            category: .dining,
            createdAt: now,
            memoryImageDatas: [Data([0]), Data([1]), Data([2])],
            coverMemoryImageIndex: 2
        )
        let second = HomeItem(
            id: UUID(uuidString: "E1000000-0000-0000-0000-000000000082")!,
            title: "两张照片",
            amount: 20,
            category: .shopping,
            createdAt: now,
            memoryImageDatas: [Data([3]), Data([4])],
            coverMemoryImageIndex: 1
        )

        XCTAssertEqual(
            DiscoverMemoryWallPhotoPolicy.photos(from: [first, second]),
            [
                DiscoverMemoryWallPhoto(itemID: first.id, imageIndex: 2),
                DiscoverMemoryWallPhoto(itemID: first.id, imageIndex: 0),
                DiscoverMemoryWallPhoto(itemID: first.id, imageIndex: 1),
                DiscoverMemoryWallPhoto(itemID: second.id, imageIndex: 1),
                DiscoverMemoryWallPhoto(itemID: second.id, imageIndex: 0)
            ]
        )
    }

    func testDiscoverMemoryWallUsesOnePreferredPhotoPerRecordWhenPhotoCountIsLarge() {
        let first = HomeItem(
            id: UUID(uuidString: "E1000000-0000-0000-0000-000000000083")!,
            title: "五张照片",
            amount: 18,
            category: .dining,
            createdAt: now,
            memoryImageDatas: (0..<5).map { Data([UInt8($0)]) },
            coverMemoryImageIndex: 3
        )
        let second = HomeItem(
            id: UUID(uuidString: "E1000000-0000-0000-0000-000000000084")!,
            title: "四张照片",
            amount: 20,
            category: .shopping,
            createdAt: now,
            memoryImageDatas: (5..<9).map { Data([UInt8($0)]) },
            coverMemoryImageIndex: 1
        )

        XCTAssertEqual(DiscoverMemoryWallPhotoPolicy.expandedPhotoLimit, 8)
        XCTAssertEqual(
            DiscoverMemoryWallPhotoPolicy.photos(from: [first, second]),
            [
                DiscoverMemoryWallPhoto(itemID: first.id, imageIndex: 3),
                DiscoverMemoryWallPhoto(itemID: second.id, imageIndex: 1)
            ]
        )
    }

    func testJourneyHierarchySuppressesOnlyTheDuplicateLegacyNarrative() {
        let itemID = UUID(uuidString: "E1000000-0000-0000-0000-000000000085")!
        let journey = LifeJourneyFact(
            id: "journey:test",
            routeCities: ["南京", "宿迁", "南京"],
            evidenceItemIDs: [itemID],
            roadEvidenceItemIDs: [itemID],
            activityEvidenceItemIDs: [],
            startDate: now,
            endDate: now,
            homeCity: "南京",
            isRoadTrip: true,
            isClosedLoop: true,
            containsWeekend: true,
            evidenceLabels: ["过路费"]
        )
        let duplicate = LifeInsightResult(
            leadQuestion: journey.label,
            teaser: journey.line,
            previewLine: journey.line,
            fullLines: [journey.line],
            questionChips: [],
            periodName: "生活线索",
            theme: .relation
        )
        let unrelated = LifeInsightResult(
            leadQuestion: "另一条线索",
            teaser: "另一条线索",
            previewLine: "另一条线索",
            fullLines: [],
            questionChips: [],
            periodName: "生活线索",
            theme: .change
        )
        let canonicalQuestionOnly = LifeInsightResult(
            leadQuestion: "这次周末跨城自驾是怎么串起来的",
            teaser: "另一句证据说明",
            previewLine: "另一句证据说明",
            fullLines: [],
            questionChips: [],
            periodName: "生活线索",
            theme: .relation
        )

        XCTAssertTrue(
            DiscoverJourneyHierarchyPolicy.suppressesLegacyNarrative(
                journeyFact: journey,
                insight: duplicate,
                hasPrimaryDiscoverCard: true
            )
        )
        XCTAssertFalse(
            DiscoverJourneyHierarchyPolicy.suppressesLegacyNarrative(
                journeyFact: journey,
                insight: unrelated,
                hasPrimaryDiscoverCard: true
            )
        )
        XCTAssertFalse(
            DiscoverJourneyHierarchyPolicy.suppressesLegacyNarrative(
                journeyFact: journey,
                insight: duplicate,
                hasPrimaryDiscoverCard: false
            )
        )
        XCTAssertTrue(
            DiscoverJourneyHierarchyPolicy.suppressesLegacyNarrative(
                journeyFact: journey,
                insight: duplicate,
                hasPrimaryDiscoverCard: false,
                hasJourneyAsset: true
            )
        )
        XCTAssertTrue(
            DiscoverJourneyHierarchyPolicy.suppressesLegacyNarrative(
                journeyFact: journey,
                insight: canonicalQuestionOnly,
                hasPrimaryDiscoverCard: false,
                hasJourneyAsset: true
            )
        )
        XCTAssertTrue(
            DiscoverJourneyHierarchyPolicy.suppressesLegacyNarrative(
                journeyFact: journey,
                insight: unrelated,
                hasPrimaryDiscoverCard: false,
                hasJourneyAsset: true,
                leadSignalID: journey.id
            )
        )
        // A legacy relation snapshot can carry the Journey copy while its
        // planner identity is stale. The explicit Journey text still makes
        // this the duplicate evidence card, so the durable asset remains the
        // only entry point.
        XCTAssertTrue(
            DiscoverJourneyHierarchyPolicy.suppressesLegacyNarrative(
                journeyFact: journey,
                insight: duplicate,
                hasPrimaryDiscoverCard: false,
                hasJourneyAsset: true,
                leadSignalID: "change:coffee:up"
            )
        )
        XCTAssertFalse(
            DiscoverJourneyHierarchyPolicy.suppressesLegacyNarrative(
                journeyFact: journey,
                insight: unrelated,
                hasPrimaryDiscoverCard: false,
                hasJourneyAsset: true,
                leadSignalID: "change:coffee:up"
            )
        )
    }

    func testHighValueLifeAssetsKeepOneJourneyNarrativeAndAStableDetailEntry() {
        let journeyID = UUID(uuidString: "E1000000-0000-0000-0000-000000000089")!
        let journey = LifeJourneyFact(
            id: "journey:asset-entry",
            routeCities: ["南京", "宿迁", "南京"],
            evidenceItemIDs: [journeyID],
            roadEvidenceItemIDs: [journeyID],
            activityEvidenceItemIDs: [],
            startDate: now,
            endDate: now,
            homeCity: "南京",
            isRoadTrip: true,
            isClosedLoop: true,
            containsWeekend: true,
            evidenceLabels: ["过路费"]
        )
        let journeyCard = DiscoverCard(
            id: "discover:journey:\(journey.id)",
            kind: .discovery,
            title: journey.label,
            summary: journey.line,
            evidenceItemIDs: journey.evidenceItemIDs,
            novelty: 98,
            confidence: 96,
            storyValue: 98,
            latestDate: now,
            isFeatured: true,
            evidenceSummary: DiscoverEvidenceSummary(total: 1, road: 1),
            coreEvidenceItemIDs: [journeyID],
            boundaryEvidenceItemIDs: []
        )
        let journeyMark = LifeMarkAggregate(
            id: journey.id,
            kind: .context,
            access: .member,
            label: journey.label,
            title: journey.label,
            detail: journey.line,
            category: .transport,
            count: 1,
            total: 18,
            latestDate: now,
            itemIDs: [journeyID],
            queryHint: "这段路怎么串起来的？",
            priority: 2
        )
        let milestone = LifeMarkAggregate(
            id: "coffee_first",
            kind: .milestone,
            access: .member,
            label: "第一次咖啡",
            title: "第一次咖啡",
            detail: "第一次被记下，之后可以回看当时的记录。",
            category: .dining,
            count: 1,
            total: 20,
            latestDate: now,
            itemIDs: [journeyID],
            queryHint: "第一次咖啡是哪天？",
            priority: 4
        )
        let ordinaryScene = LifeMarkAggregate(
            id: "coffee_drink",
            kind: .scene,
            access: .free,
            label: "咖啡饮品",
            title: "咖啡饮品",
            detail: "已经出现 3 次。",
            category: .dining,
            count: 3,
            total: 60,
            latestDate: now,
            itemIDs: [journeyID],
            queryHint: "最近咖啡饮品是哪几次？",
            priority: 18
        )

        XCTAssertTrue(
            TraceLifeMarkDetailPolicy.isJourneyAsset(
                journeyMark,
                journeyFact: journey
            )
        )
        XCTAssertEqual(
            TraceLifeMarkDetailPolicy.detailCard(for: journeyMark, journeyCard: journeyCard),
            journeyCard
        )
        XCTAssertNotNil(TraceLifeMarkDetailPolicy.detailCard(for: milestone))
        XCTAssertNil(TraceLifeMarkDetailPolicy.detailCard(for: ordinaryScene))
    }

    func testOlderCertifiedJourneyRemainsAStableSceneAssetAfterRecentWindow() {
        let journeyIDs = [
            UUID(uuidString: "E1000000-0000-0000-0000-000000000090")!,
            UUID(uuidString: "E1000000-0000-0000-0000-000000000091")!,
            UUID(uuidString: "E1000000-0000-0000-0000-000000000092")!
        ]
        let rows = [
            item("南京出发", day: 21, hour: 8, id: 90, category: .transport),
            item("连云港海鲜", day: 22, hour: 13, id: 91, category: .dining),
            item("返南京过路费", day: 23, hour: 17, id: 92, category: .transport)
        ]
        let oldNow = calendar.date(from: DateComponents(year: 2026, month: 9, day: 8, hour: 20))!
        let journey = LifeJourneyFact(
            id: "journey:older-scene-asset",
            routeCities: ["南京", "连云港", "南京"],
            evidenceItemIDs: journeyIDs,
            roadEvidenceItemIDs: [journeyIDs[0], journeyIDs[2]],
            activityEvidenceItemIDs: [journeyIDs[1]],
            startDate: rows[0].createdAt,
            endDate: rows[2].createdAt,
            homeCity: "南京",
            isRoadTrip: true,
            isClosedLoop: true,
            containsWeekend: true,
            evidenceLabels: ["过路费", "异地餐饮"]
        )

        let snapshot = TraceSnapshotComputation.buildDiscoverSnapshot(
            items: rows,
            sourceRevision: 93,
            now: oldNow,
            calendar: calendar,
            journeyFact: journey
        )
        let journeyCardID = "discover:journey:\(journey.id)"
        XCTAssertFalse(snapshot.recentDiscoveries.contains { $0.id == journeyCardID })
        XCTAssertEqual(snapshot.sceneAssets.filter { $0.id == journeyCardID }.count, 1)
        let card = try! XCTUnwrap(snapshot.sceneAssets.first { $0.id == journeyCardID })
        XCTAssertEqual(card.kind, .asset)
        XCTAssertTrue(card.isFeatured)
        XCTAssertEqual(Set(card.evidenceItemIDs), Set(journeyIDs))
        XCTAssertEqual(card.evidenceSummary?.total, journeyIDs.count)
    }

    func testDiscoverEditorialTitlesSeparatePatternsFromAssets() {
        let commute = DiscoverCard(
            id: "discover:pattern:transport",
            kind: .pattern,
            title: "通勤出行",
            summary: "",
            evidenceItemIDs: [],
            novelty: 1,
            confidence: 1,
            storyValue: 1,
            latestDate: .now
        )
        let coffeeAsset = DiscoverCard(
            id: "discover:asset:dining",
            kind: .asset,
            title: "咖啡饮品这条线索在成长",
            summary: "",
            evidenceItemIDs: [],
            novelty: 1,
            confidence: 1,
            storyValue: 1,
            latestDate: .now
        )
        XCTAssertEqual(commute.editorialTitle, "通勤模式")
        XCTAssertEqual(coffeeAsset.editorialTitle, "咖啡习惯正在形成")
    }

    func testAllJourneyFactsKeepsPrimaryCompatibilityOrdering() {
        let rows = journeyRows()
        let all = LifeJourneyFactService.allFacts(in: rows, calendar: calendar)
        XCTAssertFalse(all.isEmpty)
        XCTAssertEqual(all.first, LifeJourneyFactService.primaryFact(in: rows, calendar: calendar))
        XCTAssertEqual(Set(all.map { $0.id }).count, all.count)
    }

    func testDiscoverEchoNeedsCurrentAndHistoricalEvidenceOutsideTheJourney() {
        let journeyID = UUID(uuidString: "E1000000-0000-0000-0000-000000000086")!
        let currentID = UUID(uuidString: "E1000000-0000-0000-0000-000000000087")!
        let historicalID = UUID(uuidString: "E1000000-0000-0000-0000-000000000088")!

        XCTAssertNil(
            DiscoverEchoEvidencePolicy.independentEvidence(
                currentItemIDs: [journeyID],
                historicalItemIDs: [historicalID],
                excluding: Set([journeyID])
            )
        )
        XCTAssertNil(
            DiscoverEchoEvidencePolicy.independentEvidence(
                currentItemIDs: [currentID],
                historicalItemIDs: [journeyID],
                excluding: Set([journeyID])
            )
        )
        XCTAssertEqual(
            DiscoverEchoEvidencePolicy.independentEvidence(
                currentItemIDs: [journeyID, currentID],
                historicalItemIDs: [historicalID],
                excluding: Set([journeyID])
            )?.allItemIDs,
            [currentID, historicalID]
        )
    }

    func testDiscoverMemoryWallUsesStableEditorialRhythmInsteadOfAUniformGrid() {
        XCTAssertTrue(DiscoverMemoryWallLayoutPolicy.rows(for: 0).isEmpty)

        let one = DiscoverMemoryWallLayoutPolicy.rows(for: 1)
        XCTAssertEqual(one.map(\.kind), [.hero])
        XCTAssertEqual(one.flatMap(\.indices), [0])

        let two = DiscoverMemoryWallLayoutPolicy.rows(for: 2)
        XCTAssertEqual(two.map(\.kind), [.pair])
        XCTAssertEqual(two.flatMap(\.indices), [0, 1])

        let three = DiscoverMemoryWallLayoutPolicy.rows(for: 3)
        XCTAssertEqual(three.map(\.kind), [.hero, .pair])
        XCTAssertEqual(three.flatMap(\.indices), [0, 1, 2])

        let six = DiscoverMemoryWallLayoutPolicy.rows(for: 6)
        XCTAssertEqual(six.map(\.kind), [.hero, .pair, .pair])
        XCTAssertEqual(six.flatMap(\.indices), Array(0..<6))

        let many = DiscoverMemoryWallLayoutPolicy.rows(for: 9)
        XCTAssertEqual(many.flatMap(\.indices), Array(0..<9))
        XCTAssertEqual(Set(many.flatMap(\.indices)).count, 9)
        XCTAssertEqual(many, DiscoverMemoryWallLayoutPolicy.rows(for: 9))
    }
}

final class DiningFoodContextRegressionTests: XCTestCase {
    private func date(day: Int = 17, hour: Int = 8, minute: Int = 30) -> Date {
        Calendar.current.date(from: DateComponents(
            year: 2026, month: 9, day: day, hour: hour, minute: minute
        ))!
    }

    private func tag(_ title: String, at date: Date, variant: Int = 0, brand: String? = nil) -> String {
        NarrativeCopyResolver.resolveEmotionTag(context: .init(
            brandId: brand, category: .dining, amount: 12, date: date,
            seed: title + "|choice:\(variant)", note: title
        ))
    }

    private func resolution(_ title: String, at date: Date) -> RecordDraftResolution {
        RecordDraftResolutionService.resolve(.init(
            rawTitle: title, fallbackCategory: .dining, amount: 12, date: date,
            merchantBrandId: nil, categoryLockedByUser: false,
            userEditedTitle: true, source: "test"
        ))
    }

    func testSeparateFoodsNeverBorrowAnotherFoodNameAcrossSeeds() {
        let foods = ["馄饨", "饺子", "锅贴", "生煎"]
        for food in foods {
            for hour in [8, 12, 18, 23] {
                let outputs = (0..<32).map { tag(food, at: date(hour: hour), variant: $0) }
                XCTAssertGreaterThan(Set(outputs).count, 1, food)
                for output in outputs {
                    XCTAssertTrue(output.contains(food), output)
                    XCTAssertTrue(foods.filter { $0 != food }.allSatisfy { !output.contains($0) }, output)
                }
            }
        }
    }

    func testWeekdayAndWeekendBreakfastDoNotInventWork() {
        for day in [17, 19] {
            for variant in 0..<24 {
                let output = tag("馄饨", at: date(day: day), variant: variant)
                XCTAssertTrue(output.contains("馄饨") && output.contains("早餐"), output)
                XCTAssertTrue(["上班", "工作", "通勤", "热乎", "热食"].allSatisfy { !output.contains($0) }, output)
            }
        }
    }

    func testBreakfastInferenceUsesOnlyFiveThroughNineFiftyNine() {
        let cases = [(4, 59, false), (5, 0, true), (9, 59, true), (10, 0, false)]
        for (hour, minute, breakfast) in cases {
            let output = tag("馄饨", at: date(hour: hour, minute: minute))
            XCTAssertEqual(output.contains("早餐"), breakfast, output)
        }
    }

    func testExplicitMealFactsWinOverTheMorningClock() {
        for meal in ["午饭", "晚饭", "夜宵"] {
            for variant in 0..<24 {
                let output = tag(meal + "馄饨", at: date(), variant: variant)
                XCTAssertTrue(output.contains(meal) && output.contains("馄饨"), output)
                XCTAssertFalse(output.contains("早餐"), output)
            }
        }
    }

    func testBackfilledBreakfastRemainsBreakfastAtNight() {
        for hour in [18, 23] {
            let output = tag("早餐馄饨", at: date(hour: hour))
            XCTAssertTrue(output.contains("早餐") && output.contains("馄饨"), output)
            let item = HomeItem(title: "早餐馄饨", amount: 12, category: .dining,
                                createdAt: date(hour: hour), emotionTag: output)
            XCTAssertEqual(item.displayEmotionTag, output)
        }
    }

    func testConflictingExplicitMealsStayFoodSpecificWithoutGuessingAMeal() {
        let output = tag("早餐午饭馄饨", at: date())
        XCTAssertTrue(output.contains("馄饨"))
        XCTAssertFalse(output.contains("早餐") || output.contains("午饭"))
    }

    func testBeforeWorkExpressionRequiresExplicitEvidenceAndBreakfastContext() {
        for day in [17, 19] {
            let output = tag("上班前吃馄饨", at: date(day: day))
            XCTAssertTrue(output.contains("上班前") && output.contains("早餐"), output)
            XCTAssertFalse(tag("公司馄饨", at: date(day: day)).contains("上班前"))
            XCTAssertFalse(tag("上班前午饭馄饨", at: date(day: day)).contains("早餐"))
        }
    }

    func testExplicitWontonWinsOverCloudDumplingBrandCue() {
        for variant in 0..<24 {
            let output = tag("袁记云饺馄饨", at: date(), variant: variant, brand: "yuanjiyunjiao")
            XCTAssertTrue(output.contains("馄饨") && output.contains("早餐"), output)
            XCTAssertFalse(output.contains("饺子") || output.contains("水饺"), output)
        }
    }

    func testStrongLateWorkAndNightMarketContextsKeepTheirExistingPriority() {
        for title in ["加班馄饨", "晚归馄饨", "夜宵加班馄饨", "夜市馄饨"] {
            let at = date(hour: 23)
            XCTAssertNil(DiningCopyEvidencePolicy.contextualFoodEmotionTag(evidence: title, date: at, seed: title))
            XCTAssertEqual(tag(title, at: at), HomeItem.lateNightDiningEmotionTag(title: title, date: at), title)
        }
    }

    func testContextualFoodPolicyDoesNotExtendToOtherFoodsOrCategories() {
        for title in ["咖啡", "牛肉面", "罗森", "袁记云饺"] {
            XCTAssertNil(DiningCopyEvidencePolicy.contextualFoodEmotionTag(evidence: title, date: date(), seed: title))
        }
        for category in [HomeItem.Category.shopping, .other] {
            let output = NarrativeCopyResolver.resolveEmotionTag(context: .init(
                brandId: nil, category: category, amount: 12, date: date(), seed: "馄饨", note: "馄饨"
            ))
            XCTAssertFalse(output.contains("馄饨") || output.contains("早餐"), output)
        }
    }

    func testDirectGenericAndRefinedPathsAlsoKeepBreakfastAndFoodIdentity() {
        let generic = DiningCopyEvidencePolicy.genericEmotionTag(evidence: "馄饨", date: date(), seed: "馄饨")
        let refined = HomeItem.refinedEmotionTag(title: "馄饨", category: .dining, amount: 12, date: date()) ?? ""
        for output in [generic, refined] {
            XCTAssertTrue(output.contains("早餐") && output.contains("馄饨"), output)
            XCTAssertFalse(output.contains("饺子"), output)
        }
    }

    func testBreakfastCandidatesCycleAndSurviveSaveValidationAndDisplay() throws {
        for title in ["馄饨", "饺子", "锅贴", "生煎", "袁记云饺馄饨", "上班前的馄饨早餐"] {
            let at = date()
            let resolved = resolution(title, at: at)
            let scene = RecordEmotionSceneContext(
                title: resolved.title, category: resolved.category, amount: 12, date: at,
                merchantBrandID: resolved.merchantBrandId, scenePackID: nil, semanticAnchor: nil,
                previewEmotionTag: resolved.emotionTag, automaticEmotionTag: resolved.emotionTag
            )
            let choices = RecordEmotionScenePolicy.candidates(for: scene)
            XCTAssertGreaterThan(choices.count, 1, title)
            XCTAssertEqual(Set(choices).count, choices.count)
            let first = try XCTUnwrap(choices.first)
            var current = first
            for _ in choices.indices {
                current = try XCTUnwrap(RecordEmotionScenePolicy.next(after: current, candidates: choices))
            }
            XCTAssertEqual(current, first)
            let savedResolution = resolution(title, at: at)
            for choice in choices {
                XCTAssertTrue(choice.contains("早餐"), choice)
                XCTAssertEqual(RecordEmotionScenePolicy.validatedTag(
                    selection: .init(context: scene, tag: choice), resolution: savedResolution,
                    amount: 12, date: at, scenePackID: nil, automaticEmotionTag: savedResolution.emotionTag
                ), choice)
                let item = scene.item(emotionTag: choice)
                XCTAssertEqual(item.displayEmotionTag, choice)
                let baseline = scene.item(emotionTag: resolved.emotionTag)
                for isMember in [false, true] {
                    let originalMarks = LifeMarkService.aggregates(for: [baseline], allItems: [baseline],
                        isMember: isMember, now: at, limit: 100)
                    let chosenMarks = LifeMarkService.aggregates(for: [item], allItems: [item],
                        isMember: isMember, now: at, limit: 100)
                    XCTAssertEqual(Set(originalMarks.map(\.id)), Set(chosenMarks.map(\.id)), choice)
                }
            }
        }
    }

    func testLegacyFoodMismatchIsCorrectedOnlyOnDisplayWithoutMutation() {
        for (title, oldTag) in [("馄饨", "饺子这一餐"), ("饺子", "馄饨这一餐"), ("锅贴", "饺子这一餐"), ("生煎", "饺子这一餐")] {
            let item = HomeItem(title: title, amount: 12, category: .dining,
                                createdAt: date(), emotionTag: oldTag)
            let unchanged = item
            XCTAssertTrue(item.displayEmotionTag.contains(title), item.displayEmotionTag)
            XCTAssertEqual(item.displayEmotionTag, item.displayEmotionTag)
            XCTAssertEqual(item.emotionTag, oldTag)
            XCTAssertEqual(item, unchanged)
        }
    }

    func testMixedFoodsKeepEitherSupportedStoredLabel() {
        for emotion in ["馄饨这一餐", "饺子这一餐"] {
            let item = HomeItem(title: "馄饨和饺子", amount: 12, category: .dining,
                                createdAt: date(), emotionTag: emotion)
            XCTAssertEqual(item.displayEmotionTag, emotion)
        }
    }

    func testSameDraftRemainsDeterministicWithoutPersistedCyclingState() {
        let at = date()
        let first = resolution("馄饨", at: at)
        XCTAssertEqual(first.emotionTag, resolution("馄饨", at: at).emotionTag)
        let variants = (0..<24).map { tag("馄饨", at: at, variant: $0) }
        XCTAssertGreaterThan(Set(variants).count, 1)
    }
}

final class RecordEmotionScenePolicyTests: XCTestCase {
    @MainActor
    func testRecordSessionRetainsEmotionChoiceUntilDraftCommitReset() {
        let session = RecordTabSession()
        let scene = context()
        let selection = RecordEmotionSelection(context: scene, tag: scene.previewEmotionTag)
        session.emotionSelection = selection
        session.categoryGridExpanded = true
        session.categoryGridExpanded = false
        session.scenePackExpanded = true
        session.scenePackExpanded = false
        XCTAssertEqual(session.emotionSelection, selection)
        session.resetAfterCommittedDraft()
        XCTAssertNil(session.emotionSelection)
    }

    private var date: Date {
        Calendar.current.date(from: DateComponents(
            year: 2026, month: 9, day: 17, hour: 12
        ))!
    }

    private func context(
        title: String = "罗森",
        category: HomeItem.Category = .dining,
        amount: Double = 18,
        brandID: String? = "lawson",
        packID: String? = nil,
        anchor: String? = nil,
        preview: String? = nil,
        automatic: String? = nil
    ) -> RecordEmotionSceneContext {
        let generated = NarrativeCopyResolver.resolveEmotionTag(
            context: .init(
                brandId: brandID, category: category, amount: amount, date: date,
                seed: title, note: title, scenePackId: packID
            )
        )
        return RecordEmotionSceneContext(
            title: title, category: category, amount: amount, date: date,
            merchantBrandID: brandID, scenePackID: packID, semanticAnchor: anchor,
            previewEmotionTag: preview ?? generated,
            automaticEmotionTag: automatic ?? generated
        )
    }

    private func resolution(for context: RecordEmotionSceneContext) -> RecordDraftResolution {
        RecordDraftResolution(
            category: context.category, title: context.title,
            emotionTag: context.previewEmotionTag, merchantBrandId: context.merchantBrandID,
            source: "emotion-scene-test", trace: []
        )
    }

    private var factualFixtures: [RecordEmotionSceneContext] {
        [
            context(),
            context(title: "罗森咖啡"),
            context(title: "罗森饮料", amount: 8),
            context(title: "罗森便当"),
            context(title: "牛肉面", amount: 22, brandID: nil),
            context(title: "上班地铁", category: .transport, amount: 4, brandID: nil, packID: "commute"),
            context(title: "日常外套", category: .shopping, amount: 268, brandID: nil),
            context(title: "路亚鱼竿", category: .shopping, amount: 268, brandID: nil),
            context(title: "手机话费", category: .daily, amount: 50, brandID: nil, preview: "手机话费记下"),
            context(title: "医疗保险", category: .other, amount: 100, brandID: nil),
            context(title: "早餐记一笔", brandID: nil),
            context(title: "午餐记一笔", brandID: nil),
            context(title: "晚餐记一笔", amount: 18.5, brandID: nil),
            context(title: "今天晚饭", brandID: nil),
            context(title: "瑞幸咖啡", amount: 12.9, brandID: nil),
            context(title: "咖啡", brandID: nil),
            context(title: "奶茶", brandID: nil),
            context(title: "米粉", brandID: nil),
            lateCommuteContext(),
            lateCommuteContext(title: "这趟通勤记下", anchor: "晚间通勤"),
        ]
    }

    private func mealDate(hour: Int, minute: Int = 15) -> Date {
        Calendar.current.date(from: DateComponents(
            year: 2026, month: 9, day: 17, hour: hour, minute: minute
        ))!
    }

    private func mealResolution(
        _ title: String, at date: Date, generated: Bool, locked: Bool = false,
        source: String = "preview"
    ) -> RecordDraftResolution {
        RecordDraftResolutionService.resolve(.init(
            rawTitle: title, fallbackCategory: .dining, amount: 18.5, date: date,
            merchantBrandId: nil, categoryLockedByUser: locked,
            userEditedTitle: !generated, source: source,
            generatedNoteContext: generated ? .init(title: title, category: .dining) : nil
        ))
    }

    private func mealContext(
        _ resolution: RecordDraftResolution, at date: Date, anchor: String? = nil
    ) -> RecordEmotionSceneContext {
        RecordEmotionSceneContext(
            title: resolution.title, category: resolution.category, amount: 18.5, date: date,
            merchantBrandID: resolution.merchantBrandId, scenePackID: nil, semanticAnchor: anchor,
            previewEmotionTag: resolution.emotionTag, automaticEmotionTag: resolution.emotionTag
        )
    }

    private var supplementalMealTags: Set<String> {
        [
            "早餐这顿记下", "这顿早饭记下", "早餐留一笔",
            "午餐这顿记下", "这顿午饭记下", "午餐留一笔",
            "晚餐这顿记下", "这顿晚饭记下", "晚餐留一笔",
        ]
    }

    private func lateCommuteContext(
        title: String = "通勤路上", at date: Date? = nil,
        brandID: String? = nil, packID: String? = "commute", anchor: String? = nil,
        preview: String? = nil, automatic: String? = nil
    ) -> RecordEmotionSceneContext {
        let at = date ?? mealDate(hour: 22, minute: 48)
        let generated = NarrativeCopyResolver.resolveEmotionTag(context: .init(
            brandId: brandID, category: .transport, amount: 36, date: at,
            seed: title, note: title, scenePackId: packID
        ))
        return RecordEmotionSceneContext(
            title: title, category: .transport, amount: 36, date: at,
            merchantBrandID: brandID, scenePackID: packID, semanticAnchor: anchor,
            previewEmotionTag: preview ?? generated,
            automaticEmotionTag: automatic ?? generated
        )
    }

    func testNightCommuteScreenshotOffersStableCycleAndSavesChosenExpression() throws {
        let scene = lateCommuteContext()
        let expected = ["晚上这段通勤", "晚间这段通勤", "这趟晚间通勤记下", "晚上的通勤记一笔"]
        XCTAssertEqual(scene.previewEmotionTag, expected[0])
        let choices = RecordEmotionScenePolicy.candidates(for: scene)
        XCTAssertEqual(choices, expected)
        XCTAssertEqual(choices, RecordEmotionScenePolicy.candidates(for: scene))
        var current = try XCTUnwrap(choices.first)
        var visited: [String] = []
        for _ in choices.indices {
            visited.append(current)
            current = try XCTUnwrap(RecordEmotionScenePolicy.next(after: current, candidates: choices))
        }
        XCTAssertEqual(visited, expected)
        XCTAssertEqual(current, expected[0])

        for locked in [false, true] {
            let saved = RecordDraftResolutionService.resolve(.init(
                rawTitle: scene.title, fallbackCategory: .transport, amount: 36, date: scene.date,
                merchantBrandId: nil, categoryLockedByUser: locked, userEditedTitle: false,
                source: "manual", scenePackId: "commute",
                generatedNoteContext: .init(title: scene.title, category: .transport)
            ))
            XCTAssertEqual(saved.title, scene.title)
            XCTAssertEqual(saved.category, .transport)
            XCTAssertEqual(saved.emotionTag, expected[0])
            let automatic = RecordMemoryContextService.enhancedEmotionTag(input: .init(
                title: saved.title, category: saved.category, amount: 36, date: scene.date,
                baseEmotionTag: saved.emotionTag, weather: nil
            ))
            XCTAssertEqual(automatic, expected[0])
            for choice in choices {
                XCTAssertEqual(RecordEmotionScenePolicy.validatedTag(
                    selection: .init(context: scene, tag: choice), resolution: saved,
                    amount: 36, date: scene.date, scenePackID: "commute",
                    automaticEmotionTag: automatic
                ), choice)
                let item = scene.item(emotionTag: choice)
                XCTAssertEqual(item.displayEmotionTag, choice)
                XCTAssertEqual(HomeItem.lateWorkCommutePlaybackTitle(for: item), "晚上通勤路上")
                XCTAssertFalse(["上班", "下班", "雨", "雪", "地铁", "打车", "高铁", "机场"].contains {
                    choice.contains($0)
                })
            }
        }
    }

    func testNightCommuteSourceUsesSemanticSceneAndRejectsConflictingFacts() {
        for title in ["通勤路上", "这趟通勤记下", "晚间通勤花费"] {
            for hour in [0, 4, 21, 22, 23] {
                let scene = lateCommuteContext(title: title, at: mealDate(hour: hour), anchor: "通勤这一程")
                XCTAssertEqual(RecordEmotionCandidateSource.alternatives(for: scene).count, 3, title)
                XCTAssertGreaterThan(RecordEmotionScenePolicy.candidates(for: scene).count, 1, title)
            }
        }
        for hour in [5, 12, 20] {
            let scene = lateCommuteContext(
                at: mealDate(hour: hour), preview: "晚上这段通勤", automatic: "晚上这段通勤"
            )
            XCTAssertTrue(RecordEmotionCandidateSource.alternatives(for: scene).isEmpty)
        }
        let rejected = [
            lateCommuteContext(title: "上班通勤"),
            lateCommuteContext(title: "下班通勤"),
            lateCommuteContext(title: "雨天通勤"),
            lateCommuteContext(title: "雪天通勤"),
            lateCommuteContext(title: "咖啡通勤"),
            lateCommuteContext(title: "路上花费补上", preview: "晚上这段通勤", automatic: "晚上这段通勤"),
            lateCommuteContext(brandID: "lawson", preview: "晚上这段通勤", automatic: "晚上这段通勤"),
            lateCommuteContext(packID: "dining"),
            lateCommuteContext(anchor: "上班通勤"),
            lateCommuteContext(anchor: "下班通勤"),
            lateCommuteContext(anchor: "雨天通勤"),
            lateCommuteContext(anchor: "停车费"),
            lateCommuteContext(preview: "雨天通勤"),
            lateCommuteContext(automatic: "晚上通勤遇上雨"),
        ]
        for scene in rejected {
            XCTAssertTrue(RecordEmotionCandidateSource.alternatives(for: scene).isEmpty, scene.title)
        }
        let weekend = lateCommuteContext(at: Calendar.current.date(from: DateComponents(
            year: 2026, month: 9, day: 19, hour: 22, minute: 48
        ))!)
        // Existing weekend display correction stays authoritative; do not weaken
        // the display guard merely to expose a button for every transport note.
        XCTAssertTrue(RecordEmotionScenePolicy.candidates(for: weekend).isEmpty)
    }

    func testNightCommuteChoiceExpiresWithTimeWorkWeatherAndSceneChanges() throws {
        let scene = lateCommuteContext()
        let choice = try XCTUnwrap(RecordEmotionScenePolicy.candidates(for: scene).last)
        let selection = RecordEmotionSelection(context: scene, tag: choice)
        let changed = [
            lateCommuteContext(at: mealDate(hour: 12)),
            lateCommuteContext(title: "上班通勤"),
            lateCommuteContext(title: "下班通勤"),
            lateCommuteContext(title: "雨天通勤"),
            lateCommuteContext(packID: nil),
            lateCommuteContext(automatic: "晚上通勤遇上雨"),
        ]
        for newScene in changed {
            XCTAssertNil(RecordEmotionScenePolicy.validatedTag(
                selection: selection, resolution: resolution(for: newScene),
                amount: newScene.amount, date: newScene.date, scenePackID: newScene.scenePackID,
                automaticEmotionTag: newScene.automaticEmotionTag
            ))
        }
        XCTAssertNotEqual(scene, lateCommuteContext(anchor: "上班通勤"))
        XCTAssertNil(RecordEmotionScenePolicy.validatedTag(
            selection: selection, resolution: resolution(for: scene),
            amount: 37, date: scene.date, scenePackID: scene.scenePackID,
            automaticEmotionTag: scene.automaticEmotionTag
        ))
    }

    func testQuickDinnerAt1715OffersDeterministicCycleAndKeepsAutomaticDefault() throws {
        let date = mealDate(hour: 17)
        let resolved = mealResolution("晚餐记一笔", at: date, generated: true)
        let scene = mealContext(resolved, at: date, anchor: resolved.title)
        XCTAssertEqual(scene.amount, 18.5)
        XCTAssertEqual(resolved.emotionTag, "晚饭时间坐一会儿")
        let choices = RecordEmotionScenePolicy.candidates(for: scene)
        XCTAssertGreaterThan(choices.count, 1)
        XCTAssertLessThanOrEqual(choices.count, 6)
        XCTAssertEqual(choices, RecordEmotionScenePolicy.candidates(for: scene))
        XCTAssertEqual(choices.first, "晚饭时间坐一会儿")
        XCTAssertEqual(Set(choices).count, choices.count)
        var current = try XCTUnwrap(choices.first)
        var visited: [String] = []
        for _ in choices.indices {
            visited.append(current)
            current = try XCTUnwrap(RecordEmotionScenePolicy.next(after: current, candidates: choices))
        }
        XCTAssertEqual(visited, choices)
        XCTAssertEqual(current, choices.first)
        XCTAssertNil(RecordEmotionScenePolicy.validatedTag(
            selection: nil, resolution: resolved, amount: 18.5, date: date,
            scenePackID: nil, automaticEmotionTag: resolved.emotionTag
        ))
        XCTAssertEqual(scene.item(emotionTag: resolved.emotionTag).displayEmotionTag, resolved.emotionTag)
    }

    func testAllNineQuickMealTemplatesKeepGeneratedPreviewSaveAndDisplayConsistent() {
        let fixtures = [(8, "早餐先记下"), (12, "中午一顿饭"), (17, "晚饭时间坐一会儿")]
        var covered: Set<String> = []
        for (hour, expectedDefault) in fixtures {
            let date = mealDate(hour: hour)
            let titles = RecordQuickNotePolicy.templates(for: .dining, at: date)
            XCTAssertEqual(titles.count, 3)
            for title in titles {
                covered.insert(title)
                for locked in [false, true] {
                    let preview = mealResolution(title, at: date, generated: true, locked: locked)
                    let saved = mealResolution(title, at: date, generated: true, locked: locked, source: "manual")
                    let scene = mealContext(preview, at: date, anchor: title)
                    XCTAssertEqual(preview.title, title)
                    XCTAssertEqual(saved.title, title)
                    XCTAssertEqual(preview.category, .dining)
                    XCTAssertEqual(saved.category, .dining)
                    XCTAssertEqual(preview.emotionTag, expectedDefault)
                    XCTAssertEqual(saved.emotionTag, expectedDefault)
                    XCTAssertEqual(preview.merchantBrandId, saved.merchantBrandId)
                    XCTAssertTrue(saved.trace.contains(locked ? "category:userLocked" : "category:generatedDraft"))
                    let choices = RecordEmotionScenePolicy.candidates(for: scene)
                    XCTAssertGreaterThan(choices.count, 1, title)
                    XCTAssertLessThanOrEqual(choices.count, 6, title)
                    XCTAssertEqual(choices.first, expectedDefault, title)
                    for tag in choices {
                        XCTAssertEqual(RecordEmotionScenePolicy.validatedTag(
                            selection: .init(context: scene, tag: tag), resolution: saved,
                            amount: 18.5, date: date, scenePackID: nil,
                            automaticEmotionTag: saved.emotionTag
                        ), tag, title)
                        XCTAssertEqual(scene.item(emotionTag: tag).displayEmotionTag, tag, title)
                    }
                }
            }
        }
        XCTAssertEqual(covered.count, 9)
    }

    func testBareHandwrittenMealsUseTheSameChoicesAsTheirQuickTemplates() {
        let fixtures = [
            (8, "早餐记一笔", ["早餐", "早饭"]),
            (12, "午餐记一笔", ["午餐", "午饭", "中午"]),
            (17, "晚餐记一笔", ["晚餐", "晚饭"]),
        ]
        for (hour, quickTitle, handwrittenTitles) in fixtures {
            let date = mealDate(hour: hour)
            let generated = mealResolution(quickTitle, at: date, generated: true)
            let expected = RecordEmotionScenePolicy.candidates(for: mealContext(generated, at: date))
            XCTAssertGreaterThan(expected.count, 1)
            for title in handwrittenTitles {
                let saved = mealResolution(title, at: date, generated: false, source: "manual")
                let scene = mealContext(saved, at: date)
                XCTAssertEqual(saved.title, title)
                XCTAssertEqual(saved.emotionTag, generated.emotionTag)
                XCTAssertEqual(RecordEmotionScenePolicy.candidates(for: scene), expected, title)
                for tag in expected {
                    XCTAssertEqual(RecordEmotionScenePolicy.validatedTag(
                        selection: .init(context: scene, tag: tag), resolution: saved,
                        amount: 18.5, date: date, scenePackID: nil,
                        automaticEmotionTag: saved.emotionTag
                    ), tag, title)
                }
            }
        }
    }

    func testExplicitMealChoicesKeepMealEvidenceWhenClockIsInAnotherDayPeriod() {
        for (title, hour, expected) in [
            ("早餐", 19, "早餐先记下"),
            ("午饭", 19, "中午一顿饭"),
            ("晚餐", 8, "晚饭时间坐一会儿"),
        ] {
            let date = mealDate(hour: hour)
            let resolved = mealResolution(title, at: date, generated: false)
            let scene = mealContext(resolved, at: date)
            XCTAssertEqual(resolved.emotionTag, expected, title)
            let choices = RecordEmotionScenePolicy.candidates(for: scene)
            XCTAssertGreaterThan(choices.count, 1, title)
            XCTAssertEqual(choices.first, expected, title)
            for tag in choices {
                XCTAssertEqual(scene.item(emotionTag: tag).displayEmotionTag, tag, title)
            }
        }
        // Late dinner already has a night-specific automatic label; keep that boundary.
        let lateDate = mealDate(hour: 23)
        let lateDinner = mealResolution("晚餐", at: lateDate, generated: false)
        XCTAssertNotEqual(lateDinner.emotionTag, "晚饭时间坐一会儿")
        XCTAssertTrue(supplementalMealTags.isDisjoint(with: RecordEmotionScenePolicy.candidates(
            for: mealContext(lateDinner, at: lateDate)
        )))
    }

    func testMealAlternativesRequireBothCanonicalTagsAndDiningCategory() {
        let fixtures = [
            context(title: "晚餐", category: .daily, brandID: nil,
                    preview: "晚饭时间坐一会儿", automatic: "晚饭时间坐一会儿"),
            context(title: "晚餐", brandID: nil,
                    preview: "晚饭时间坐一会儿", automatic: "雨天通勤"),
            context(title: "晚餐", brandID: nil,
                    preview: "雨天通勤", automatic: "晚饭时间坐一会儿"),
            context(title: "晚餐", brandID: nil,
                    preview: "中午一顿饭", automatic: "中午一顿饭"),
            context(title: "晚餐", brandID: "lawson",
                    preview: "晚饭时间坐一会儿", automatic: "晚饭时间坐一会儿"),
        ]
        for scene in fixtures {
            XCTAssertTrue(supplementalMealTags.isDisjoint(with: RecordEmotionScenePolicy.candidates(for: scene)))
        }
    }

    func testMealAlternativesDoNotBroadenSpecificFoodBrandWeatherOrConflictingNotes() {
        let date = mealDate(hour: 17)
        for title in [
            "晚餐咖啡", "晚餐馄饨", "罗森晚餐", "加班晚餐", "雨天晚餐",
            "早餐晚餐", "午餐晚饭", "晚餐夜宵", "晚餐宵夜",
        ] {
            let resolved = mealResolution(title, at: date, generated: false)
            let scene = mealContext(resolved, at: date)
            XCTAssertTrue(supplementalMealTags.isDisjoint(with: RecordEmotionScenePolicy.candidates(for: scene)), title)
        }
    }

    func testMealAlternativesAllowSameMealAnchorAndRejectConcreteOrConflictingAnchors() {
        let date = mealDate(hour: 17)
        let resolved = mealResolution("晚餐记一笔", at: date, generated: true)
        let expected = RecordEmotionScenePolicy.candidates(for: mealContext(resolved, at: date))
        XCTAssertGreaterThan(expected.count, 1)
        for anchor in ["", "晚餐", "晚饭", "这顿晚饭先记下"] {
            let scene = mealContext(resolved, at: date, anchor: anchor)
            XCTAssertEqual(RecordEmotionScenePolicy.candidates(for: scene), expected, anchor)
        }
        for anchor in ["早餐", "午饭", "夜宵", "晚餐咖啡", "罗森", "雨天晚餐", "加班晚饭"] {
            let scene = mealContext(resolved, at: date, anchor: anchor)
            XCTAssertTrue(supplementalMealTags.isDisjoint(with: RecordEmotionScenePolicy.candidates(for: scene)), anchor)
        }
    }

    func testSelectedMealAlternativeCannotSurviveChangedDraftFacts() throws {
        let date = mealDate(hour: 17)
        let resolved = mealResolution("晚餐记一笔", at: date, generated: true)
        let scene = mealContext(resolved, at: date)
        let tag = try XCTUnwrap(RecordEmotionScenePolicy.next(
            after: scene.previewEmotionTag, candidates: RecordEmotionScenePolicy.candidates(for: scene)
        ))
        let selection = RecordEmotionSelection(context: scene, tag: tag)
        let changedTitle = mealResolution("午餐记一笔", at: date, generated: true, source: "manual")
        let mutations: [(RecordDraftResolution, Double, Date, String?, String)] = [
            (changedTitle, 18.5, date, nil, resolved.emotionTag),
            (resolved, 19, date, nil, resolved.emotionTag),
            (resolved, 18.5, date.addingTimeInterval(60), nil, resolved.emotionTag),
            (resolved, 18.5, date, "food", resolved.emotionTag),
            (resolved, 18.5, date, nil, "雨天通勤"),
        ]
        for (draft, amount, date, packID, automatic) in mutations {
            XCTAssertNil(RecordEmotionScenePolicy.validatedTag(
                selection: selection, resolution: draft, amount: amount, date: date,
                scenePackID: packID, automaticEmotionTag: automatic
            ))
        }
    }

    func testLockedLuckinAt1926CyclesAndSavesWithoutChangingDefaultOrCategoryLock() throws {
        let date = mealDate(hour: 19, minute: 26)
        func resolve(source: String) -> RecordDraftResolution {
            RecordDraftResolutionService.resolve(.init(
                rawTitle: "瑞幸咖啡", fallbackCategory: .dining, amount: 12.9, date: date,
                merchantBrandId: nil, categoryLockedByUser: true,
                userEditedTitle: true, source: source
            ))
        }
        let preview = resolve(source: "preview")
        let saved = resolve(source: "manual")
        let scene = RecordEmotionSceneContext(
            title: preview.title, category: preview.category, amount: 12.9, date: date,
            merchantBrandID: preview.merchantBrandId, scenePackID: nil, semanticAnchor: preview.title,
            previewEmotionTag: preview.emotionTag, automaticEmotionTag: saved.emotionTag
        )
        for resolved in [preview, saved] {
            XCTAssertEqual(resolved.title, "瑞幸咖啡")
            XCTAssertEqual(resolved.category, .dining)
            XCTAssertNil(resolved.merchantBrandId)
            XCTAssertTrue(resolved.trace.contains("category:userLocked"))
            XCTAssertEqual(resolved.emotionTag, "买杯喝的")
        }
        let choices = RecordEmotionScenePolicy.candidates(for: scene)
        XCTAssertGreaterThan(choices.count, 1)
        XCTAssertLessThanOrEqual(choices.count, 6)
        XCTAssertEqual(choices.first, saved.emotionTag)
        XCTAssertEqual(choices, RecordEmotionScenePolicy.candidates(for: scene))
        XCTAssertEqual(Set(choices).count, choices.count)
        var current = try XCTUnwrap(choices.first)
        var visited: [String] = []
        for _ in choices.indices {
            visited.append(current)
            XCTAssertEqual(RecordEmotionScenePolicy.validatedTag(
                selection: .init(context: scene, tag: current), resolution: saved,
                amount: 12.9, date: date, scenePackID: nil,
                automaticEmotionTag: saved.emotionTag
            ), current)
            XCTAssertEqual(scene.item(emotionTag: current).displayEmotionTag, current)
            current = try XCTUnwrap(RecordEmotionScenePolicy.next(after: current, candidates: choices))
        }
        XCTAssertEqual(visited, choices)
        XCTAssertEqual(current, choices.first)
        XCTAssertNil(RecordEmotionScenePolicy.validatedTag(
            selection: nil, resolution: saved, amount: 12.9, date: date,
            scenePackID: nil, automaticEmotionTag: saved.emotionTag
        ))
        XCTAssertEqual(saved.emotionTag, "买杯喝的")
    }

    func testNaturalDinnerTitleUsesMealSemanticsBeyondQuickTemplateWhitelist() {
        let date = mealDate(hour: 17)
        let resolved = mealResolution("今天晚饭", at: date, generated: false, source: "manual")
        let scene = mealContext(resolved, at: date, anchor: "今晚晚饭")
        let quick = mealResolution("晚餐记一笔", at: date, generated: true)
        let choices = RecordEmotionScenePolicy.candidates(for: scene)
        XCTAssertEqual(resolved.title, "今天晚饭")
        XCTAssertEqual(resolved.emotionTag, "晚饭时间坐一会儿")
        XCTAssertGreaterThan(choices.count, 1)
        XCTAssertEqual(choices, RecordEmotionScenePolicy.candidates(for: mealContext(quick, at: date)))
        XCTAssertTrue(Set(RecordEmotionCandidateSource.alternatives(for: scene)).isSubset(of: Set(choices)))
        for tag in choices {
            XCTAssertEqual(RecordEmotionScenePolicy.validatedTag(
                selection: .init(context: scene, tag: tag), resolution: resolved,
                amount: 18.5, date: date, scenePackID: nil,
                automaticEmotionTag: resolved.emotionTag
            ), tag)
            XCTAssertEqual(scene.item(emotionTag: tag).displayEmotionTag, tag)
        }
    }

    func testCollapsedCoffeeDrinkAndFoodPoolsGainOnlyCompatibleSemanticChoices() {
        for title in ["咖啡", "奶茶", "饭团", "牛肉面", "米粉", "麻辣烫"] {
            let scene = context(title: title, brandID: nil)
            let alternatives = RecordEmotionCandidateSource.alternatives(for: scene)
            let choices = RecordEmotionScenePolicy.candidates(for: scene)
            XCTAssertEqual(alternatives.count, 3, title)
            XCTAssertGreaterThan(choices.count, 1, title)
            XCTAssertLessThanOrEqual(choices.count, 6, title)
            XCTAssertEqual(choices.first, scene.previewEmotionTag, title)
            XCTAssertTrue(Set(alternatives).isSubset(of: Set(choices)), title)
            for tag in choices {
                XCTAssertEqual(scene.item(emotionTag: tag).displayEmotionTag, tag, title)
            }
            if ["米粉", "麻辣烫"].contains(title) {
                XCTAssertTrue(alternatives.allSatisfy { $0.contains("餐食") && !$0.contains("面") }, title)
            }
        }
        // The character 雪 in a drink name is not evidence of snowy weather.
        let soda = context(title: "雪碧", brandID: nil)
        XCTAssertEqual(RecordEmotionCandidateSource.alternatives(for: soda).count, 3)
        XCTAssertGreaterThan(RecordEmotionScenePolicy.candidates(for: soda).count, 1)
    }

    func testSemanticFallbackRejectsStrongContextsConflictsAndInsufficientEvidence() {
        let rejected = [
            context(title: "加班咖啡", brandID: nil),
            context(title: "雨天奶茶", brandID: nil),
            context(title: "下雪咖啡", brandID: nil),
            context(title: "深夜牛肉面", brandID: nil),
            context(title: "早餐晚饭", brandID: nil),
            context(title: "咖啡", brandID: nil, anchor: "奶茶"),
            context(title: "牛肉面", brandID: nil, anchor: "饭团"),
            context(title: "瑞幸", brandID: nil),
            context(title: "一杯", brandID: nil),
            context(title: "馄饨", brandID: nil),
            context(title: "咖啡", category: .shopping, brandID: nil),
            context(title: "奶茶", brandID: nil, preview: "雨天路上", automatic: "买杯喝的"),
            context(title: "奶茶", brandID: nil, preview: "晚饭时间坐一会儿", automatic: "晚饭时间坐一会儿"),
        ]
        for scene in rejected {
            XCTAssertTrue(RecordEmotionCandidateSource.alternatives(for: scene).isEmpty, scene.title)
        }
        let transit = context(title: "上班地铁", category: .transport, amount: 4, brandID: nil, packID: "commute")
        XCTAssertTrue(RecordEmotionCandidateSource.alternatives(for: transit).isEmpty)
        XCTAssertEqual(RecordEmotionScenePolicy.candidates(for: transit), ["公共交通一段"])
    }

    func testWorkingBrandedPoolsKeepOriginalResolverScanOrderWithoutSupplementing() {
        for scene in [context(), context(title: "罗森咖啡"), context(title: "罗森饮料", amount: 8), context(title: "罗森便当")] {
            let allowedRules = RecordSemanticLexicon.matchingEmotionRuleIDs(in: scene.title + " " + scene.previewEmotionTag)
            var expected: [String] = []
            for index in 0..<24 {
                let tag = index == 0 ? scene.previewEmotionTag : NarrativeCopyResolver.resolveEmotionTag(
                    context: .init(
                        brandId: scene.merchantBrandID, category: scene.category,
                        amount: scene.amount, date: scene.date,
                        seed: scene.title + "|emotionChoice:\(index)", note: scene.title,
                        scenePackId: scene.scenePackID
                    )
                )
                if !expected.contains(tag),
                   RecordSemanticLexicon.isTitle(tag, compatibleWith: scene.category),
                   RecordSemanticLexicon.matchingEmotionRuleIDs(in: tag).isSubset(of: allowedRules),
                   scene.item(emotionTag: tag).displayEmotionTag == tag {
                    expected.append(tag)
                }
                if expected.count == 6 { break }
            }
            XCTAssertGreaterThan(expected.count, 1, scene.title)
            XCTAssertEqual(RecordEmotionScenePolicy.candidates(for: scene), expected, scene.title)
        }
    }

    func testConvenienceStoreHasRealDeterministicDistinctChoicesWithinSix() {
        let scene = context()
        let first = RecordEmotionScenePolicy.candidates(for: scene)
        let second = RecordEmotionScenePolicy.candidates(for: scene)

        // This positive fixture must not pass if filtering accidentally removes every choice.
        XCTAssertGreaterThan(first.count, 1)
        XCTAssertLessThanOrEqual(first.count, 6)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.first, scene.previewEmotionTag)
        XCTAssertEqual(Set(first).count, first.count)
        XCTAssertTrue(first.allSatisfy {
            $0.contains("罗森") || $0 == "便利店这一笔"
        })
    }

    func testNextCyclesEachCandidateOnceThenReturnsToTheFirst() throws {
        let choices = RecordEmotionScenePolicy.candidates(for: context())
        XCTAssertGreaterThan(choices.count, 1)
        let first = try XCTUnwrap(choices.first)
        var current = first
        var visited: [String] = []
        for _ in choices.indices {
            visited.append(current)
            current = try XCTUnwrap(RecordEmotionScenePolicy.next(after: current, candidates: choices))
        }
        XCTAssertEqual(visited, choices)
        XCTAssertEqual(current, first)
        XCTAssertEqual(
            RecordEmotionScenePolicy.next(after: "不在候选里的旧标签", candidates: choices),
            first
        )
    }

    func testEmptyAndSingletonChoicesDoNotOfferAChange() {
        XCTAssertNil(RecordEmotionScenePolicy.next(after: "", candidates: []))
        XCTAssertNil(RecordEmotionScenePolicy.next(after: "唯一标签", candidates: ["唯一标签"]))
        XCTAssertNil(RecordEmotionScenePolicy.next(after: "旧标签", candidates: ["唯一标签"]))
    }

    func testMissingNoteOrNonpositiveAmountCannotOfferChoices() {
        XCTAssertTrue(RecordEmotionScenePolicy.candidates(for: context(title: "")).isEmpty)
        XCTAssertTrue(RecordEmotionScenePolicy.candidates(for: context(title: RecordSemanticLexicon.emptyNoteTitle)).isEmpty)
        XCTAssertTrue(RecordEmotionScenePolicy.candidates(for: context(amount: 0)).isEmpty)
        XCTAssertTrue(RecordEmotionScenePolicy.candidates(for: context(amount: -1)).isEmpty)
    }

    func testEveryRealCandidatePassesSaveValidationWithoutChangingResolution() {
        for scene in factualFixtures {
            let resolved = resolution(for: scene)
            let choices = RecordEmotionScenePolicy.candidates(for: scene)
            XCTAssertFalse(choices.isEmpty, scene.title)
            XCTAssertLessThanOrEqual(choices.count, 6, scene.title)
            XCTAssertEqual(Set(choices).count, choices.count, scene.title)
            for tag in choices {
                XCTAssertEqual(
                    RecordEmotionScenePolicy.validatedTag(
                        selection: .init(context: scene, tag: tag), resolution: resolved,
                        amount: scene.amount, date: scene.date, scenePackID: scene.scenePackID,
                        automaticEmotionTag: scene.automaticEmotionTag
                    ),
                    tag,
                    "\(scene.title): \(tag)"
                )
            }
            XCTAssertEqual(resolved.category, scene.category)
            XCTAssertEqual(resolved.title, scene.title)
            XCTAssertEqual(resolved.merchantBrandId, scene.merchantBrandID)
        }
    }

    func testNilAndForgedSelectionsCannotOverrideAutomaticEmotion() {
        let scene = context()
        for selection in [
            nil,
            RecordEmotionSelection(context: scene, tag: "雨天通勤"),
            RecordEmotionSelection(context: scene, tag: "不属于任何候选的标签"),
        ] as [RecordEmotionSelection?] {
            XCTAssertNil(RecordEmotionScenePolicy.validatedTag(
                selection: selection, resolution: resolution(for: scene),
                amount: scene.amount, date: scene.date, scenePackID: scene.scenePackID,
                automaticEmotionTag: scene.automaticEmotionTag
            ))
        }
    }

    func testChangedTitleCategoryOrBrandRejectsTheOldSelection() throws {
        let scene = context()
        let tag = try XCTUnwrap(RecordEmotionScenePolicy.candidates(for: scene).first)
        let changedResolutions = [
            RecordDraftResolution(
                category: scene.category, title: "罗森咖啡", emotionTag: scene.previewEmotionTag,
                merchantBrandId: scene.merchantBrandID, source: "test", trace: []
            ),
            RecordDraftResolution(
                category: .daily, title: scene.title, emotionTag: scene.previewEmotionTag,
                merchantBrandId: scene.merchantBrandID, source: "test", trace: []
            ),
            RecordDraftResolution(
                category: scene.category, title: scene.title, emotionTag: scene.previewEmotionTag,
                merchantBrandId: "familymart", source: "test", trace: []
            ),
            RecordDraftResolution(
                category: scene.category, title: scene.title, emotionTag: scene.previewEmotionTag,
                merchantBrandId: nil, source: "test", trace: []
            ),
        ]
        for changed in changedResolutions {
            XCTAssertNil(RecordEmotionScenePolicy.validatedTag(
                selection: .init(context: scene, tag: tag), resolution: changed,
                amount: scene.amount, date: scene.date, scenePackID: scene.scenePackID,
                automaticEmotionTag: scene.automaticEmotionTag
            ))
        }
    }

    func testChangedAmountDateOrPackRejectsTheOldSelection() throws {
        let scene = context(packID: "food")
        let tag = try XCTUnwrap(RecordEmotionScenePolicy.candidates(for: scene).first)
        let mutations: [(Double, Date, String?)] = [
            (scene.amount + 1, scene.date, scene.scenePackID),
            (scene.amount, scene.date.addingTimeInterval(60), scene.scenePackID),
            (scene.amount, scene.date, "commute"),
            (scene.amount, scene.date, nil),
        ]
        for (amount, date, packID) in mutations {
            XCTAssertNil(RecordEmotionScenePolicy.validatedTag(
                selection: .init(context: scene, tag: tag), resolution: resolution(for: scene),
                amount: amount, date: date, scenePackID: packID,
                automaticEmotionTag: scene.automaticEmotionTag
            ))
        }
    }

    func testChangedAutomaticEmotionRejectsTheOldSelection() throws {
        let scene = context()
        let tag = try XCTUnwrap(RecordEmotionScenePolicy.candidates(for: scene).first)
        XCTAssertNil(RecordEmotionScenePolicy.validatedTag(
            selection: .init(context: scene, tag: tag), resolution: resolution(for: scene),
            amount: scene.amount, date: scene.date, scenePackID: scene.scenePackID,
            automaticEmotionTag: "外地记录"
        ))
    }

    func testHandwrittenDoubleSpacesUseNormalizedChoiceContextThroughSaveValidation() throws {
        let rawTitle = "罗森  咖啡"
        let normalizedTitle = UserContentRiskService.shared.normalizedManualNote(rawTitle)
        XCTAssertEqual(normalizedTitle, "罗森 咖啡")
        func resolve(_ title: String) -> RecordDraftResolution {
            RecordDraftResolutionService.resolve(.init(
                rawTitle: title, fallbackCategory: .dining, amount: 18, date: date,
                merchantBrandId: MerchantBrandCatalog.matchBrand(in: title)?.id,
                categoryLockedByUser: false, userEditedTitle: true, source: "manual"
            ))
        }
        let rawPreview = resolve(rawTitle)
        let chooserResolution = resolve(normalizedTitle)
        XCTAssertEqual(rawPreview.title, rawTitle)
        XCTAssertEqual(
            UserContentRiskService.shared.normalizedManualNote(rawPreview.title),
            chooserResolution.title
        )
        XCTAssertEqual(rawPreview.category, chooserResolution.category)
        XCTAssertEqual(rawPreview.merchantBrandId, chooserResolution.merchantBrandId)

        let scene = RecordEmotionSceneContext(
            title: chooserResolution.title, category: chooserResolution.category,
            amount: 18, date: date, merchantBrandID: chooserResolution.merchantBrandId,
            scenePackID: nil, semanticAnchor: nil,
            previewEmotionTag: chooserResolution.emotionTag,
            automaticEmotionTag: chooserResolution.emotionTag
        )
        let choices = RecordEmotionScenePolicy.candidates(for: scene)
        XCTAssertGreaterThan(choices.count, 1)
        let chosen = try XCTUnwrap(RecordEmotionScenePolicy.next(
            after: scene.previewEmotionTag, candidates: choices
        ))
        XCTAssertNotEqual(chosen, scene.previewEmotionTag)

        let validatedNote = UserContentRiskService.shared.validateManualNote(rawTitle, allowEmpty: true)
        XCTAssertTrue(validatedNote.isAllowed)
        XCTAssertEqual(validatedNote.value, normalizedTitle)
        let saveResolution = resolve(validatedNote.value)
        XCTAssertEqual(saveResolution.title, "罗森 咖啡")
        XCTAssertEqual(
            RecordEmotionScenePolicy.validatedTag(
                selection: .init(context: scene, tag: chosen), resolution: saveResolution,
                amount: 18, date: date, scenePackID: nil,
                automaticEmotionTag: saveResolution.emotionTag
            ),
            chosen
        )
        XCTAssertEqual(scene.item(emotionTag: chosen).displayEmotionTag, chosen)
    }

    func testSemanticAnchorAndAutomaticPreviewArePartOfDraftIdentity() {
        let original = context()
        XCTAssertNotEqual(original, context(anchor: "罗森咖啡"))
        XCTAssertNotEqual(original, context(preview: "新的预览标签"))
        XCTAssertNotEqual(original, context(automatic: "新的自动标签"))
        XCTAssertEqual(Set([original, context(), context(anchor: "罗森咖啡")]).count, 2)
    }

    func testSpecificDiningChoicesStayWithCoffeeDrinkOrBentoEvidence() {
        let fixtures: [(RecordEmotionSceneContext, String)] = [
            (context(title: "罗森咖啡"), "咖啡"),
            (context(title: "罗森饮料", amount: 8), "drink"),
            (context(title: "罗森便当"), "便当"),
        ]
        for (scene, evidence) in fixtures {
            let choices = RecordEmotionScenePolicy.candidates(for: scene)
            XCTAssertGreaterThan(choices.count, 1, scene.title)
            for tag in choices {
                if evidence == "drink" {
                    XCTAssertTrue(tag.contains("饮料") || tag.contains("喝的"), tag)
                } else {
                    XCTAssertTrue(tag.contains(evidence), tag)
                }
                XCTAssertEqual(scene.item(emotionTag: tag).displayEmotionTag, tag)
            }
        }
    }

    func testCanonicalTelecomInsuranceAndTransportRemainSingletons() {
        let fixtures: [(RecordEmotionSceneContext, String)] = [
            (context(title: "手机话费", category: .daily, amount: 50, brandID: nil, preview: "手机话费记下"), "手机话费记下"),
            (context(title: "医疗保险", category: .other, amount: 100, brandID: nil), "保障安排记下"),
            (context(title: "上班地铁", category: .transport, amount: 4, brandID: nil, packID: "commute"), "公共交通一段"),
        ]
        for (scene, expected) in fixtures {
            let choices = RecordEmotionScenePolicy.candidates(for: scene)
            XCTAssertEqual(choices, [expected], scene.title)
            XCTAssertNil(RecordEmotionScenePolicy.next(after: expected, candidates: choices))
        }
    }

    func testTelecomAlternativesThatWouldBeRewrittenOnDisplayAreNotOffered() {
        let scene = context(title: "手机话费", category: .daily, amount: 50, brandID: nil)
        XCTAssertNotEqual(scene.previewEmotionTag, "手机话费记下")
        XCTAssertEqual(scene.item(emotionTag: scene.previewEmotionTag).displayEmotionTag, "手机话费记下")
        let choices = RecordEmotionScenePolicy.candidates(for: scene)
        XCTAssertTrue(choices.isEmpty)
        XCTAssertNil(RecordEmotionScenePolicy.next(after: scene.previewEmotionTag, candidates: choices))
    }

    func testLegacyRainAndAwayFactsCannotBeRemovedByCycling() {
        let rainy = context(
            title: "上班地铁", category: .transport, amount: 4, brandID: nil,
            packID: "commute", preview: "雨天通勤", automatic: "雨天通勤"
        )
        let away = context(preview: "外地记录", automatic: "外地记录")
        XCTAssertEqual(RecordEmotionScenePolicy.candidates(for: rainy), ["雨天通勤"])
        XCTAssertEqual(RecordEmotionScenePolicy.candidates(for: away), ["外地记录"])
        let weatherChanged = context(
            title: "上班地铁", category: .transport, amount: 4, brandID: nil,
            packID: "commute", automatic: "雨天通勤"
        )
        XCTAssertTrue(RecordEmotionScenePolicy.candidates(for: weatherChanged).isEmpty)
    }

    func testEveryCandidatePreservesDisplaySceneLifeMarksAndQueryFacets() {
        let facets: [AICommandSemanticFacet] = [
            .weatherHot, .weatherCold, .weatherRain, .weatherSnow,
            .commute, .interestGear, .awayFromHome,
        ]
        for scene in factualFixtures {
            let baseline = scene.item(emotionTag: scene.automaticEmotionTag)
            let expectedScene = LifeSceneSemanticService.classify(baseline)
            let choices = RecordEmotionScenePolicy.candidates(for: scene)
            XCTAssertFalse(choices.isEmpty, scene.title)
            for tag in choices {
                var selected = baseline
                selected.emotionTag = tag
                XCTAssertEqual(selected.displayEmotionTag, tag, scene.title)
                XCTAssertEqual(LifeSceneSemanticService.classify(selected), expectedScene, scene.title)
                for isMember in [false, true] {
                    let originalMarks = LifeMarkService.aggregates(
                        for: [baseline], allItems: [baseline], isMember: isMember,
                        now: scene.date, limit: 100
                    )
                    let selectedMarks = LifeMarkService.aggregates(
                        for: [selected], allItems: [selected], isMember: isMember,
                        now: scene.date, limit: 100
                    )
                    XCTAssertEqual(
                        Set(selectedMarks.map(\.id)), Set(originalMarks.map(\.id)),
                        "\(scene.title): \(tag), member: \(isMember)"
                    )
                }
                for facet in facets {
                    let intent = LifeMarkQueryIntent(
                        id: "emotion-scene-test", label: "", categories: [], keywords: [],
                        requiresKeywordMatch: false, semanticFacets: [facet]
                    )
                    XCTAssertEqual(
                        LifeMarkService.matches(selected, intent: intent),
                        LifeMarkService.matches(baseline, intent: intent),
                        "\(scene.title): \(tag), facet: \(facet)"
                    )
                }
            }
        }
    }

    private func rewardPackID(for item: HomeItem) -> String? {
        let suiteName = "RecordEmotionScenePolicyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let service = LifeMarkSceneRewardService(defaults: defaults, now: { item.createdAt })
        return service.registerRewardIfNeeded(
            for: item, allItems: [item], currentPackIds: [],
            definitions: ScenePackCopyPool.definitions, isMember: false
        )?.packId
    }

    func testEmotionChoicePreservesRewardEligibilityWithAPositiveInterestFixture() {
        let interest = context(title: "路亚鱼竿", category: .shopping, amount: 268, brandID: nil)
        XCTAssertEqual(rewardPackID(for: interest.item(emotionTag: interest.automaticEmotionTag)), "shopping")
        for scene in factualFixtures {
            let baseline = scene.item(emotionTag: scene.automaticEmotionTag)
            let expectedRewardPack = rewardPackID(for: baseline)
            let choices = RecordEmotionScenePolicy.candidates(for: scene)
            XCTAssertFalse(choices.isEmpty, scene.title)
            for tag in choices {
                var selected = baseline
                selected.emotionTag = tag
                XCTAssertEqual(rewardPackID(for: selected), expectedRewardPack, "\(scene.title): \(tag)")
            }
        }
    }
}
#endif

final class RecordQuickNotePolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func date(month: Int = 9, day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private var referenceDate: Date { date(day: 17) }

    private func record(
        _ title: String, on date: Date, category: HomeItem.Category = .dining,
        amount: Double = 18, userEdited: Bool? = true,
        draftStatus: HomeItem.DraftMeta.Status? = nil
    ) -> HomeItem {
        var item = HomeItem(
            title: title, amount: amount, category: category, createdAt: date,
            userEditedTitle: userEdited
        )
        if let draftStatus {
            item.draftMeta = .init(batchId: "quick-note-test", importedAt: date, status: draftStatus)
        }
        return item
    }

    private func history(_ items: [HomeItem], at date: Date? = nil) -> [String: [String]] {
        RecordQuickNotePolicy.historicalTitles(items: items, at: date ?? referenceDate, calendar: calendar)
    }

    private func titles(_ items: [HomeItem]) -> Set<String> {
        Set(history(items).values.flatMap { $0 })
    }

    private func assertStableResolution(
        _ title: String, category: HomeItem.Category, date: Date,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        for locked in [false, true] {
            for source in ["preview", "manual"] {
                let result = RecordDraftResolutionService.resolve(.init(
                    rawTitle: title, fallbackCategory: category, amount: 18, date: date,
                    merchantBrandId: nil, categoryLockedByUser: locked,
                    userEditedTitle: false, source: source,
                    generatedNoteContext: .init(title: title, category: category)
                ))
                XCTAssertEqual(result.category, category, "\(title), locked: \(locked)", file: file, line: line)
                XCTAssertEqual(result.title, title, "\(category): \(title), locked: \(locked)", file: file, line: line)
            }
        }
    }

    func testAllCategoryTemplatesStayCompatibleAcrossHourBoundariesAndWeekends() {
        let unsupportedFacts = ["早班", "加班", "下班", "出差", "热乎", "工作日", "假期", "休息日"]
        for day in [17, 19] {
            for hour in [0, 5, 9, 10, 13, 14, 16, 17, 20, 21, 23] {
                for category in HomeItem.Category.allCases {
                    let candidates = RecordQuickNotePolicy.templates(
                        for: category, at: date(day: day, hour: hour), calendar: calendar
                    )
                    XCTAssertEqual(candidates.count, 3, "\(category), hour: \(hour)")
                    XCTAssertEqual(Set(candidates).count, candidates.count)
                    for title in candidates {
                        XCTAssertTrue(RecordQuickNotePolicy.isCompatible(title, category: category), title)
                        XCTAssertLessThanOrEqual(title.count, 32)
                        XCTAssertFalse(unsupportedFacts.contains { title.contains($0) }, title)
                    }
                }
            }
        }
    }

    func testTemplatesPreserveTitleAndCategoryInLockedAndUnlockedPreviewAndSave() {
        for day in [17, 19] {
            for hour in [8, 12, 15, 19, 23] {
                let currentDate = date(day: day, hour: hour)
                for category in HomeItem.Category.allCases {
                    for title in RecordQuickNotePolicy.templates(for: category, at: currentDate, calendar: calendar) {
                        assertStableResolution(title, category: category, date: currentDate)
                    }
                }
            }
        }
    }

    func testDiningTemplatesFollowMealBandsWithoutAssumingWorkOrHolidayActivities() {
        let expectations = [(5, "早餐"), (9, "早餐"), (10, "午"), (13, "午"), (17, "晚"), (20, "晚")]
        for (hour, cue) in expectations {
            let workday = RecordQuickNotePolicy.templates(for: .dining, at: date(day: 17, hour: hour), calendar: calendar)
            let weekend = RecordQuickNotePolicy.templates(for: .dining, at: date(day: 19, hour: hour), calendar: calendar)
            let holiday = RecordQuickNotePolicy.templates(for: .dining, at: date(month: 5, day: 1, hour: hour), calendar: calendar)
            XCTAssertTrue(workday.allSatisfy { $0.contains(cue) })
            XCTAssertEqual(workday, weekend)
            XCTAssertEqual(workday, holiday)
        }
        for hour in [0, 4, 21, 23] {
            let candidates = RecordQuickNotePolicy.templates(for: .dining, at: date(day: 17, hour: hour), calendar: calendar)
            XCTAssertFalse(candidates.contains { $0.contains("早餐") || $0.contains("午餐") || $0.contains("加班") })
        }
    }

    func testCompatibilityRejectsOldConvenienceStoreDailyCopyAndForeignBrands() {
        XCTAssertFalse(RecordQuickNotePolicy.isCompatible("便利店补一袋日常", category: .daily))
        XCTAssertFalse(RecordQuickNotePolicy.isCompatible("罗森咖啡", category: .daily))
        XCTAssertFalse(RecordQuickNotePolicy.isCompatible("京东", category: .dining))
        XCTAssertFalse(RecordQuickNotePolicy.isCompatible("", category: .daily))
        XCTAssertFalse(RecordQuickNotePolicy.isCompatible(String(repeating: "物", count: 33), category: .daily))
        XCTAssertTrue(RecordQuickNotePolicy.isCompatible("日用品补一笔", category: .daily))
        XCTAssertTrue(RecordQuickNotePolicy.isCompatible("罗森咖啡", category: .dining))
    }

    func testHistoryNeedsTwoDistinctDaysEvenWhenOneDayHasManyRecords() {
        let repeatedDate = date(day: 15)
        var items = (0..<8).map { index in
            record("同日咖啡", on: repeatedDate.addingTimeInterval(Double(index * 60)))
        }
        items += [record("拿铁咖啡", on: date(day: 14)), record("拿铁咖啡", on: date(day: 15))]
        XCTAssertEqual(titles(items), Set(["拿铁咖啡"]))
    }

    func testHistorySeparatesCategoriesMealBandsWorkdaysWeekendsAndHolidays() {
        let items = [
            record("早餐咖啡", on: date(day: 14, hour: 8)),
            record("早餐咖啡", on: date(day: 15, hour: 8)),
            record("午间咖啡", on: date(day: 14)),
            record("午间咖啡", on: date(day: 15)),
            record("周末咖啡", on: date(day: 12)),
            record("周末咖啡", on: date(day: 13)),
            record("假日咖啡", on: date(month: 5, day: 1)),
            record("假日咖啡", on: date(month: 6, day: 19)),
            record("跨时段咖啡", on: date(day: 14, hour: 8)),
            record("跨时段咖啡", on: date(day: 15, hour: 15)),
            record("跨日型咖啡", on: date(day: 13)),
            record("跨日型咖啡", on: date(day: 14)),
            record("常用小物", on: date(day: 14), category: .daily),
            record("常用小物", on: date(day: 15), category: .shopping),
        ]
        let pool = history(items)
        let fixtures: [(Date, String)] = [
            (date(day: 17, hour: 8), "早餐咖啡"),
            (date(day: 17), "午间咖啡"),
            (date(day: 19), "周末咖啡"),
            (date(month: 5, day: 1), "假日咖啡"),
        ]
        for (contextDate, expected) in fixtures {
            let key = RecordQuickNotePolicy.contextKey(category: .dining, date: contextDate, calendar: calendar)
            XCTAssertEqual(pool[key], [expected])
        }
        XCTAssertEqual(Set(pool.values.flatMap { $0 }), Set(fixtures.map { $0.1 }))
    }

    func testHistoryIncludesExact180DayBoundaryButExcludesExpiredAndFutureSupport() {
        let cutoff = calendar.date(byAdding: .day, value: -180, to: referenceDate)!
        let laterWeekend = calendar.date(byAdding: .day, value: 7, to: cutoff)!
        let items = [
            record("边界咖啡", on: cutoff),
            record("边界咖啡", on: laterWeekend),
            record("过期咖啡", on: cutoff.addingTimeInterval(-1)),
            record("过期咖啡", on: laterWeekend),
            record("未来咖啡", on: date(day: 10)),
            record("未来咖啡", on: date(day: 24)),
        ]
        XCTAssertEqual(titles(items), Set(["边界咖啡"]))
    }

    func testDifferentPositiveAmountsCanSupportOneTitleButZeroAndNegativeAmountsCannot() {
        let items = [
            record("常喝咖啡", on: date(day: 14), amount: 9.9),
            record("常喝咖啡", on: date(day: 15), amount: 28),
            record("零元咖啡", on: date(day: 14), amount: 0),
            record("零元咖啡", on: date(day: 15), amount: 18),
            record("退款咖啡", on: date(day: 14), amount: -18),
            record("退款咖啡", on: date(day: 15), amount: 18),
        ]
        XCTAssertEqual(titles(items), Set(["常喝咖啡"]))
    }

    func testPendingAndResolvedDraftMetadataBothExcludeUnorganizedHistory() {
        let items = [
            record("普通咖啡", on: date(day: 14)),
            record("普通咖啡", on: date(day: 15)),
            record("待整理咖啡", on: date(day: 14)),
            record("待整理咖啡", on: date(day: 15), draftStatus: .pending),
            record("已校对咖啡", on: date(day: 14)),
            record("已校对咖啡", on: date(day: 15), draftStatus: .resolved),
        ]
        XCTAssertEqual(titles(items), Set(["普通咖啡"]))
    }

    func testHistoryRejectsAmountsDefaultTitlesAndUneditedGenericCopy() {
        let rejected = ["18.00", "￥20", HomeItem.Category.dining.defaultRecordTitle, "早餐先记下", "餐饮消费"]
        var items = rejected.flatMap { title in
            [record(title, on: date(day: 14)), record(title, on: date(day: 15))]
        }
        items += [
            record("这顿吃得舒服", on: date(day: 14), userEdited: false),
            record("这顿吃得舒服", on: date(day: 15), userEdited: nil),
            record("牛肉面", on: date(day: 14)),
            record("牛肉面", on: date(day: 15)),
        ]
        XCTAssertEqual(titles(items), Set(["牛肉面"]))
    }

    func testHistoryEnforcesTwoToTwelveCharactersAfterTrimming() {
        let twelveCharacters = "每日常喝的大杯热拿铁咖啡"
        let thirteenCharacters = "我" + twelveCharacters
        XCTAssertEqual(twelveCharacters.count, 12)
        XCTAssertEqual(thirteenCharacters.count, 13)
        let fixtures = ["茶", "咖啡", twelveCharacters, thirteenCharacters, "  拿铁咖啡  "]
        let items = fixtures.flatMap { title in
            [record(title, on: date(day: 14)), record(title, on: date(day: 15))]
        }
        XCTAssertEqual(titles(items), Set(["咖啡", twelveCharacters, "拿铁咖啡"]))
    }

    func testHistoryAcceptsRepeatedBrandOrUserEditedTitleWithoutInventingManualProvenance() {
        let items = [
            record("罗森咖啡", on: date(day: 14), userEdited: nil),
            record("罗森咖啡", on: date(day: 15), userEdited: false),
            record("拿铁咖啡", on: date(day: 14), userEdited: true),
            record("拿铁咖啡", on: date(day: 15), userEdited: false),
            record("牛肉面", on: date(day: 14), userEdited: false),
            record("牛肉面", on: date(day: 15), userEdited: false),
        ]
        XCTAssertEqual(titles(items), Set(["罗森咖啡", "拿铁咖啡"]))
    }

    func testHistoryRanksDistinctDaysThenRecencyAndLimitsEachContextToSix() {
        let tiedTitles = ["丙咖啡", "丁咖啡", "戊咖啡", "己咖啡", "庚咖啡", "辛咖啡"]
        var items = [
            record("甲咖啡", on: date(day: 10)),
            record("甲咖啡", on: date(day: 11)),
            record("甲咖啡", on: date(day: 14)),
            record("乙咖啡", on: date(day: 14)),
            record("乙咖啡", on: date(day: 16)),
        ]
        items += tiedTitles.flatMap { title in
            [record(title, on: date(day: 14)), record(title, on: date(day: 15))]
        }
        items += (0..<12).map { _ in record("辛咖啡", on: date(day: 15)) }
        let key = RecordQuickNotePolicy.contextKey(category: .dining, date: referenceDate, calendar: calendar)
        let expected = ["甲咖啡", "乙咖啡"] + Array(tiedTitles.sorted().prefix(4))
        XCTAssertEqual(history(items)[key], expected)
        XCTAssertEqual(history(Array(items.reversed()))[key], expected)
        XCTAssertEqual(expected.count, 6)
    }

    func testNewUsersReceiveNeutralTemplatesForEveryCategory() {
        for category in HomeItem.Category.allCases {
            let candidates = RecordQuickNotePolicy.suggestions(
                category: category, date: referenceDate, history: [], prefill: nil,
                anchor: "", calendar: calendar
            )
            XCTAssertEqual(candidates, RecordQuickNotePolicy.templates(for: category, at: referenceDate, calendar: calendar))
            XCTAssertFalse(candidates.isEmpty)
            XCTAssertLessThanOrEqual(candidates.count, 4)
        }
    }

    func testSuggestionsDeduplicateAndReserveTwoPlacesForNeutralTemplates() {
        let personalized = ["美式咖啡", "拿铁咖啡", "牛肉面", "便当"]
        let candidates = RecordQuickNotePolicy.suggestions(
            category: .dining, date: referenceDate,
            history: ["美式咖啡", "美式咖啡", "拿铁咖啡", "牛肉面", "便当"],
            prefill: "美式咖啡", anchor: "", calendar: calendar
        )
        XCTAssertEqual(Array(candidates.prefix(2)), ["美式咖啡", "拿铁咖啡"])
        XCTAssertEqual(candidates.count, 4)
        XCTAssertEqual(Set(candidates).count, candidates.count)
        XCTAssertEqual(candidates.filter { personalized.contains($0) }.count, 2)
        let defaults = RecordQuickNotePolicy.templates(for: .dining, at: referenceDate, calendar: calendar)
        XCTAssertEqual(candidates.filter { defaults.contains($0) }.count, 2)
    }

    func testSuggestionsRejectCategoryConflictsAndPreserveAcceptedTitlesOnSave() {
        let candidates = RecordQuickNotePolicy.suggestions(
            category: .daily, date: referenceDate,
            history: ["便利店补一袋日常", "罗森咖啡", "纸巾", "猫砂"],
            prefill: "午餐便当", anchor: "", calendar: calendar
        )
        XCTAssertEqual(Array(candidates.prefix(2)), ["纸巾", "猫砂"])
        XCTAssertLessThanOrEqual(candidates.count, 4)
        for title in candidates {
            XCTAssertTrue(RecordQuickNotePolicy.isCompatible(title, category: .daily), title)
            assertStableResolution(title, category: .daily, date: referenceDate)
        }
    }

    func testFoodAndBrandAnchorsExcludeDifferentFoodOrAnotherMerchant() {
        let candidates = RecordQuickNotePolicy.suggestions(
            category: .dining, date: referenceDate,
            history: ["罗森便当", "全家咖啡", "拿铁咖啡", "罗森咖啡"],
            prefill: "罗森饮料", anchor: "罗森咖啡", calendar: calendar
        )
        XCTAssertEqual(Array(candidates.prefix(2)), ["拿铁咖啡", "罗森咖啡"])
        XCTAssertFalse(candidates.contains("罗森便当"))
        XCTAssertFalse(candidates.contains("全家咖啡"))
        XCTAssertFalse(candidates.contains("罗森饮料"))
        XCTAssertEqual(candidates.count, 4)
        for title in candidates {
            XCTAssertTrue(RecordQuickNotePolicy.respectsAnchor(title, anchor: "罗森咖啡"), title)
        }
    }

    func testBabyAndPetAnchorsDoNotSubstituteForEachOther() {
        let fixtures = [
            (anchor: "猫砂", accepted: "猫粮", rejected: "宝宝湿巾"),
            (anchor: "宝宝湿巾", accepted: "纸尿裤", rejected: "猫粮"),
        ]
        for fixture in fixtures {
            let candidates = RecordQuickNotePolicy.suggestions(
                category: .daily, date: referenceDate,
                history: [fixture.rejected, fixture.accepted], prefill: fixture.rejected,
                anchor: fixture.anchor, calendar: calendar
            )
            XCTAssertEqual(candidates.first, fixture.accepted)
            XCTAssertFalse(candidates.contains(fixture.rejected))
            XCTAssertTrue(candidates.contains("日用品补一笔"))
            XCTAssertLessThanOrEqual(candidates.count, 4)
            for title in candidates {
                XCTAssertTrue(RecordQuickNotePolicy.respectsAnchor(title, anchor: fixture.anchor), title)
            }
        }
    }
}

final class RecordAmountInputCoalescingTests: XCTestCase {
    func testContinuousInputOnlyCompletesLatestRequest() {
        var gate = RecordAmountInputGate()
        let requests = (0..<12).map { _ in gate.begin() }

        for request in requests.dropLast() {
            XCTAssertFalse(gate.finish(request))
            XCTAssertEqual(gate.pending, requests.last)
        }
        XCTAssertTrue(gate.finish(requests.last!))
        XCTAssertNil(gate.pending)
    }

    func testReturningToEarlierAmountDoesNotReviveItsRequest() {
        var gate = RecordAmountInputGate()
        let firstOne = gate.begin()
        let twelve = gate.begin()
        let secondOne = gate.begin()

        XCTAssertNotEqual(firstOne, secondOne, "The 1 -> 12 -> 1 sequence contains three input events.")
        XCTAssertFalse(gate.finish(firstOne))
        XCTAssertFalse(gate.finish(twelve))
        XCTAssertEqual(gate.pending, secondOne)
        XCTAssertTrue(gate.finish(secondOne))
    }

    func testRequestCanFinishOnlyOnce() {
        var gate = RecordAmountInputGate()
        let request = gate.begin()

        XCTAssertTrue(gate.finish(request))
        XCTAssertFalse(gate.finish(request))
        XCTAssertFalse(gate.finish(request))
        XCTAssertNil(gate.pending)
    }

    func testExplicitFlushRejectsOldCallbackWithoutConsumingNextInput() {
        var gate = RecordAmountInputGate()
        let oldRequest = gate.begin()
        let pendingForFlush = gate.pending!
        XCTAssertTrue(gate.finish(pendingForFlush))
        XCTAssertFalse(gate.finish(oldRequest))

        let nextRequest = gate.begin()
        XCTAssertFalse(gate.finish(oldRequest))
        XCTAssertEqual(gate.pending, nextRequest)
        XCTAssertTrue(gate.finish(nextRequest))
    }

    func testCancellationInvalidatesPendingCallbackAndAllowsNewRequest() {
        var gate = RecordAmountInputGate()
        let cancelledRequest = gate.begin()
        gate.cancel()

        XCTAssertNil(gate.pending)
        XCTAssertFalse(gate.finish(cancelledRequest))
        let nextRequest = gate.begin()
        XCTAssertNotEqual(cancelledRequest, nextRequest)
        XCTAssertFalse(gate.finish(cancelledRequest))
        XCTAssertEqual(gate.pending, nextRequest)
        XCTAssertTrue(gate.finish(nextRequest))
    }

    func testMemoBuildsSameKeyOnceAcrossRepeatedReads() {
        let memo = RecordDraftMemo<String, Int>()
        var builds = 0
        for _ in 0..<8 {
            let value = memo.value(for: "current draft") {
                builds += 1
                return builds
            }
            XCTAssertEqual(value, 1)
        }
        XCTAssertEqual(builds, 1)
    }

    func testMemoCachesNilInsteadOfTreatingItAsAMiss() {
        let memo = RecordDraftMemo<String, String?>()
        var builds = 0
        let first = memo.value(for: "neutral draft") {
            builds += 1
            return nil
        }
        let repeated = memo.value(for: "neutral draft") {
            builds += 1
            return "must not be built"
        }

        XCTAssertNil(first)
        XCTAssertNil(repeated)
        XCTAssertEqual(builds, 1)
        XCTAssertEqual(memo.value(for: "explicit draft") {
            builds += 1
            return "new result"
        }, "new result")
        XCTAssertEqual(builds, 2)
    }

    func testMemoRebuildsChangedKeyAndEvictsEarlierDraft() {
        let memo = RecordDraftMemo<String, Int>()
        var builds = 0
        for (key, expected) in [("1", 1), ("12", 2), ("1", 3)] {
            XCTAssertEqual(memo.value(for: key) {
                builds += 1
                return builds
            }, expected)
        }
        XCTAssertEqual(builds, 3)
    }

    func testEveryDraftAndPrefillDependencyInvalidatesPreviewMemo() {
        let mutations: [(String, (inout RecordPreviewComputationKey) -> Void)] = [
            ("amount text", { $0.amountText = "12.00" }),
            ("title", { $0.title = "午餐便当" }),
            ("category", { $0.category = .daily }),
            ("category lock", { $0.categoryLocked = true }),
            ("record date", { $0.date = $0.date.addingTimeInterval(60) }),
            ("note editor", { $0.noteEditorExpanded = true }),
            ("manual note intent", { $0.noteIntent = true }),
            ("rotated copy", { $0.lineWasRotated = true }),
            ("scene identity", { $0.scenePackID = "family" }),
            ("scene category", { $0.scenePackCategory = .daily }),
            ("semantic anchor", { $0.noteAnchor = "便当" }),
            ("prefill title", { $0.prefillTitle = "午餐" }),
            ("prefill category", { $0.prefillCategory = .other }),
            ("prefill emotion", { $0.prefillEmotion = "补点能量" }),
            ("prefill source", { $0.prefillSource = "brand" }),
            ("prefill confidence", { $0.prefillConfidence = 0.9 }),
            ("weather setting", { $0.weatherEnabled = false }),
        ]
        for (name, mutate) in mutations {
            assertPreviewMemoInvalidated(name, mutate: mutate)
        }
    }

    func testCalendarIdentityAndTimeZoneInvalidatePreviewMemo() {
        assertPreviewMemoInvalidated("calendar identifier") {
            $0.calendar = Calendar(identifier: .buddhist)
        }
        assertPreviewMemoInvalidated("calendar time zone") {
            $0.calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!
        }
        assertPreviewMemoInvalidated("calendar week boundary") {
            $0.calendar.firstWeekday = 2
        }
    }

    func testGeneratedNotePresenceTitleAndCategoryInvalidatePreviewMemo() {
        assertPreviewMemoInvalidated("removed generated provenance") { $0.generatedNote = nil }
        assertPreviewMemoInvalidated("generated title") {
            $0.generatedNote = RecordGeneratedNoteContext(title: "午餐便当", category: .dining)
        }
        assertPreviewMemoInvalidated("generated category") {
            $0.generatedNote = RecordGeneratedNoteContext(title: "拿铁咖啡", category: .daily)
        }
    }

    func testWeatherPresenceTemperatureCodeAndTimestampInvalidatePreviewMemo() {
        assertPreviewMemoInvalidated("weather expired or unavailable") { $0.weather = nil }
        assertPreviewMemoInvalidated("temperature") { $0.weather?.temp = 31 }
        assertPreviewMemoInvalidated("weather code") { $0.weather?.weatherCode = 71 }
        assertPreviewMemoInvalidated("weather timestamp") {
            $0.weather?.ts = Date(timeIntervalSince1970: 1_800_000_060)
        }
    }

    private func assertPreviewMemoInvalidated(
        _ dependency: String,
        mutate: (inout RecordPreviewComputationKey) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let original = previewKey()
        var changed = original
        mutate(&changed)
        XCTAssertNotEqual(original, changed, dependency, file: file, line: line)

        let memo = RecordDraftMemo<RecordPreviewComputationKey, Int>()
        var builds = 0
        XCTAssertEqual(memo.value(for: original) {
            builds += 1
            return builds
        }, 1, dependency, file: file, line: line)
        XCTAssertEqual(memo.value(for: changed) {
            builds += 1
            return builds
        }, 2, dependency, file: file, line: line)
        XCTAssertEqual(memo.value(for: changed) {
            builds += 1
            return builds
        }, 2, dependency, file: file, line: line)
        XCTAssertEqual(builds, 2, dependency, file: file, line: line)
    }

    private func previewKey() -> RecordPreviewComputationKey {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        return RecordPreviewComputationKey(
            calendar: calendar,
            amountText: "12", title: "拿铁咖啡", category: .dining,
            categoryLocked: false, date: date,
            generatedNote: RecordGeneratedNoteContext(title: "拿铁咖啡", category: .dining),
            noteEditorExpanded: false, noteIntent: false, lineWasRotated: false,
            scenePackID: "food", scenePackCategory: .dining, noteAnchor: "咖啡",
            prefillTitle: "拿铁咖啡", prefillCategory: .dining,
            prefillEmotion: "喝点喜欢的", prefillSource: "frequent", prefillConfidence: 0.8,
            weatherEnabled: true, weather: WeatherSnapshot(temp: 18, weatherCode: 61, ts: date)
        )
    }
}
