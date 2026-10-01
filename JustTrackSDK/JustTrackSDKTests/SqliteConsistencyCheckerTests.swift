import XCTest

@testable import JustTrackSDK

final class SqliteConsistencyCheckerTests: XCTestCase {
	// MARK: - Messages: consistent paths

	func testMessagesConsistentWhenBothEmpty() {
		let checker = DefaultSqliteConsistencyChecker()
		var result: SqliteConsistencyResult?
		checker.check(dbMessages: [], storeMessages: []) { result = $0 }
		XCTAssertEqual(result, .consistent)
	}

	func testMessagesConsistentWhenDbHasMoreThanStore() {
		let checker = DefaultSqliteConsistencyChecker()
		let msg1 = StoredLogMessage(id: 1, message: DTOLogMessage("info", "msg1", [:], Date()))
		let msg2 = StoredLogMessage(id: 2, message: DTOLogMessage("info", "msg2", [:], Date()))
		var result: SqliteConsistencyResult?
		checker.check(dbMessages: [msg1, msg2], storeMessages: [msg1]) { result = $0 }
		XCTAssertEqual(result, .consistent)
	}

	func testMessagesConsistentWhenExactMatch() {
		let checker = DefaultSqliteConsistencyChecker()
		let msg = StoredLogMessage(id: 1, message: DTOLogMessage("info", "hello", [:], Date()))
		var result: SqliteConsistencyResult?
		checker.check(dbMessages: [msg], storeMessages: [msg]) { result = $0 }
		XCTAssertEqual(result, .consistent)
	}

	func testMessagesConsistentWithUnsortedInput() {
		let checker = DefaultSqliteConsistencyChecker()
		let msg1 = StoredLogMessage(id: 1, message: DTOLogMessage("info", "first", [:], Date()))
		let msg2 = StoredLogMessage(id: 2, message: DTOLogMessage("info", "second", [:], Date()))
		// db in reverse, store in order — both should be sorted internally
		var result: SqliteConsistencyResult?
		checker.check(dbMessages: [msg2, msg1], storeMessages: [msg1]) { result = $0 }
		XCTAssertEqual(result, .consistent)
	}

	// MARK: - Messages: inconsistent paths

	func testMessagesInconsistentWhenDbHasFewerThanStore() {
		let checker = DefaultSqliteConsistencyChecker()
		let msg1 = StoredLogMessage(id: 1, message: DTOLogMessage("info", "msg1", [:], Date()))
		let msg2 = StoredLogMessage(id: 2, message: DTOLogMessage("info", "msg2", [:], Date()))
		var result: SqliteConsistencyResult?
		checker.check(dbMessages: [msg1], storeMessages: [msg1, msg2]) { result = $0 }
		XCTAssertEqual(result, .inconsistent)
	}

	func testMessagesInconsistentWhenIdsDiffer() {
		let checker = DefaultSqliteConsistencyChecker()
		let dbMsg = StoredLogMessage(id: 1, message: DTOLogMessage("info", "msg", [:], Date()))
		let storeMsg = StoredLogMessage(id: 2, message: DTOLogMessage("info", "msg", [:], Date()))
		var result: SqliteConsistencyResult?
		checker.check(dbMessages: [dbMsg], storeMessages: [storeMsg]) { result = $0 }
		XCTAssertEqual(result, .inconsistent)
	}

	func testMessagesInconsistentWhenMessageTextDiffers() {
		let checker = DefaultSqliteConsistencyChecker()
		let dbMsg = StoredLogMessage(id: 1, message: DTOLogMessage("info", "original", [:], Date()))
		let storeMsg = StoredLogMessage(id: 1, message: DTOLogMessage("info", "tampered", [:], Date()))
		var result: SqliteConsistencyResult?
		checker.check(dbMessages: [dbMsg], storeMessages: [storeMsg]) { result = $0 }
		XCTAssertEqual(result, .inconsistent)
	}

	// MARK: - Messages: once-per-launch guard

	func testMessagesInconsistentOnlyReportedOnce() {
		let checker = DefaultSqliteConsistencyChecker()
		let msg1 = StoredLogMessage(id: 1, message: DTOLogMessage("info", "msg1", [:], Date()))
		let msg2 = StoredLogMessage(id: 2, message: DTOLogMessage("info", "msg2", [:], Date()))

		var callCount = 0
		// First call — db < store → inconsistent
		checker.check(dbMessages: [msg1], storeMessages: [msg1, msg2]) { _ in callCount += 1 }
		XCTAssertEqual(callCount, 1)

		// Second call — guard fires, resultHandler NOT called again
		checker.check(dbMessages: [], storeMessages: [msg1, msg2]) { _ in callCount += 1 }
		XCTAssertEqual(callCount, 1, "resultHandler must not be called after first inconsistency was already found")
	}

	// MARK: - Metrics: consistent paths

