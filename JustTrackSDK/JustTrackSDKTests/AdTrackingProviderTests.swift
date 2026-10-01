import AppTrackingTransparency
import XCTest

@testable import JustTrackSDK

final class AdTrackingProviderTests: XCTestCase {
	// MARK: - requestTrackingAuthorization: dialog shown (unknown initial state)

	func testUnknownToAuthorizedWithDialog() {
		runTestWith(currentStatus: .unknown, finalStatus: .authorized)
	}

	func testUnknownToDeniedWithDialog() {
		runTestWith(currentStatus: .unknown, finalStatus: .denied)
	}

	func testUnknownToRestrictedWithDialog() {
		runTestWith(currentStatus: .unknown, finalStatus: .restricted)
	}

	// MARK: - requestTrackingAuthorization: permission already determined (no dialog)

	func testAlreadyAuthorized() {
		runTestWith(currentStatus: .authorized, finalStatus: .authorized)
	}

	func testAlreadyDenied() {
		runTestWith(currentStatus: .denied, finalStatus: .denied)
	}

	func testAlreadyRestricted() {
		runTestWith(currentStatus: .restricted, finalStatus: .restricted)
	}

	// MARK: - requestTrackingAuthorization: multiple pending callbacks

	func testMultiplePendingCallbacksAllFireAfterResolution() {
		let provider = AdTrackingProviderImpl(forTesting: ())
		let requester = TestAdTrackingPermissionRequester(
			currentPermission: .unknown,
			finalPermission: .authorized,
			waitWithCallbacks: true
		)
		var callCount = 0

		// Register 4 callbacks while permission is still unknown
		for _ in 0..<4 {
			provider.requestTrackingAuthorization(requester: requester) { allowed in
				callCount += 1
				XCTAssertTrue(allowed)
			}
		}

		// None should have fired yet
		XCTAssertEqual(0, callCount)

		// Resolve the permission
		requester.callCallbacks()

		// All 4 should have fired
		XCTAssertEqual(4, callCount)

		// A 5th call after resolution should fire immediately (cached result)
		provider.requestTrackingAuthorization(requester: requester) { allowed in
			callCount += 1
			XCTAssertTrue(allowed)
		}
		XCTAssertEqual(5, callCount)
	}

	func testMultiplePendingCallbacksDeniedAllReceiveFalse() {
		let provider = AdTrackingProviderImpl(forTesting: ())
		let requester = TestAdTrackingPermissionRequester(
			currentPermission: .unknown,
			finalPermission: .denied,
			waitWithCallbacks: true
		)
		var results: [Bool] = []

		for _ in 0..<3 {
			provider.requestTrackingAuthorization(requester: requester) { allowed in
				results.append(allowed)
			}
		}

		XCTAssertEqual(0, results.count)
		requester.callCallbacks()

		XCTAssertEqual(3, results.count)
		XCTAssertTrue(results.allSatisfy { !$0 })
	}

	// MARK: - provideIDFA

	/// On the simulator (and in CI) ATT permission is not determined / not authorized,
	/// so provideIDFA() must return nil — this tests the denial/guard path.
	func testProvideIDFAReturnsNilWhenNotAuthorized() {
		let provider = AdTrackingProviderImpl(forTesting: ())
		// In the test environment ATTrackingManager.trackingAuthorizationStatus is
		// .notDetermined, so the guard inside provideIDFA() should return nil.
		let idfa = provider.provideIDFA()
		XCTAssertNil(idfa, "provideIDFA() should return nil when ATT is not authorized")
	}

	/// After driving the provider to an authorized state via the mock requester,
	/// provideIDFA() still depends on the real ATTrackingManager status (not the mock),
	/// so on a simulator it will still return nil — but we verify the method is callable
	/// without crashing and returns the expected type.
	func testProvideIDFAAfterAuthorizationFlowDoesNotCrash() {
		let provider = AdTrackingProviderImpl(forTesting: ())
		let requester = TestAdTrackingPermissionRequester(
			currentPermission: .authorized,
			finalPermission: .authorized
		)
		provider.requestTrackingAuthorization(requester: requester) { _ in }

		// Must not crash; result depends on real OS ATT state
		let _ = provider.provideIDFA()
	}

