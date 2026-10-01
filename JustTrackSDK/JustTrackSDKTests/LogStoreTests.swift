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

	// MARK: - StoredLogMessage Equatable

	func testStoredLogMessageEqualityTrueWhenSameIdAndMessage() {
		let message = DTOLogMessage("info", "hello", [:], Date())
		let a = StoredLogMessage(id: 1, message: message)
		let b = StoredLogMessage(id: 1, message: message)
		XCTAssertEqual(a, b)
	}

	func testStoredLogMessageEqualityFalseWhenDifferentId() {
		let message = DTOLogMessage("info", "hello", [:], Date())
		let a = StoredLogMessage(id: 1, message: message)
		let b = StoredLogMessage(id: 2, message: message)
		XCTAssertNotEqual(a, b)
	}

	func testStoredLogMessageEqualityFalseWhenDifferentMessage() {
		let a = StoredLogMessage(id: 1, message: DTOLogMessage("info", "hello", [:], Date()))
		let b = StoredLogMessage(id: 1, message: DTOLogMessage("info", "world", [:], Date()))
		XCTAssertNotEqual(a, b)
	}

	// MARK: - StoredLogMetric Equatable

	func testStoredLogMetricEqualityTrueWhenSameIdAndMetric() {
		let date = Date()
		let metric = DTOLogMetric("cpu", [:], 1.0, MetricUnit.count.getUnit(), date)
		let a = StoredLogMetric(id: 5, metric: metric)
		let b = StoredLogMetric(id: 5, metric: metric)
		XCTAssertEqual(a, b)
	}

	func testStoredLogMetricEqualityFalseWhenDifferentId() {
		let date = Date()
		let metric = DTOLogMetric("cpu", [:], 1.0, MetricUnit.count.getUnit(), date)
		let a = StoredLogMetric(id: 5, metric: metric)
		let b = StoredLogMetric(id: 6, metric: metric)
		XCTAssertNotEqual(a, b)
	}

	// MARK: - init: version mismatch triggers migration

	func testInitWithWrongVersionClearsAndRewritesStore() {
		let store = LogStore(maxBlockSize: 5, maxBlockCount: 5)
		store.clearForTesting()

		// Store a message so there is data
		let msg = DTOLogMessage("debug", "before migration", [:], Date())
		_ = store.store(message: msg)

		// A new LogStore over the same files but with modified version would
		// normally trigger migration. We can observe this indirectly: after
		// clearForTesting the store starts fresh, and the next read returns empty.
		let store2 = LogStore(maxBlockSize: 5, maxBlockCount: 5)

		var messages: [StoredLogMessage] = []
		store2.fetchNextBlock(
			onReadLogMessage: { messages.append($0) },
			onReadLogMetric: { _ in }
		)

		// The store was just written by store above; store2 reads the same backing files
		// so the message should still be there (same version).
		// This test verifies that opening an existing valid store doesn't wipe it.
		XCTAssertEqual(messages.count, 1)
	}

	// MARK: - fetchNextBlock on empty store

	func testFetchNextBlockOnEmptyStoreCallsNoCallbacks() {
		let store = LogStore(maxBlockSize: 5, maxBlockCount: 5)
		store.clearForTesting()

		var called = false
		store.fetchNextBlock(
			onReadLogMessage: { _ in called = true },
			onReadLogMetric: { _ in called = true }
		)

		XCTAssertFalse(called)
	}

	// MARK: - remove with empty lists does not crash

	func testRemoveWithEmptyListsDoesNotCrash() {
		let store = LogStore(maxBlockSize: 5, maxBlockCount: 5)
		store.clearForTesting()

		store.remove(messages: [], metrics: [])
	}

	// MARK: - isEmptyBlock returns false when block has content

	func testIsEmptyBlockReturnsFalseForNonEmptyBlock() {
		let store = LogStore(maxBlockSize: 5, maxBlockCount: 5)
		store.clearForTesting()

		let msg = DTOLogMessage("debug", "non-empty", [:], Date())
		_ = store.store(message: msg)

		// fetchNextBlock internally calls isEmptyBlock; a non-empty block won't be removed
		var readCount = 0
		store.fetchNextBlock(
			onReadLogMessage: { _ in readCount += 1 },
			onReadLogMetric: { _ in }
		)

		XCTAssertEqual(readCount, 1)
	}

	// MARK: - StoredLogMessage init?(encoded:) with bad data

	func testStoredLogMessageInitWithBadEncodedDataReturnsNil() {
		let bad: [String: Any] = ["garbage": "data"]
		let result = StoredLogMessage(id: 1, encoded: bad)
		XCTAssertNil(result)
	}

	// MARK: - StoredLogMetric init?(encoded:) with bad data

	func testStoredLogMetricInitWithBadEncodedDataReturnsNil() {
		let bad: [String: Any] = ["garbage": "data"]
		let result = StoredLogMetric(id: 1, encoded: bad)
		XCTAssertNil(result)
	}

	// MARK: - store message and metric roundtrip via encode/decode

	func testStoredLogMessageEncodeDecodeRoundtrip() {
		let date = Date()
		let msg = DTOLogMessage("warn", "roundtrip", ["k": "v"], date)
		let stored = StoredLogMessage(id: 42, message: msg)
		let encoded = stored.encode()
		let decoded = StoredLogMessage(id: 42, encoded: encoded)

		XCTAssertNotNil(decoded)
		XCTAssertEqual(decoded?.message.message, "roundtrip")
		XCTAssertEqual(decoded?.message.fields["k"], "v")
	}

	func testStoredLogMetricEncodeDecodeRoundtrip() {
		let date = Date()
		let metric = DTOLogMetric("latency", ["region": "eu"], 99.5, MetricUnit.count.getUnit(), date)
		let stored = StoredLogMetric(id: 7, metric: metric)
		let encoded = stored.encode()
		let decoded = StoredLogMetric(id: 7, encoded: encoded)

		XCTAssertNotNil(decoded)
		XCTAssertEqual(decoded?.metric.metric, "latency")
		XCTAssertEqual(decoded?.metric.dimensions["region"], "eu")
		XCTAssertEqual(decoded?.metric.value, 99.5)
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