	func testMetricsConsistentWhenBothEmpty() {
		let checker = DefaultSqliteConsistencyChecker()
		var result: SqliteConsistencyResult?
		checker.check(dbMetrics: [], storeMetrics: []) { result = $0 }
		XCTAssertEqual(result, .consistent)
	}

	func testMetricsConsistentWhenDbHasMore() {
		let checker = DefaultSqliteConsistencyChecker()
		let m1 = StoredLogMetric(id: 1, metric: DTOLogMetric("latency", [:], 1.0, "ms", Date()))
		let m2 = StoredLogMetric(id: 2, metric: DTOLogMetric("latency", [:], 2.0, "ms", Date()))
		var result: SqliteConsistencyResult?
		checker.check(dbMetrics: [m1, m2], storeMetrics: [m1]) { result = $0 }
		XCTAssertEqual(result, .consistent)
	}

	func testMetricsConsistentWhenExactMatch() {
		let checker = DefaultSqliteConsistencyChecker()
		let m = StoredLogMetric(id: 5, metric: DTOLogMetric("cpu", [:], 42.0, "percent", Date()))
		var result: SqliteConsistencyResult?
		checker.check(dbMetrics: [m], storeMetrics: [m]) { result = $0 }
		XCTAssertEqual(result, .consistent)
	}

	// MARK: - Metrics: inconsistent paths

	func testMetricsInconsistentWhenDbHasFewerThanStore() {
		let checker = DefaultSqliteConsistencyChecker()
		let m1 = StoredLogMetric(id: 1, metric: DTOLogMetric("cpu", [:], 1.0, "pct", Date()))
		let m2 = StoredLogMetric(id: 2, metric: DTOLogMetric("cpu", [:], 2.0, "pct", Date()))
		var result: SqliteConsistencyResult?
		checker.check(dbMetrics: [m1], storeMetrics: [m1, m2]) { result = $0 }
		XCTAssertEqual(result, .inconsistent)
	}

	func testMetricsInconsistentWhenIdsDiffer() {
		let checker = DefaultSqliteConsistencyChecker()
		let dbMetric = StoredLogMetric(id: 1, metric: DTOLogMetric("cpu", [:], 1.0, "pct", Date()))
		let storeMetric = StoredLogMetric(id: 2, metric: DTOLogMetric("cpu", [:], 1.0, "pct", Date()))
		var result: SqliteConsistencyResult?
		checker.check(dbMetrics: [dbMetric], storeMetrics: [storeMetric]) { result = $0 }
		XCTAssertEqual(result, .inconsistent)
	}

	func testMetricsInconsistentWhenMetricNameDiffers() {
		let checker = DefaultSqliteConsistencyChecker()
		let dbMetric = StoredLogMetric(id: 1, metric: DTOLogMetric("original_metric", [:], 1.0, "pct", Date()))
		let storeMetric = StoredLogMetric(id: 1, metric: DTOLogMetric("tampered_metric", [:], 1.0, "pct", Date()))
		var result: SqliteConsistencyResult?
		checker.check(dbMetrics: [dbMetric], storeMetrics: [storeMetric]) { result = $0 }
		XCTAssertEqual(result, .inconsistent)
	}

	// MARK: - Metrics: once-per-launch guard

	func testMetricsInconsistentOnlyReportedOnce() {
		let checker = DefaultSqliteConsistencyChecker()
		let m1 = StoredLogMetric(id: 1, metric: DTOLogMetric("cpu", [:], 1.0, "pct", Date()))
		let m2 = StoredLogMetric(id: 2, metric: DTOLogMetric("cpu", [:], 2.0, "pct", Date()))

		var callCount = 0
		checker.check(dbMetrics: [m1], storeMetrics: [m1, m2]) { _ in callCount += 1 }
		XCTAssertEqual(callCount, 1)

		checker.check(dbMetrics: [], storeMetrics: [m1, m2]) { _ in callCount += 1 }
		XCTAssertEqual(callCount, 1, "resultHandler must not be called after first inconsistency was already found")
	}

	// MARK: - Independence of message and metric flags

	func testMessagesAndMetricsHaveIndependentInconsistencyFlags() {
		let checker = DefaultSqliteConsistencyChecker()
		let msg = StoredLogMessage(id: 1, message: DTOLogMessage("info", "msg", [:], Date()))
		let metric = StoredLogMetric(id: 1, metric: DTOLogMetric("cpu", [:], 1.0, "pct", Date()))

		// Mark messages as inconsistent
		var msgResult: SqliteConsistencyResult?
		checker.check(dbMessages: [], storeMessages: [msg]) { msgResult = $0 }
		XCTAssertEqual(msgResult, .inconsistent)

		// Metrics should still fire normally
		var metricResult: SqliteConsistencyResult?
		checker.check(dbMetrics: [metric], storeMetrics: [metric]) { metricResult = $0 }
		XCTAssertEqual(metricResult, .consistent)
	}
}
