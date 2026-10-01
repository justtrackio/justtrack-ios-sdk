import Foundation
import XCTest

@testable import JustTrackSDK

final class HttpLoggerTests: XCTestCase {
	private lazy var httpLogger = HttpLoggerImpl(
		fallback: logger,
		logApi: logApi,
		logAggregator: logAggregator,
		installId: userData.installId,
		adIdsProvider: { [unowned self] in FutureImpl<AdIds>().fulfill(.success(AdIds(idfa: self.idfa, userId: self.userData.userId))) },
		dateProvider: { [unowned self] in self.date },
		appVersionProvider: { [unowned self] in self.appVersion },
		sdkVersionProvider: { [unowned self] in self.sdkVersion }
	)

	private var logger = LoggerImpl()
	private var logApi = MockLogApi()
	private lazy var logAggregator: LogAggregator = LogAggregatorImpl(queue: logAggregatorQueue, sqliteDriver: sqliteDriver)
	private var logAggregatorQueue = DispatchQueue(label: "io.justtrack.JustTrackSDK.LogAggregatorImpl.queue", qos: .userInteractive)
	private var idfa: StringID?
	private var userData: UserData = .fixture()
	private var date = Date(timeIntervalSince1970: 41)
	private var appVersion: AppVersion = AppVersionImpl(code: "1", name: "1.1.0")
	private var sdkVersion: any Version = VersionImpl(major: 1, minor: 1, patch: 1, name: "1.1.1-test")
	private lazy var sqliteDriver = try! DefaultSqliteDriver(databaseName: UUID().uuidString)

	override class func setUp() {
		JustTrack.resetForTesting(clearStorage: true)
		try? clearDocumentsDirectory()
	}

