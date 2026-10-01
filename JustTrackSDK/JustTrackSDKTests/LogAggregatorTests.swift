import XCTest

@testable import JustTrackSDK

final class LogAggregatorTests: XCTestCase {
	static let apiToken = TestCredentials.apiToken
	static let clientId = TestCredentials.clientId
	static let trackingData = ("1-23456notatrackingid", "provider")
	static let idfa = StringID()
	static let idfv = StringID(value: UUID().uuidString.lowercased().dropLast(3) + "6ed")!

	func testStoreAndRetrieveLogsAndMetrics() {
		withFailureCount { failureCount in
			LogStore().clearForTesting()

			let message = DTOLogMessage("level", "this is a test", [:], Date())
			let metric = DTOLogMetric("metric", [:], 42.0, MetricUnit.count.getUnit(), Date())

			let aggregator = LogAggregatorImpl(
				sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)")
			)
			aggregator.addLog(message: message)
			aggregator.addLog(metric: metric)

			let (storedMessages, storedMetrics) = consume(aggregator: aggregator, failureCount: failureCount)
			XCTAssertEqual([message], storedMessages)
			XCTAssertEqual([metric], storedMetrics)

			let (remainingMessages, remainingMetrics) = consume(aggregator: aggregator, failureCount: failureCount)
			XCTAssertEqual(0, remainingMessages.count)
			XCTAssertEqual(0, remainingMetrics.count)
		}
	}

	func testStoreTooManyLogs() {
		LogStore().clearForTesting()
		let aggregator = LogAggregatorImpl(
			maxBlockCount: 10,
			maxBlockSize: 10,
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)")
		)

		// store more messages than we want to keep
		let messageCount = 110
		for i in 0..<messageCount {
			let message = DTOLogMessage(
				"level",
				"message",
				[
					"number": "\(i)"
				],
				Date()
			)
			aggregator.addLog(message: message)
		}

		var messageNumbers: [String] = []

		// Retrieve all stored messages
		while messageNumbers.count < 100 {
			aggregator.sendLogsAndMetrics { (storedMessages, _) in
				for message in storedMessages {
					if let number = message.fields["number"] {
						messageNumbers.append(number)
					}
				}
				return FutureImpl(Data()).toFuture()
			}
			sleep(1)
		}

		var expectedMessageNumbers: [String] = []
		for i in (messageCount - 100)..<messageCount {
			expectedMessageNumbers.append("\(i)")
		}

		messageNumbers.sort()
		expectedMessageNumbers.sort()
		XCTAssertEqual(expectedMessageNumbers, messageNumbers)
	}

	func testStoreTooManyMetrics() {
		LogStore().clearForTesting()
		let aggregator = LogAggregatorImpl(
			maxBlockCount: 10,
			maxBlockSize: 10,
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)")
		)

		// store more metrics than we want to keep
		let metricCount = 110
		for i in 0..<metricCount {
			let metric = DTOLogMetric(
				"metric",
				[
					"number": "\(i)"
				],
				42,
				MetricUnit.count.getUnit(),
				Date()
			)
			aggregator.addLog(metric: metric)
		}

		var metricNumbers: [String] = []

		// Retrieve all stored metrics
		while metricNumbers.count < 100 {
			aggregator.sendLogsAndMetrics { (_, storedMetrics) in
				for metric in storedMetrics {
					if let number = metric.dimensions["number"] {
						metricNumbers.append(number)
					}
				}
				return FutureImpl(Data()).toFuture()
			}
			sleep(1)
		}

		var expectedMetricNumbers: [String] = []
		for i in (metricCount - 100)..<metricCount {
			expectedMetricNumbers.append("\(i)")
		}

		metricNumbers.sort()
		expectedMetricNumbers.sort()
		XCTAssertEqual(expectedMetricNumbers, metricNumbers)
	}

	func testStoreTooManyLogsAndMetrics() {
		LogStore().clearForTesting()
		let aggregator = LogAggregatorImpl(
			maxBlockCount: 10,
			maxBlockSize: 10,
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)")
		)

		// store more logs and metrics than we want to keep
		let logsAndMetricCount = 110
		for i in 0..<logsAndMetricCount {
			if i % 2 == 0 {
				let message = DTOLogMessage(
					"level",
					"message",
					[
						"number": "\(i)"
					],
					Date()
				)
				aggregator.addLog(message: message)
			} else {
				let metric = DTOLogMetric(
					"metric",
					[
						"number": "\(i)"
					],
					42,
					MetricUnit.count.getUnit(),
					Date()
				)
				aggregator.addLog(metric: metric)
			}
		}

		var messageNumbers: [String] = []
		var metricNumbers: [String] = []

		while messageNumbers.count + metricNumbers.count < 100 {
			aggregator.sendLogsAndMetrics { (storedMessages, storedMetrics) in
				for message in storedMessages {
					if let number = message.fields["number"] {
						messageNumbers.append(number)
					}
				}
				for metric in storedMetrics {
					if let number = metric.dimensions["number"] {
						metricNumbers.append(number)
					}
				}
				return FutureImpl(Data()).toFuture()
			}
			sleep(1)
		}

		var expectedMessageNumbers: [String] = []
		var expectedMetricNumbers: [String] = []
		for i in (logsAndMetricCount - 100)..<logsAndMetricCount {
			if i % 2 == 0 {
				expectedMessageNumbers.append("\(i)")
			} else {
				expectedMetricNumbers.append("\(i)")
			}
		}

		messageNumbers.sort()
		metricNumbers.sort()
		expectedMessageNumbers.sort()
		expectedMetricNumbers.sort()
		XCTAssertEqual(expectedMessageNumbers, messageNumbers)
		XCTAssertEqual(expectedMetricNumbers, metricNumbers)
	}

	func testUseConcurrently() {
		LogStore().clearForTesting()
		let aggregator = LogAggregatorImpl(
			maxBlockCount: 10,
			maxBlockSize: 100,
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)")
		)

		let messageCount = 100
		let metricCount = 100
		let expectation = self.expectation(description: #function)
		let group = DispatchGroup()

		// Add messages concurrently
		group.enter()
		DispatchQueue.global().async {
			for i in 0..<messageCount {
				let message = DTOLogMessage(
					"level",
					"message",
					[
						"number": "\(i)"
					],
					Date()
				)
				aggregator.addLog(message: message)
			}
			group.leave()
		}

		// Add metrics concurrently
		group.enter()
		DispatchQueue.global().async {
			for i in 0..<metricCount {
				let metric = DTOLogMetric(
					"metric",
					[
						"number": "\(i)"
					],
					42,
					MetricUnit.count.getUnit(),
					Date()
				)
				aggregator.addLog(metric: metric)
			}
			group.leave()
		}

		group.notify(queue: .main) {
			var messageNumbersSet: Set<String> = []
			var metricNumbersSet: Set<String> = []

			while messageNumbersSet.count < messageCount || metricNumbersSet.count < metricCount {
				aggregator.sendLogsAndMetrics { (storedMessages, storedMetrics) in
					for message in storedMessages {
						if let number = message.fields["number"] {
							messageNumbersSet.insert(number)
						}
					}
					for metric in storedMetrics {
						if let number = metric.dimensions["number"] {
							metricNumbersSet.insert(number)
						}
					}
					return FutureImpl(Data()).toFuture()
				}
				sleep(1)
			}

			var expectedMessageNumbers: [String] = []
			var expectedMetricNumbers: [String] = []
			for i in 0..<messageCount {
				expectedMessageNumbers.append("\(i)")
			}
			for i in 0..<metricCount {
				expectedMetricNumbers.append("\(i)")
			}

			let messageNumbers = Array(messageNumbersSet).sorted()
			let metricNumbers = Array(metricNumbersSet).sorted()
			expectedMessageNumbers.sort()
			expectedMetricNumbers.sort()
			XCTAssertEqual(expectedMessageNumbers, messageNumbers)
			XCTAssertEqual(expectedMetricNumbers, metricNumbers)

			expectation.fulfill()
		}

		waitForExpectations(timeout: 60)
	}

	func testBreadcrumbs() {
		let breadcrumb = Breadcrumb(
			message: "message_1",
			category: "category_1",
			level: "level_1",
			timestamp: Date()
		)
		let aggregator = LogAggregatorImpl(
			breadcrumbsLimit: 3,
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)")
		)
		aggregator.addLog(breadcrumb: breadcrumb)

		XCTAssertEqual(aggregator.getBreadcrumbs(), [breadcrumb])
	}

	func testBreadcrumbsWithExceededLimit() {
		let breadcrumbs = [
			Breadcrumb(message: "message_1", category: "category_1", level: "level_1", timestamp: Date()),
			Breadcrumb(message: "message_2", category: "category_1", level: "level_1", timestamp: Date()),
			Breadcrumb(message: "message_3", category: "category_1", level: "level_1", timestamp: Date()),
			Breadcrumb(message: "message_4", category: "category_1", level: "level_1", timestamp: Date()),
			Breadcrumb(message: "message_5", category: "category_1", level: "level_1", timestamp: Date()),
		]
		let aggregator = LogAggregatorImpl(
			breadcrumbsLimit: 3,
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)")
		)
		for breadcrumb in breadcrumbs {
			aggregator.addLog(breadcrumb: breadcrumb)
		}

		XCTAssertEqual(aggregator.getBreadcrumbs(), Array(breadcrumbs[2..<breadcrumbs.count]).reversed())
	}

	func testBreadcrumbsConcurrently() {
		let expectation = expectation(description: #function)
		let breadcrumbsLimit = 3
		let aggregator = LogAggregatorImpl(
			breadcrumbsLimit: breadcrumbsLimit,
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)")
		)
		let firstQueue = DispatchQueue(label: "first")
		let secondQueue = DispatchQueue(label: "second")
		let group = DispatchGroup()

		for num in 1...5 {
			group.enter()
			firstQueue.async {
				defer { group.leave() }
				let breadcrumb = Breadcrumb(
					message: "message_first_queue_\(num)",
					category: "category_first_queue_\(num)",
					level: "level_first_queue_\(num)",
					timestamp: Date()
				)
				aggregator.addLog(breadcrumb: breadcrumb)
			}
			group.enter()
			secondQueue.async {
				defer { group.leave() }
				let breadcrumb = Breadcrumb(
					message: "message_second_queue_\(num)",
					category: "category_second_queue_\(num)",
					level: "level_second_queue_\(num)",
					timestamp: Date()
				)
				aggregator.addLog(breadcrumb: breadcrumb)
			}
		}
		group.notify(queue: .main) {
			let breadcrumbs = aggregator.getBreadcrumbs()

			// Verify we have exactly breadcrumbsLimit breadcrumbs
			XCTAssertEqual(breadcrumbs.count, breadcrumbsLimit, "Expected \(breadcrumbsLimit) breadcrumbs but got \(breadcrumbs.count)")

			// Verify all breadcrumbs have the expected format
			for breadcrumb in breadcrumbs {
				let hasValidMessage = breadcrumb.message.starts(with: "message_first_queue_") || breadcrumb.message.starts(with: "message_second_queue_")
				let hasValidCategory = breadcrumb.category.starts(with: "category_first_queue_") || breadcrumb.category.starts(with: "category_second_queue_")
				let hasValidLevel = breadcrumb.level.starts(with: "level_first_queue_") || breadcrumb.level.starts(with: "level_second_queue_")

				XCTAssertTrue(hasValidMessage, "Invalid breadcrumb message: \(breadcrumb.message)")
				XCTAssertTrue(hasValidCategory, "Invalid breadcrumb category: \(breadcrumb.category)")
				XCTAssertTrue(hasValidLevel, "Invalid breadcrumb level: \(breadcrumb.level)")
			}

			expectation.fulfill()
		}

		waitForExpectations(timeout: 10)
	}

	func testEventsInDBAreConsistent() throws {
		LogStore().clearForTesting()
		let sqliteDrive = try DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)")
		let sqliteConsistencyChecker = MockSqliteConsistencyChecker()
		let httpClient = HttpClientImpl(
			retryConfig: RetryConfig.defaultConfig,
			urlSession: URLSession.shared
		)
		let requestFactory = RequestFactoryImpl(
			platformType: .native,
			apiToken: Self.apiToken,
			clientId: Self.clientId
		)
		let logger = LoggerImpl()
		let retryConfig = httpClient.retryConfig
		let attributionApi: AttributionApi = AttributionApiImpl(httpClient: httpClient, requestFactory: requestFactory, retryConfig: retryConfig)
		let privacyApi: PrivacyApi = PrivacyApiImpl(httpClient: httpClient, requestFactory: requestFactory)
		let eventApi: EventApi = EventApiImpl(httpClient: httpClient, requestFactory: requestFactory, retryConfig: retryConfig, logger: logger)
		let logApi: LogApi = LogApiImpl(httpClient: httpClient, requestFactory: requestFactory)
		let userPropertyApi: UserPropertyApi = UserPropertyApiImpl(httpClient: httpClient, requestFactory: requestFactory)
		let remoteConfigApi: RemoteConfigApi = RemoteConfigApiImpl(httpClient: httpClient, requestFactory: requestFactory)
		let sdk = try JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: httpClient,
			attributionApi: attributionApi,
			privacyApi: privacyApi,
			eventApi: eventApi,
			logApi: logApi,
			userPropertyApi: userPropertyApi,
			remoteConfigApi: remoteConfigApi,
			sessionManagerBuilder: { sdk in
				SessionManagerImpl(sdk)
			},
			connectivityManagerBuilder: { sdk in
				try! ConnectivityManagerImpl()
			},
			adTrackingProvider: TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			logAggregator: LogAggregatorImpl(
				sqliteDriver: sqliteDrive,
				sqliteConsistencyChecker: sqliteConsistencyChecker
			),
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: sqliteDrive,
			config: JustTrackSdkConfig(),
			manualStart: false
		)

		let enventsNumber = 500
		for number in 0..<enventsNumber {
			let eventName = "spam_event_\(number)"
			_ = sdk.track(event: AppEvent(eventName))
		}

		let expectation = self.expectation(description: #function)

		DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
			// Verify that consistency checks were performed
			XCTAssertGreaterThan(sqliteConsistencyChecker.messageCheckCount, 0, "No message consistency checks were performed")

			// Verify that the last consistency check result was consistent
			XCTAssertEqual(sqliteConsistencyChecker.lastMessageConsistencyResult, .consistent, "Messages in DB are inconsistent with Store")

			expectation.fulfill()
		}

		waitForExpectations(timeout: 60)
		sdk.shutdown()
	}

	private func withFailureCount(_ test: (Int) -> Void) {
		[0, 1, 5].forEach {
			test($0)
		}
	}

	private func consume(aggregator: LogAggregator, failureCount: Int) -> ([DTOLogMessage], [DTOLogMetric]) {
		var messages: [DTOLogMessage] = []
		var metrics: [DTOLogMetric] = []

		for i in 0...failureCount {
			aggregator.sendLogsAndMetrics({ (newMessages, newMetrics) in
				if i == failureCount {
					messages.append(contentsOf: newMessages)
					metrics.append(contentsOf: newMetrics)

					return FutureImpl(Data()).toFuture()
				}

				return FutureImpl().reject(TestLogAggregatorError())
			})
			sleep(1)
		}

		return (messages, metrics)
	}
}

private class TestLogAggregatorError: Error {}