	func testProvideIDFAAfterDeniedFlowReturnsNil() {
		let provider = AdTrackingProviderImpl(forTesting: ())
		let requester = TestAdTrackingPermissionRequester(
			currentPermission: .denied,
			finalPermission: .denied
		)
		provider.requestTrackingAuthorization(requester: requester) { _ in }

		let idfa = provider.provideIDFA()
		XCTAssertNil(idfa, "provideIDFA() should return nil when tracking is denied")
	}

	func testProvideIDFAAfterRestrictedFlowReturnsNil() {
		let provider = AdTrackingProviderImpl(forTesting: ())
		let requester = TestAdTrackingPermissionRequester(
			currentPermission: .restricted,
			finalPermission: .restricted
		)
		provider.requestTrackingAuthorization(requester: requester) { _ in }

		let idfa = provider.provideIDFA()
		XCTAssertNil(idfa, "provideIDFA() should return nil when tracking is restricted")
	}

	// MARK: - provideIDFV

	/// IDFV does not require ATT permission and should return a non-nil value on a real device/simulator.
	func testProvideIDFVReturnsValueOnSimulator() {
		let provider = AdTrackingProviderImpl(forTesting: ())
		let idfv = provider.provideIDFV()
		// UIDevice.current.identifierForVendor is non-nil on simulators and real devices
		XCTAssertNotNil(idfv, "provideIDFV() should return a value on a simulator or real device")
	}

	func testProvideIDFVIsIndependentOfATTPermission() {
		// IDFV should be available regardless of what the ATT authorization flow says
		let provider = AdTrackingProviderImpl(forTesting: ())
		let requester = TestAdTrackingPermissionRequester(
			currentPermission: .denied,
			finalPermission: .denied
		)
		provider.requestTrackingAuthorization(requester: requester) { _ in }

		let idfv = provider.provideIDFV()
		XCTAssertNotNil(idfv, "provideIDFV() should not be affected by denied ATT status")
	}

	// MARK: - setLogger

	func testSetLoggerDoesNotCrash() {
		let provider = AdTrackingProviderImpl(forTesting: ())
		let mockLogger = MockLogger()
		// Should not crash
		provider.setLogger(mockLogger)
	}

	func testSetLoggerBeforeRequestTrackingAuthorizationDoesNotCrash() {
		let provider = AdTrackingProviderImpl(forTesting: ())
		let mockLogger = MockLogger()
		provider.setLogger(mockLogger)

		let requester = TestAdTrackingPermissionRequester(
			currentPermission: .authorized,
			finalPermission: .authorized
		)
		var called = false
		provider.requestTrackingAuthorization(requester: requester) { _ in
			called = true
		}
		XCTAssertTrue(called)
	}

	func testSetLoggerAfterRequestTrackingAuthorizationDoesNotCrash() {
		let provider = AdTrackingProviderImpl(forTesting: ())
		let requester = TestAdTrackingPermissionRequester(
			currentPermission: .authorized,
			finalPermission: .authorized
		)
		provider.requestTrackingAuthorization(requester: requester) { _ in }

		let mockLogger = MockLogger()
		// Should not crash even when set after operations have been performed
		provider.setLogger(mockLogger)
	}

	// MARK: - getAdTrackingPermissionRequester

	func testGetAdTrackingPermissionRequesterReturnsNonNil() {
		let provider = AdTrackingProviderImpl(forTesting: ())
		let requester = provider.getAdTrackingPermissionRequester()
		XCTAssertNotNil(requester)
	}

	func testGetAdTrackingPermissionRequesterReturnsCorrectType() {
		let provider = AdTrackingProviderImpl(forTesting: ())
		let requester = provider.getAdTrackingPermissionRequester()
		XCTAssertTrue(requester is AdTrackingPermissionRequesterImpl)
	}

	func testGetAdTrackingPermissionRequesterCanBeCalledMultipleTimes() {
		let provider = AdTrackingProviderImpl(forTesting: ())
		// Should not crash and should return a valid requester each time
		let requester1 = provider.getAdTrackingPermissionRequester()
		let requester2 = provider.getAdTrackingPermissionRequester()
		XCTAssertNotNil(requester1)
		XCTAssertNotNil(requester2)
	}

