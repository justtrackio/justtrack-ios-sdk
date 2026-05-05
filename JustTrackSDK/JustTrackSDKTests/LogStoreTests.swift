import XCTest

@testable import JustTrackSDK

class LogStoreTests: XCTestCase {
	func testStoreAndRetrieveLogsAndMetrics() {
		let message = DTOLogMessage("level", "this is a test", [:], Date())
		let metric = DTOLogMetric("metric", [:], 42.0, MetricUnit.count.getUnit(), Date())

		let store = LogStore()
		store.clearForTesting()
		_ = store.store(message: message)
		_ = store.store(metric: metric)

		var storedMessages: [StoredLogMessage] = []
		var storedMetrics: [StoredLogMetric] = []
		store.fetchNextBlock(
			onReadLogMessage: { readMessage in
				XCTAssertEqual(readMessage.message, message)
				storedMessages.append(readMessage)
			},
			onReadLogMetric: { readMetric in
				XCTAssertEqual(readMetric.metric, metric)
				storedMetrics.append(readMetric)
			}
		)
		XCTAssertEqual(1, storedMessages.count)
		XCTAssertEqual(1, storedMetrics.count)

		store.remove(messages: storedMessages, metrics: storedMetrics)

		store.fetchNextBlock(
			onReadLogMessage: { readMessage in
				XCTFail("unexpected message read")
			},
			onReadLogMetric: { readMetric in
				XCTFail("unexpected metric read")
			}
		)
	}

	func testStoreTooManyLogs() {
		let store = LogStore(maxBlockSize: 10, maxBlockCount: 10)
		store.clearForTesting()

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
			_ = store.store(message: message)
		}

		var messageNumbers: [String] = []
		repeat {
			var messages: [StoredLogMessage] = []
			store.fetchNextBlock(
				onReadLogMessage: { readMessage in
					messageNumbers.append(readMessage.message.fields["number"] ?? "not found")
					messages.append(readMessage)
				},
				onReadLogMetric: { readMetric in
					XCTFail("unexpected metric read")
				}
			)
			store.remove(messages: messages, metrics: [])
			LoggerImpl().info("testStoreTooManyLogs: Currently at \(messageNumbers.count)", LoggerFieldsImpl())
		} while messageNumbers.count < 100

		var expectedMessageNumbers: [String] = []
		for i in (messageCount - 100)..<messageCount {
			expectedMessageNumbers.append("\(i)")
		}

		messageNumbers.sort()
		expectedMessageNumbers.sort()
		XCTAssertEqual(expectedMessageNumbers, messageNumbers)
	}

	func testStoreTooManyMetrics() {
		let store = LogStore(maxBlockSize: 10, maxBlockCount: 10)
		store.clearForTesting()

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
			_ = store.store(metric: metric)
		}

		var metricNumbers: [String] = []
		repeat {
			var metrics: [StoredLogMetric] = []
			store.fetchNextBlock(
				onReadLogMessage: { readMessage in
					XCTFail("unexpected message read")
				},
				onReadLogMetric: { readMetric in
					metricNumbers.append(readMetric.metric.dimensions["number"] ?? "not found")
					metrics.append(readMetric)
				}
			)
			store.remove(messages: [], metrics: metrics)
			LoggerImpl().info("storeTooManyMetrics: Currently at \(metricNumbers.count)", LoggerFieldsImpl())
		} while metricNumbers.count < 100

		var expectedMetricNumbers: [String] = []
		for i in (metricCount - 100)..<metricCount {
			expectedMetricNumbers.append("\(i)")
		}

		metricNumbers.sort()
		expectedMetricNumbers.sort()
		XCTAssertEqual(expectedMetricNumbers, metricNumbers)
	}

	func testStoreTooManyLogsAndMetrics() {
		let store = LogStore(maxBlockSize: 10, maxBlockCount: 10)
		store.clearForTesting()

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
				_ = store.store(message: message)
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
				_ = store.store(metric: metric)
			}
		}

		var messageNumbers: [String] = []
		var metricNumbers: [String] = []
		repeat {
			var messages: [StoredLogMessage] = []
			var metrics: [StoredLogMetric] = []
			store.fetchNextBlock(
				onReadLogMessage: { readMessage in
					messageNumbers.append(readMessage.message.fields["number"] ?? "not found")
					messages.append(readMessage)
				},
				onReadLogMetric: { readMetric in
					metricNumbers.append(readMetric.metric.dimensions["number"] ?? "not found")
					metrics.append(readMetric)
				}
			)
			store.remove(messages: messages, metrics: metrics)
			LoggerImpl().info("testStoreTooManyLogsAndMetrics: Currently at \(messageNumbers.count) messages and \(metricNumbers.count) metrics", LoggerFieldsImpl())
		} while messageNumbers.count + metricNumbers.count < 100

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
		let queue = DispatchQueue(label: "test-concurrently-queue", attributes: .concurrent)
		var successCount: Int32 = 0
		let group = DispatchGroup()

		let messageCount = 5000
		let metricCount = 3000

		let store = LogStore()
		store.clearForTesting()

		var messageNumbers: [String] = []
		var metricNumbers: [String] = []

		group.enter()
		queue.async {
			repeat {
				var messages: [StoredLogMessage] = []
				var metrics: [StoredLogMetric] = []
				store.fetchNextBlock(
					onReadLogMessage: { readMessage in
						messageNumbers.append(readMessage.message.fields["number"] ?? "not found")
						messages.append(readMessage)
					},
					onReadLogMetric: { readMetric in
						metricNumbers.append(readMetric.metric.dimensions["number"] ?? "not found")
						metrics.append(readMetric)
					}
				)
				store.remove(messages: messages, metrics: metrics)
				LoggerImpl().info("testUseConcurrently: Currently at \(messageNumbers.count) messages and \(metricNumbers.count) metrics", LoggerFieldsImpl())
			} while messageNumbers.count < messageCount || metricNumbers.count < metricCount

			OSAtomicIncrement32(&successCount)
			group.leave()
		}

		group.enter()
		queue.async {
			for i in 0..<messageCount {
				let message = DTOLogMessage(
					"level",
					"message",
					[
						"number": "\(i)"
					],
					Date()
				)
				_ = store.store(message: message)
			}

			OSAtomicIncrement32(&successCount)
			group.leave()
		}

		group.enter()
		queue.async {
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
				_ = store.store(metric: metric)
			}

			OSAtomicIncrement32(&successCount)
			group.leave()
		}

		group.wait()

		var expectedMessageNumbers: [String] = []
		var expectedMetricNumbers: [String] = []
		for i in 0..<messageCount {
			expectedMessageNumbers.append("\(i)")
		}

		for i in 0..<metricCount {
			expectedMetricNumbers.append("\(i)")
		}

		messageNumbers.sort()
		metricNumbers.sort()
		expectedMessageNumbers.sort()
		expectedMetricNumbers.sort()
		XCTAssertEqual(expectedMessageNumbers, messageNumbers)
		XCTAssertEqual(expectedMetricNumbers, metricNumbers)

		XCTAssertEqual(3, successCount)
	}
}
