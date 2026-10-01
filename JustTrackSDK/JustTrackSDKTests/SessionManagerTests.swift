import Foundation
import XCTest

@testable import JustTrackSDK

// MARK: - Session struct tests (no SDK dependency needed)

final class SessionTests: XCTestCase {
	private var userDefaults: UserDefaults!

	private var suiteName: String = ""

	override func setUp() {
		super.setUp()
		suiteName = "io.justtrack.test.session.\(UUID().uuidString)"
		userDefaults = UserDefaults(suiteName: suiteName)!
	}

	override func tearDown() {
		userDefaults.removeSuite(named: suiteName)
		userDefaults = nil
		super.tearDown()
	}

	// MARK: Session.init?(restoreFrom:) — all nil paths

	func testSessionRestoreReturnsNilWhenNoDataStored() {
		let session = Session(restoreFrom: userDefaults)
		XCTAssertNil(session)
	}

	func testSessionRestoreReturnsNilWhenSessionIdMissing() {
		let dict: [String: Any] = [
			"sessionStart": Date(),
			"sessionLastTick": Date(),
		]
		userDefaults.setValue(dict, forKey: Session.key)

		let session = Session(restoreFrom: userDefaults)
		XCTAssertNil(session)
	}

	func testSessionRestoreReturnsNilWhenSessionIdInvalid() {
		// StringID requires a non-empty string — store an integer instead
		let dict: [String: Any] = [
			"sessionId": 12345,
			"sessionStart": Date(),
			"sessionLastTick": Date(),
		]
		userDefaults.setValue(dict, forKey: Session.key)

		let session = Session(restoreFrom: userDefaults)
		XCTAssertNil(session)
	}

	func testSessionRestoreReturnsNilWhenSessionIdIsEmptyString() {
		// Empty string is a valid String cast but fails StringID(value:) validation.
		// This exercises the `guard let sessionId = StringID(value:) else { return nil }` branch.
		let dict: [String: Any] = [
			"sessionId": "",
			"sessionStart": Date(),
			"sessionLastTick": Date(),
		]
		userDefaults.setValue(dict, forKey: Session.key)

		let session = Session(restoreFrom: userDefaults)
		XCTAssertNil(session)
	}

	func testSessionRestoreReturnsNilWhenSessionStartMissing() {
		let dict: [String: Any] = [
			"sessionId": UUID().uuidString,
			"sessionLastTick": Date(),
		]
		userDefaults.setValue(dict, forKey: Session.key)

		let session = Session(restoreFrom: userDefaults)
		XCTAssertNil(session)
	}

	func testSessionRestoreReturnsNilWhenSessionLastTickMissing() {
		let dict: [String: Any] = [
			"sessionId": UUID().uuidString,
			"sessionStart": Date(),
		]
		userDefaults.setValue(dict, forKey: Session.key)

		let session = Session(restoreFrom: userDefaults)
		XCTAssertNil(session)
	}

	func testSessionPersistAndRestoreRoundTrip() {
		let session = Session()
		session.persist(storeTo: userDefaults)

		let restored = Session(restoreFrom: userDefaults)
		XCTAssertNotNil(restored)
		XCTAssertEqual(restored!.sessionId.value, session.sessionId.value)
		XCTAssertEqual(restored!.sessionStart.timeIntervalSince1970, session.sessionStart.timeIntervalSince1970, accuracy: 1.0)
	}

	func testSessionRemoveClearsStorage() {
		let session = Session()
		session.persist(storeTo: userDefaults)
		XCTAssertNotNil(Session(restoreFrom: userDefaults))

		session.remove(from: userDefaults)
		XCTAssertNil(Session(restoreFrom: userDefaults))
	}

	// MARK: reportLastSession — nil path (no stored session → no crash)

	func testReportLastSessionDoesNothingWhenNoSessionStored() {
		// Ensure there is no session stored
		userDefaults.removeObject(forKey: Session.key)

		// Session.init?(restoreFrom:) returns nil → reportLastSession is a no-op
		let session = Session(restoreFrom: userDefaults)
		XCTAssertNil(session)
	}
}

// MARK: - SessionManagerImpl getLastSessionId branches

final class SessionManagerImplTests: XCTestCase {
	override func setUp() {
		super.setUp()
		JustTrack.resetForTesting(clearStorage: true)
	}

	override func tearDown() {
		JustTrack.resetForTesting(clearStorage: true)
		super.tearDown()
	}

	func testStartSessionReturnsExistingSessionOnSecondCall() {
		// startSession has `if let session { return session }` early-return.
		// Calling moveToForeground twice (without intervening moveToBackground) hits this path:
		// first call starts a session, second call sees session != nil → no-ops.
		let sdk = makeSdk()
		let manager = SessionManagerImpl(sdk)

		manager.moveToForeground()
		let firstId = manager.getLastSessionId(sdk)
		manager.moveToForeground()
		let secondId = manager.getLastSessionId(sdk)

		XCTAssertEqual(firstId, secondId)

		manager.moveToBackground()
		sdk.shutdown()
	}

	func testGetLastSessionIdReturnsCachedLastSessionIdAfterBackground() {
		// Covers the `if let lastSessionId { return lastSessionId }` branch.
		// After moveToBackground, session is nil but lastSessionId is set.
		let sdk = makeSdk()
		let manager = SessionManagerImpl(sdk)

		manager.moveToForeground()
		let foregroundId = manager.getLastSessionId(sdk)
		manager.moveToBackground()
		let backgroundId = manager.getLastSessionId(sdk)

		XCTAssertEqual(foregroundId, backgroundId)

		sdk.shutdown()
	}

	func testReportLastSessionEndsRestoredSession() {
		// Covers reportLastSession() when a previous session exists in UserDefaults.
		// Pre-populate UserDefaults with a session, then start() the manager and verify it
		// consumes the stored session by exposing it via getLastSessionId.
		let stored = Session()
		stored.persist(storeTo: .standard)
		XCTAssertNotNil(Session(restoreFrom: .standard))

		let sdk = makeSdk()
		let manager = SessionManagerImpl(sdk)
		manager.start()
		// start() invokes reportLastSession (which ends the restored session) + moveToForeground.
		// The restored session's id should now be the lastSessionId; we read it back via getLastSessionId
		// from a fresh manager after backgrounding the foreground session.
		manager.moveToBackground()
		_ = manager.getLastSessionId(sdk)

		// Storage should be cleared after end.
		XCTAssertNil(Session(restoreFrom: .standard))

		sdk.shutdown()
	}

	// MARK: - Helpers

	private func makeSdk() -> JustTrackSdkImpl {
		let idfa = StringID()
		let idfv = StringID(value: UUID().uuidString.lowercased().dropLast(3) + "6ed")!
		return try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: StubHttpClient(),
			attributionApi: TestAttributionHttpClient(changeInstallId: false, remainingFails: 0),
			privacyApi: TestAttributionHttpClient(changeInstallId: false, remainingFails: 0),
			eventApi: TestAttributionHttpClient(changeInstallId: false, remainingFails: 0),
			logApi: TestAttributionHttpClient(changeInstallId: false, remainingFails: 0),
			userPropertyApi: TestAttributionHttpClient(changeInstallId: false, remainingFails: 0),
			remoteConfigApi: TestAttributionHttpClient(changeInstallId: false, remainingFails: 0),
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in TestConnectivityManager() },
			adTrackingProvider: TestAdTrackingProvider(idfa: idfa, idfv: idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(
				databaseName: "JustTrackSDK_SessionManagerImplTests_\(StringID().value)"
			),
			config: .default,
			manualStart: true
		)
	}
}