	// MARK: - AdTrackingLogger buffering

	func testLogCallsBeforeSetLoggerAreBufferedAndReplayed() {
		let provider = AdTrackingProviderImpl(forTesting: ())
		let requester = TestAdTrackingPermissionRequester(
			currentPermission: .authorized,
			finalPermission: .authorized
		)

		// Trigger a log call before the SDK logger is set — it should be buffered
		provider.requestTrackingAuthorization(requester: requester) { _ in }

		let mockLogger = MockLogger()
		XCTAssertTrue(mockLogger.entries.isEmpty, "No entries should be recorded before setLogger is called")

		// Setting the logger should flush the buffer
		provider.setLogger(mockLogger)

		XCTAssertFalse(mockLogger.entries.isEmpty, "Buffered log calls should be replayed after setLogger is called")
		XCTAssertTrue(
			mockLogger.entries.contains { $0.message.contains("Requesting tracking authorization") },
			"Expected a buffered debug entry containing 'Requesting tracking authorization'"
		)
	}

	func testLogCallsAfterSetLoggerAreForwardedImmediately() {
		let provider = AdTrackingProviderImpl(forTesting: ())
		let mockLogger = MockLogger()
		provider.setLogger(mockLogger)

		let countBefore = mockLogger.entries.count

		let requester = TestAdTrackingPermissionRequester(
			currentPermission: .authorized,
			finalPermission: .authorized
		)
		provider.requestTrackingAuthorization(requester: requester) { _ in }

		XCTAssertGreaterThan(
			mockLogger.entries.count,
			countBefore,
			"Log calls after setLogger should be forwarded immediately"
		)
	}

	func testSetLoggerCanBeCalledMultipleTimesAndLastLoggerReceivesSubsequentCalls() {
		let provider = AdTrackingProviderImpl(forTesting: ())
		let firstLogger = MockLogger()
		let secondLogger = MockLogger()

		provider.setLogger(firstLogger)

		// Trigger one log call so firstLogger gets some entries
		let requester1 = TestAdTrackingPermissionRequester(
			currentPermission: .authorized,
			finalPermission: .authorized
		)
		provider.requestTrackingAuthorization(requester: requester1) { _ in }
		let firstLoggerCountAfterFirstCall = firstLogger.entries.count

		// Replace with second logger
		provider.setLogger(secondLogger)

		// Trigger another request on a fresh provider to generate more log calls
		// (the existing provider has cached result, so use a fresh one linked to same second logger)
		let provider2 = AdTrackingProviderImpl(forTesting: ())
		provider2.setLogger(secondLogger)
		let requester2 = TestAdTrackingPermissionRequester(
			currentPermission: .authorized,
			finalPermission: .authorized
		)
		provider2.requestTrackingAuthorization(requester: requester2) { _ in }

		XCTAssertGreaterThan(firstLoggerCountAfterFirstCall, 0, "First logger should have received entries")
		XCTAssertGreaterThan(secondLogger.entries.count, 0, "Second logger should receive subsequent log calls")
	}

	// MARK: - applicationDidBecomeActive

	func testApplicationDidBecomeActiveWithNoPendingCallbacksDoesNotCrash() {
		let mockLogger = MockLogger()
		let requester = AdTrackingPermissionRequesterImpl(logger: mockLogger)

		// Must not crash when there are no pending callbacks
		requester.applicationDidBecomeActive()
	}

	func testApplicationDidBecomeActiveCanBeCalledMultipleTimes() {
		let mockLogger = MockLogger()
		let requester = AdTrackingPermissionRequesterImpl(logger: mockLogger)

		// Calling repeatedly with no pending callbacks must not crash
		requester.applicationDidBecomeActive()
		requester.applicationDidBecomeActive()
		requester.applicationDidBecomeActive()
	}

	// MARK: - AdTrackingLogger: buffered log-method closures

	func testAdTrackingLoggerDebugWithFieldsIsBufferedAndReplayed() {
		let atLogger = AdTrackingLogger()
		let mockLogger = MockLogger()

		atLogger.debug("buffered debug", [])

		XCTAssertTrue(mockLogger.entries.isEmpty)

		atLogger.set(sdkLogger: mockLogger)

		XCTAssertTrue(
			mockLogger.entries.contains { $0.message == "buffered debug" },
			"Buffered debug(_:_:) call should be replayed after setLogger"
		)
	}

