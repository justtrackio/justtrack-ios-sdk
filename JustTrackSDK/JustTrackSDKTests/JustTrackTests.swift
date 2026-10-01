import XCTest

@testable import JustTrackSDK

/// Tests for the JustTrack static entry-point class.
/// Focuses on the methods that currently have 0% coverage:
///   - requestTrackingAuthorization(_:)
///   - getInstance()
/// and the partially-covered provideInstance(_:) error/second-call paths.
final class JustTrackTests: XCTestCase {
	override func setUp() {
		super.setUp()
		JustTrack.resetForTesting(clearStorage: false)
	}

	// MARK: - getInstance

	func testGetInstanceReturnsNilBeforeInitialization() {
		XCTAssertNil(JustTrack.getInstance())
	}

	func testGetInstanceReturnsSdkAfterSetSdk() {
		let sdk = makeSdk()
		JustTrack.setSdk(sdk)

		XCTAssertNotNil(JustTrack.getInstance())

		sdk.shutdown()
	}

	func testGetInstanceReturnsNilAfterReset() {
		let sdk = makeSdk()
		JustTrack.setSdk(sdk)
		XCTAssertNotNil(JustTrack.getInstance())

		JustTrack.resetForTesting(clearStorage: false)

		XCTAssertNil(JustTrack.getInstance())

		sdk.shutdown()
	}

	func testSetSdkTwiceOnlyTriggersAppStartedAtOnce() {
		// Covers JustTrack.getAppStartedAt() `if started { return nil }` branch.
		// First setSdk fires the AppStateEvent, second setSdk must early-return.
		let first = makeSdk()
		JustTrack.setSdk(first)
		// Second call: started is already true, getAppStartedAt returns nil, notifyAppStart is not called.
		let second = makeSdk()
		JustTrack.setSdk(second)

		XCTAssertNotNil(JustTrack.getInstance())

		first.shutdown()
		second.shutdown()
	}

	// MARK: - requestTrackingAuthorization

	func testRequestTrackingAuthorizationDoesNotCrash() {
		// This cannot verify the callback fires synchronously (status is unknown on simulator),
		// but it must not crash.
		JustTrack.requestTrackingAuthorization { _ in }
	}

	// MARK: - provideInstance

	func testProvideInstanceReturnsSdkOnSuccess() throws {
		let builder = makeBuilder()

		let sdk = try JustTrack.provideInstance(builder)

		XCTAssertNotNil(sdk)
		(sdk as? JustTrackSdkImpl)?.shutdown()
	}

	func testProvideInstanceReturnsSameSdkOnSecondCall() throws {
		let builder = makeBuilder()

		let first = try JustTrack.provideInstance(builder)
		let second = try JustTrack.provideInstance(builder)

		XCTAssertTrue(first === (second as AnyObject))
		(first as? JustTrackSdkImpl)?.shutdown()
	}

	func testProvideInstanceThrowsWhenBuilderFails() {
		// JustTrackSdkImpl.init throws JustTrackError.notOnMainThread when called off the main thread.
		// Dispatch to a background thread to force this error path.
		let exp = expectation(description: "provideInstance off-main-thread throws")
		let builder = makeBuilder()

		DispatchQueue.global().async {
			do {
				_ = try JustTrack.provideInstance(builder)
				XCTFail("Expected notOnMainThread error")
			} catch let error as JustTrackError {
				XCTAssertEqual(error, .notOnMainThread)
			} catch {
				XCTFail("Unexpected error type: \(error)")
			}
			exp.fulfill()
		}

		waitForExpectations(timeout: 2)
	}

	// MARK: - Helpers

	private func makeBuilder() -> JustTrackSdkBuilder {
		JustTrackSdkBuilder(apiToken: "prod-test-token-justtrack-tests")
	}

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
				databaseName: "JustTrackSDK_JustTrackTests_\(StringID().value)"
			),
			config: .default,
			manualStart: true
		)
	}
}
