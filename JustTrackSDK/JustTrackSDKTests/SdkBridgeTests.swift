#if DEBUG
	import XCTest

	@testable import JustTrackSDK

	final class SdkBridgeTests: XCTestCase {
		private var logger: MockHttpLogger!
		private var bridge: SdkBridge!

		override func setUp() {
			super.setUp()
			logger = MockHttpLogger()
			bridge = makeBridge()
		}

		override func tearDown() {
			bridge = nil
			logger = nil
			super.tearDown()
		}

		// MARK: - sendLogMessage

		func testSendLogMessageDebugRoutesToDebug() {
			bridge.sendLogMessage(level: "debug", message: "hello debug", fields: [:])
			XCTAssertTrue(logger.entries.contains { $0.level == .debug && $0.message == "hello debug" })
		}

		func testSendLogMessageInfoRoutesToInfo() {
			bridge.sendLogMessage(level: "info", message: "hello info", fields: [:])
			XCTAssertTrue(logger.entries.contains { $0.level == .info && $0.message == "hello info" })
		}

		func testSendLogMessageWarnRoutesToWarn() {
			bridge.sendLogMessage(level: "warn", message: "hello warn", fields: [:])
			XCTAssertTrue(logger.entries.contains { $0.level == .warn && $0.message == "hello warn" })
		}

		func testSendLogMessageErrorRoutesToError() {
			bridge.sendLogMessage(level: "error", message: "hello error", fields: [:])
			XCTAssertTrue(logger.entries.contains { $0.level == .error && $0.message == "hello error" })
		}

		func testSendLogMessagePassesMessageVerbatim() {
			let msg = "a very specific message 🔥"
			bridge.sendLogMessage(level: "info", message: msg, fields: [:])
			XCTAssertTrue(logger.entries.contains { $0.message == msg })
		}

		// MARK: - sendLogMetric

		func testSendLogMetricPublishesCorrectMetricName() {
			bridge.sendLogMetric(metric: "my.metric", value: 1.0, unit: "count", dimensions: [:])
			XCTAssertTrue(logger.entries.contains { $0.level == .metric && $0.message == "my.metric" })
		}

		func testSendLogMetricPublishesCorrectValue() {
			bridge.sendLogMetric(metric: "latency", value: 42.5, unit: "seconds", dimensions: [:])
			let entry = logger.metricEntries.first { $0.name == "latency" }
			XCTAssertEqual(entry?.value, 42.5)
		}

		func testSendLogMetricUsesCountForUnknownUnit() {
			bridge.sendLogMetric(metric: "m", value: 1.0, unit: "unknown_unit", dimensions: [:])
			let entry = logger.metricEntries.first { $0.name == "m" }
			XCTAssertEqual(entry?.unit, MetricUnit.count.rawValue)
		}

		func testSendLogMetricRecognisesSecondsUnit() {
			bridge.sendLogMetric(metric: "m", value: 1.0, unit: "seconds", dimensions: [:])
			let entry = logger.metricEntries.first { $0.name == "m" }
			XCTAssertEqual(entry?.unit, "seconds")
		}

		func testSendLogMetricRecognisesMillisecondsUnit() {
			bridge.sendLogMetric(metric: "m", value: 1.0, unit: "milliseconds", dimensions: [:])
			let entry = logger.metricEntries.first { $0.name == "m" }
			XCTAssertEqual(entry?.unit, "milliseconds")
		}

		// MARK: - getUserId

		func testGetUserIdResolvesWithUserIdOnSuccess() {
			let userId = StringID()
			let future = FutureImpl<AdIds>()
			let localBridge = makeBridge(adIdsFuture: future)

			var resolved: String?
			localBridge.getUserId().observe { result in
				if case let .success(value) = result {
					resolved = value
				}
			}

			future.resolve(AdIds(idfa: nil, userId: userId))

			XCTAssertEqual(resolved, userId.value)
		}

		func testGetUserIdRejectsOnFailure() {
			let future = FutureImpl<AdIds>()
			let localBridge = makeBridge(adIdsFuture: future)

			var didReject = false
			localBridge.getUserId().observe { result in
				if case .failure = result {
					didReject = true
				}
			}

			future.reject(SdkBridgeTestError.someError)

			XCTAssertTrue(didReject)
		}

		func testGetUserIdReturnsAFuture() {
			let result = bridge.getUserId()
			XCTAssertNotNil(result)
		}

		// MARK: - perform

		func testPerformCallsTheAction() {
			var called = false
			bridge.perform { called = true }
			XCTAssertTrue(called)
		}

		func testPerformCallsActionExactlyOnce() {
			var callCount = 0
			bridge.perform { callCount += 1 }
			XCTAssertEqual(callCount, 1)
		}

		// MARK: - sleep

		func testSleepForZeroSecondsReturnsWithoutBlocking() {
			// Darwin.sleep(0) is a no-op — verifies the non-nil path doesn't crash
			bridge.sleep(for: 0)
		}

		// MARK: - sendInternalEvents

		func testSendInternalEventsWithNilSdkDoesNotCrash() {
			// sdk is nil by default — all track calls are guarded by optional chaining
			bridge.sendInternalEvents()
		}

		// MARK: - Helpers

		private func makeBridge(adIdsFuture: FutureImpl<AdIds>? = nil) -> SdkBridge {
			SdkBridge(
				sdk: nil,
				httpLogger: logger,
				getAdIdsResult: adIdsFuture ?? FutureImpl<AdIds>()
			)
		}
	}

	private enum SdkBridgeTestError: Error {
		case someError
	}
#endif