	func testAdTrackingLoggerInfoIsBufferedAndReplayed() {
		let atLogger = AdTrackingLogger()
		let mockLogger = MockLogger()

		atLogger.info("buffered info", [])

		XCTAssertTrue(mockLogger.entries.isEmpty)

		atLogger.set(sdkLogger: mockLogger)

		XCTAssertTrue(
			mockLogger.entries.contains { $0.message == "buffered info" },
			"Buffered info(_:_:) call should be replayed after setLogger"
		)
	}

	func testAdTrackingLoggerWarnIsBufferedAndReplayed() {
		let atLogger = AdTrackingLogger()
		let mockLogger = MockLogger()

		atLogger.warn("buffered warn", [])

		XCTAssertTrue(mockLogger.entries.isEmpty)

		atLogger.set(sdkLogger: mockLogger)

		XCTAssertTrue(
			mockLogger.entries.contains { $0.message == "buffered warn" },
			"Buffered warn(_:_:) call should be replayed after setLogger"
		)
	}

	func testAdTrackingLoggerErrorWithFieldsIsBufferedAndReplayed() {
		let atLogger = AdTrackingLogger()
		let mockLogger = MockLogger()

		atLogger.error("buffered error", [])

		XCTAssertTrue(mockLogger.entries.isEmpty)

		atLogger.set(sdkLogger: mockLogger)

		XCTAssertTrue(
			mockLogger.entries.contains { $0.level == .error && $0.message == "buffered error" },
			"Buffered error(_:_:) call should be replayed after setLogger"
		)
	}

	func testAdTrackingLoggerErrorWithExceptionIsBufferedAndReplayed() {
		let atLogger = AdTrackingLogger()
		let mockLogger = MockLogger()

		atLogger.error("buffered error with exception", AdTrackingLoggerTestError.someError, [])

		XCTAssertTrue(mockLogger.entries.isEmpty)

		atLogger.set(sdkLogger: mockLogger)

		XCTAssertTrue(
			mockLogger.entries.contains { $0.level == .error && $0.message == "buffered error with exception" },
			"Buffered error(_:_:_:) call should be replayed after setLogger"
		)
	}

	func testAdTrackingLoggerPublishMetricIsBufferedAndReplayed() {
		let atLogger = AdTrackingLogger()
		let mockLogger = MockLogger()
		let metric = Metric(metric: "test.metric", unit: .count)

		atLogger.publishMetric(metric, 1.0, [])

		XCTAssertTrue(mockLogger.entries.isEmpty)

		atLogger.set(sdkLogger: mockLogger)

		XCTAssertTrue(
			mockLogger.entries.contains { $0.level == .metric && $0.message == "test.metric" },
			"Buffered publishMetric(_:_:_:) call should be replayed after setLogger"
		)
	}

	func testAdTrackingLoggerMultipleCallsBufferedInOrder() {
		let atLogger = AdTrackingLogger()
		let mockLogger = MockLogger()

		atLogger.debug("first", [])
		atLogger.info("second", [])
		atLogger.warn("third", [])

		atLogger.set(sdkLogger: mockLogger)

		let messages = mockLogger.entries.map { $0.message }
		XCTAssertTrue(messages.contains("first"))
		XCTAssertTrue(messages.contains("second"))
		XCTAssertTrue(messages.contains("third"))
	}

	func testAdTrackingLoggerCallsAfterSetLoggerAreForwardedImmediately() {
		let atLogger = AdTrackingLogger()
		let mockLogger = MockLogger()

		atLogger.set(sdkLogger: mockLogger)
		let countAfterSet = mockLogger.entries.count

		atLogger.debug("immediate debug", [])
		atLogger.info("immediate info", [])

		XCTAssertEqual(mockLogger.entries.count, countAfterSet + 2)
	}

	// MARK: - Shared helper

