import Foundation
import XCTest

@testable import JustTrackSDK

final class HttpLoggerTests: XCTestCase {
	private lazy var httpLogger = HttpLoggerImpl(
		fallback: logger,
		httpClient: httpClient,
		logAggregator: logAggregator,
		installId: userData.installId,
		adIdsProvider: { [unowned self] in FutureImpl<AdIds>().fulfill(.success(AdIds(idfa: self.idfa, userId: self.userData.userId))) },
		dateProvider: { [unowned self] in self.date },
		appVersionProvider: { [unowned self] in self.appVersion },
		sdkVersionProvider: { [unowned self] in self.sdkVersion }
	)

	private var logger = LoggerImpl()
	private var httpClient = MockHttpClient()
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
			httpClient.calls,
			[
				MockHttpClient.Call.sendLogs(
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

	func testHttpLoggerSendsInfoLogsToServerWithFilteringWhenLogConfigWithRulesIsSet() {
		httpLogger.setRules(
			logConfig: .fixture(
				rules: [
					AttributionOutputSdkConfig.Rule(
						name: "message_1",
						drop: false,
						dimensions: [:]
					),
					AttributionOutputSdkConfig.Rule(
						name: "message_2",
						drop: true,
						dimensions: ["field_2_1": "^.*$", "field_2_2": "^val.*$"]
					),
				]
			),
			metricConfig: nil
		)
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
			httpClient.calls,
			[
				MockHttpClient.Call.sendLogs(
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
			httpClient.calls,
			[
				MockHttpClient.Call.sendLogs(
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

	func testHttpLoggerSendsWarnLogsToServerWithFilteringWhenLogConfigWithRulesIsSet() {
		httpLogger.setRules(
			logConfig: .fixture(
				rules: [
					AttributionOutputSdkConfig.Rule(
						name: "message_1",
						drop: true,
						dimensions: [:]
					),
					AttributionOutputSdkConfig.Rule(
						name: "message_2",
						drop: true,
						dimensions: ["field_2_1": "^.*_1$", "field_2_2": "value_2_2"]
					),
				]
			),
			metricConfig: nil
		)
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
			httpClient.calls,
			[
				MockHttpClient.Call.sendLogs(
					input: DTOLogInput(
						messages: [
							DTOLogMessage(
								"warn",
								"message_3",
								[
									"field_3_1": "value_3_1",
									"field_3_2": "value_3_2",
								],
								date
							)
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
			httpClient.calls,
			[
				MockHttpClient.Call.sendLogs(
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

	func testHttpLoggerSendsErrorLogsToServerWithFilteringWhenLogConfigWithRulesIsSet() {
		httpLogger.setRules(
			logConfig: .fixture(
				rules: [
					AttributionOutputSdkConfig.Rule(
						name: "message_1",
						drop: true,
						dimensions: [:]
					),
					AttributionOutputSdkConfig.Rule(
						name: "message_2",
						drop: true,
						dimensions: ["field_2_1": "^.*_1$", "field_2_2": "value_2_2"]
					),
				]
			),
			metricConfig: nil
		)
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
			httpClient.calls,
			[
				MockHttpClient.Call.sendLogs(
					input: DTOLogInput(
						messages: [
							DTOLogMessage(
								"error",
								"message_3",
								[
									"field_3_1": "value_3_1",
									"field_3_2": "value_3_2",
								],
								date
							)
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
			httpClient.calls,
			[
				MockHttpClient.Call.sendLogs(
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

	func testHttpLoggerSendsMetricsToServerWithFilteringWhenMetricConfigIsSet() {
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
		httpLogger.setRules(
			logConfig: nil,
			metricConfig: AttributionOutputSdkConfig.Metric(
				rules: [
					AttributionOutputSdkConfig.Rule(
						name: "metric_1",
						drop: true,
						dimensions: [:]
					),
					AttributionOutputSdkConfig.Rule(
						name: "metric_2",
						drop: true,
						dimensions: ["dimension_1": "^.*_1$"]
					),
					AttributionOutputSdkConfig.Rule(
						name: "metric_3",
						drop: true,
						dimensions: ["dimension_1": "^.*_1$", "field_2": "^.*$"]
					),
				]
			)
		)

		httpLogger.sendToServer()

		waitForExpectation(#function)

		XCTAssertEqual(
			httpClient.calls,
			[
				MockHttpClient.Call.sendLogs(
					input: DTOLogInput(
						messages: [],
						metrics: [
							DTOLogMetric(
								"metric_3",
								[
									"dimension_1": "value_1",
									"field_1": "value_1",
								],
								12,
								"Count",
								date
							)
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
