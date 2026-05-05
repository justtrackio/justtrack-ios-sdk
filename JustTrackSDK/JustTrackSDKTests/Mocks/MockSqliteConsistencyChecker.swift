import XCTest

@testable import JustTrackSDK

final class MockSqliteConsistencyChecker: SqliteConsistencyChecker {
	var messageCheckCount = 0
	var metricCheckCount = 0
	var lastMessageConsistencyResult: SqliteConsistencyResult = .consistent
	var lastMetricConsistencyResult: SqliteConsistencyResult = .consistent

	func check(
		dbMessages: [JustTrackSDK.StoredLogMessage],
		storeMessages: [JustTrackSDK.StoredLogMessage],
		resultHandler: (JustTrackSDK.SqliteConsistencyResult) -> Void
	) {
		messageCheckCount += 1

		guard dbMessages.count >= storeMessages.count else {
			lastMessageConsistencyResult = .inconsistent
			resultHandler(.inconsistent)
			return
		}

		let sortedStoreMessages = storeMessages.sorted { $0.id < $1.id }
		let sortedDbMessages = dbMessages.sorted { $0.id < $1.id }

		var consistent = true

		for idx in 0..<sortedStoreMessages.count {
			let storedMessage = sortedStoreMessages[idx]
			let dbMessage = sortedDbMessages[idx]
			if storedMessage.id != dbMessage.id || storedMessage.message.message != dbMessage.message.message {
				consistent = false
				break
			}
		}

		let result: SqliteConsistencyResult = consistent ? .consistent : .inconsistent
		lastMessageConsistencyResult = result
		resultHandler(result)
	}

	func check(
		dbMetrics: [JustTrackSDK.StoredLogMetric],
		storeMetrics: [JustTrackSDK.StoredLogMetric],
		resultHandler: (JustTrackSDK.SqliteConsistencyResult) -> Void
	) {
		metricCheckCount += 1

		guard dbMetrics.count >= storeMetrics.count else {
			lastMetricConsistencyResult = .inconsistent
			resultHandler(.inconsistent)
			return
		}

		let sortedStoreMetrics = storeMetrics.sorted { $0.id < $1.id }
		let sortedDbMetrics = dbMetrics.sorted { $0.id < $1.id }

		var consistent = true

		for idx in 0..<sortedStoreMetrics.count {
			let storedMetric = sortedStoreMetrics[idx]
			let dbMetric = sortedDbMetrics[idx]
			if storedMetric.id != dbMetric.id || storedMetric.metric.metric != dbMetric.metric.metric {
				consistent = false
				break
			}
		}

		let result: SqliteConsistencyResult = consistent ? .consistent : .inconsistent
		lastMetricConsistencyResult = result
		resultHandler(result)
	}
}