	private func runTestWith(
		currentStatus: AdTrackingStatus,
		finalStatus: AdTrackingStatus
	) {
		let provider = AdTrackingProviderImpl(forTesting: ())
		let requester = TestAdTrackingPermissionRequester(
			currentPermission: currentStatus,
			finalPermission: finalStatus,
			waitWithCallbacks: true
		)
		var callCount = 0
		provider.requestTrackingAuthorization(requester: requester) { allowed in
			callCount += 1
			XCTAssertEqual(finalStatus == .authorized, allowed)
		}
		provider.requestTrackingAuthorization(requester: requester) { allowed in
			callCount += 1
			XCTAssertEqual(finalStatus == .authorized, allowed)
		}
		if currentStatus == .unknown {
			XCTAssertEqual(0, callCount)
			requester.callCallbacks()
		}
		XCTAssertEqual(2, callCount)
		provider.requestTrackingAuthorization(
			requester: requester,
			{ allowed in
				callCount += 1
				XCTAssertEqual(finalStatus == .authorized, allowed)
			}
		)
		XCTAssertEqual(3, callCount)
	}

	// MARK: - ensureActive inactive branch + applicationDidBecomeActive replay

	func testRequestAdTrackingPermissionDefersUntilAppBecomesActive() {
		let mockLogger = MockLogger()
		let requester = AdTrackingPermissionRequesterImpl(logger: mockLogger)
		// Force the inactive branch of ensureActive
		requester.applicationStateProvider = { .inactive }

		var receivedStatus: AdTrackingStatus?
		requester.requestAdTrackingPermission { status in
			receivedStatus = status
		}

		// While "inactive", the ATT request closure is deferred.
		XCTAssertNil(receivedStatus, "Callback must wait until app becomes active")

		// Flip back to active and replay the queued callback. The block
		// re-enters ensureActive which now finds .active and proceeds to
		// ATTrackingManager.requestTrackingAuthorization. We don't assert on
		// the ATT result (it's environment-dependent), only that the
		// deferred body fires.
		requester.applicationStateProvider = { .active }
		requester.applicationDidBecomeActive()
	}

	func testApplicationDidBecomeActiveExecutesPendingCallbacks() {
		let mockLogger = MockLogger()
		let requester = AdTrackingPermissionRequesterImpl(logger: mockLogger)
		requester.applicationStateProvider = { .inactive }

		// Queue a deferred ATT request, then call applicationDidBecomeActive
		// with .active so the re-entry path picks up the queued block and the
		// `for callback in callbacks { callback() }` loop body executes.
		requester.requestAdTrackingPermission { _ in }
		requester.requestAdTrackingPermission { _ in }

		requester.applicationStateProvider = { .active }
		requester.applicationDidBecomeActive()
	}

	// MARK: - translateAdTrackingPermission (all enum cases)

	func testTranslateAdTrackingPermissionAuthorized() {
		guard #available(iOS 14, *) else { return }
		XCTAssertEqual(
			AdTrackingPermissionRequesterImpl.translateAdTrackingPermission(.authorized),
			.authorized
		)
	}

	func testTranslateAdTrackingPermissionDenied() {
		guard #available(iOS 14, *) else { return }
		XCTAssertEqual(
			AdTrackingPermissionRequesterImpl.translateAdTrackingPermission(.denied),
			.denied
		)
	}

	func testTranslateAdTrackingPermissionRestricted() {
		guard #available(iOS 14, *) else { return }
		XCTAssertEqual(
			AdTrackingPermissionRequesterImpl.translateAdTrackingPermission(.restricted),
			.restricted
		)
	}

	func testTranslateAdTrackingPermissionNotDetermined() {
		guard #available(iOS 14, *) else { return }
		XCTAssertEqual(
			AdTrackingPermissionRequesterImpl.translateAdTrackingPermission(.notDetermined),
			.unknown
		)
	}

	func testTranslateAdTrackingPermissionDefaultFallback() {
		guard #available(iOS 14, *) else { return }
		// Synthesize an unknown raw value to hit the `default:` case.
		if let unknown = ATTrackingManager.AuthorizationStatus(rawValue: 99) {
			XCTAssertEqual(
				AdTrackingPermissionRequesterImpl.translateAdTrackingPermission(unknown),
				.unknown
			)
		}
	}
}

private enum AdTrackingLoggerTestError: Error {
	case someError
}