	func testHttpLoggerSendsInfoLogsToServerWithoutFilteringWhenLogConfigIsNotSet() {
		httpLogger.info(
			"message_1",
			[LoggerFieldsImpl().with("field_1_1", "value_1_1").with("field_1_2", "value_1_2")]
		)
		httpLogger.info(
			"message_2",
			[LoggerFieldsImpl().with("field_2_1", "value_2_1").with("field_2_2", "value_2_2")]
		)
		httpLogger.info(
			"message_3",
			[LoggerFieldsImpl().with("field_3_1", "value_3_1").with("field_3_2", "value_3_2")]
		)

		httpLogger.sendToServer()

		waitForExpectation(#function)

		XCTAssertEqual(
			logApi.calls,
			[
				MockLogApi.Call.sendLogs(
					input: DTOLogInput(
						messages: [
							DTOLogMessage(
								"info",
								"message_1",
								[
									"field_1_1": "value_1_1",
									"field_1_2": "value_1_2",
								],
								date
							),
							DTOLogMessage(
								"info",
								"message_2",
								[
									"field_2_1": "value_2_1",
									"field_2_2": "value_2_2",
								],
								date
							),
							DTOLogMessage(
								"info",
								"message_3",
								[
									"field_3_1": "value_3_1",
									"field_3_2": "value_3_2",
								],
								date
							),
						],
						metrics: [],
						appVersion: .fixture(code: "1", name: "1.1.0"),
						sdkVersion: .fixture(name: "1.1.1-test"),
						clientDate: date
					),
					userData: userData
				)
			]
		)
	}

	func testHttpLoggerSendsWarnLogsToServerWithoutFilteringWhenLogConfigIsNotSet() {
		httpLogger.warn(
			"message_1",
			[LoggerFieldsImpl().with("field_1_1", "value_1_1").with("field_1_2", "value_1_2")]
		)
		httpLogger.warn(
			"message_2",
			[LoggerFieldsImpl().with("field_2_1", "value_2_1").with("field_2_2", "value_2_2")]
		)
		httpLogger.warn(
			"message_3",
			[LoggerFieldsImpl().with("field_3_1", "value_3_1").with("field_3_2", "value_3_2")]
		)

		httpLogger.sendToServer()

		waitForExpectation(#function)

		XCTAssertEqual(
			logApi.calls,
			[
				MockLogApi.Call.sendLogs(
					input: DTOLogInput(
						messages: [
							DTOLogMessage(
								"warn",
								"message_1",
								[
									"field_1_1": "value_1_1",
									"field_1_2": "value_1_2",
								],
								date
							),
							DTOLogMessage(
								"warn",
								"message_2",
								[
									"field_2_1": "value_2_1",
									"field_2_2": "value_2_2",
								],
								date
							),
							DTOLogMessage(
								"warn",
								"message_3",
								[
									"field_3_1": "value_3_1",
									"field_3_2": "value_3_2",
								],
								date
							),
						],
						metrics: [
							.fixture(metric: "Warnings"),
							.fixture(metric: "Warnings"),
							.fixture(metric: "Warnings"),
						],
						appVersion: .fixture(code: "1", name: "1.1.0"),
						sdkVersion: .fixture(name: "1.1.1-test"),
						clientDate: date
					),
					userData: userData
				)
			]
		)
	}

	func testHttpLoggerSendsErrorLogsToServerWithoutFilteringWhenLogConfigIsNotSet() {
		httpLogger.error(
			"message_1",
			[LoggerFieldsImpl().with("field_1_1", "value_1_1").with("field_1_2", "value_1_2")]
		)
		httpLogger.error(
			"message_2",
			[LoggerFieldsImpl().with("field_2_1", "value_2_1").with("field_2_2", "value_2_2")]
		)
		httpLogger.error(
			"message_3",
			[LoggerFieldsImpl().with("field_3_1", "value_3_1").with("field_3_2", "value_3_2")]
		)

		httpLogger.sendToServer()

		waitForExpectation(#function)

		XCTAssertEqual(
			logApi.calls,
			[
				MockLogApi.Call.sendLogs(
					input: DTOLogInput(
						messages: [
							DTOLogMessage(
								"error",
								"message_1",
								[
									"field_1_1": "value_1_1",
									"field_1_2": "value_1_2",
								],
								date
							),
							DTOLogMessage(
								"error",
								"message_2",
								[
									"field_2_1": "value_2_1",
									"field_2_2": "value_2_2",
								],
								date
							),
							DTOLogMessage(
								"error",
								"message_3",
								[
									"field_3_1": "value_3_1",
									"field_3_2": "value_3_2",
								],
								date
							),
						],
						metrics: [
							.fixture(metric: "Errors"),
							.fixture(metric: "Errors"),
							.fixture(metric: "Errors"),
						],
						appVersion: .fixture(code: "1", name: "1.1.0"),
						sdkVersion: .fixture(name: "1.1.1-test"),
						clientDate: date
					),
					userData: userData
				)
			]
		)
	}

	func testHttpLoggerSendsMetricsToServerWithoutFilteringWhenMetricConfigIsNotSet() {
		httpLogger.publishMetric(
			Metric(
				metric: "metric_1",
				defaultDimensions: ["dimension_1": "value_1"],
				unit: .count
			),
			12,
			[LoggerFieldsImpl().with("field_1", "value_1")]
		)
		httpLogger.publishMetric(
			Metric(
				metric: "metric_2",
				defaultDimensions: ["dimension_1": "value_1"],
				unit: .count
			),
			12,
			[LoggerFieldsImpl().with("field_1", "value_1")]
		)
		httpLogger.publishMetric(
			Metric(
				metric: "metric_3",
				defaultDimensions: ["dimension_1": "value_1"],
				unit: .count
			),
			12,
			[LoggerFieldsImpl().with("field_1", "value_1")]
		)

		httpLogger.sendToServer()

		waitForExpectation(#function)

		XCTAssertEqual(
			logApi.calls,
			[
				MockLogApi.Call.sendLogs(
					input: DTOLogInput(
						messages: [],
						metrics: [
							DTOLogMetric(
								"metric_1",
								[
									"dimension_1": "value_1",
									"field_1": "value_1",
								],
								12,
								"Count",
								date
							),
							DTOLogMetric(
								"metric_2",
								[
									"dimension_1": "value_1",
									"field_1": "value_1",
								],
								12,
								"Count",
								date
							),
							DTOLogMetric(
								"metric_3",
								[
									"dimension_1": "value_1",
									"field_1": "value_1",
								],
								12,
								"Count",
								date
							),
						],
						appVersion: .fixture(code: "1", name: "1.1.0"),
						sdkVersion: .fixture(name: "1.1.1-test"),
						clientDate: date
					),
					userData: userData
				)
			]
		)
	}

	// MARK: - sdkIsRunning guard branches

	func testHttpLoggerDoesNotLogWhenSdkIsNotRunning() {
		httpLogger.sdkIsRunning = { false }

		httpLogger.info("should be dropped", [])
		httpLogger.warn("should be dropped", [])
		httpLogger.error("should be dropped", [])
		httpLogger.debug("should be dropped", [])
		httpLogger.sendToServer()

		waitForExpectation(#function)

		XCTAssertTrue(logApi.calls.isEmpty, "No calls should be made when sdk is not running")
	}

	func testHttpLoggerDoesNotSendToServerWhenSdkIsNotRunning() {
		// Put something in the aggregator first while running, then stop, then sendToServer
		httpLogger.info("message", [])
		httpLogger.sdkIsRunning = { false }
		httpLogger.sendToServer()

		// Give time for any async work
		waitForExpectation(#function)

		// sendToServer was called while not running → logAggregator.sendLogsAndMetrics was not called
		// (the guard returns early). The previous info message is still in the aggregator unflushed.
		XCTAssertTrue(logApi.calls.isEmpty)
	}

	// MARK: - performServerRequest adIds failure

	func testHttpLoggerHandlesAdIdsFailureGracefully() {
		let failingAdIdsLogger = HttpLoggerImpl(
			fallback: logger,
			logApi: logApi,
			logAggregator: logAggregator,
			installId: userData.installId,
			adIdsProvider: {
				FutureImpl<AdIds>().fulfill(.failure(NSError(domain: "test", code: 42)))
			},
			dateProvider: { [unowned self] in self.date },
			appVersionProvider: { [unowned self] in self.appVersion },
			sdkVersionProvider: { [unowned self] in self.sdkVersion }
		)

		failingAdIdsLogger.info("message", [])
		failingAdIdsLogger.sendToServer()

		waitForExpectation(#function)

		// adIds failed → logApi.sendLogs should never have been called
		XCTAssertTrue(logApi.calls.isEmpty)
	}

	// MARK: - default dateProvider closure (arg 6)

	func testHttpLoggerDefaultDateProviderIsUsed() {
		// Instantiate without specifying dateProvider — exercises the default closure
		let loggerWithDefaults = HttpLoggerImpl(
			fallback: logger,
			logApi: logApi,
			logAggregator: logAggregator,
			installId: userData.installId,
			adIdsProvider: { [unowned self] in
				FutureImpl<AdIds>().fulfill(.success(AdIds(idfa: self.idfa, userId: self.userData.userId)))
			}
		)

		loggerWithDefaults.info("hello from default date provider", [])
		loggerWithDefaults.sendToServer()

		waitForExpectation(#function)

		XCTAssertEqual(logApi.calls.count, 1)
		if case let .sendLogs(input, _) = logApi.calls.first {
			XCTAssertEqual(input.messages.count, 1)
			// The date string should be non-empty (default provider returned current time)
			XCTAssertFalse(input.clientDate.isEmpty)
		} else {
			XCTFail("Expected sendLogs call")
		}
	}

	// MARK: - performServerRequest empty-after-filter early return

	private func waitForExpectation(
		_ name: String
	) {
		let expectation = expectation(description: name)
		logAggregatorQueue.async {
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
	}
}
