import Foundation

enum SqliteConsistencyResult {
	case consistent
	case inconsistent
}

protocol SqliteConsistencyChecker {
	func check(dbMessages: [StoredLogMessage], storeMessages: [StoredLogMessage], resultHandler: (SqliteConsistencyResult) -> Void)
	func check(dbMetrics: [StoredLogMetric], storeMetrics: [StoredLogMetric], resultHandler: (SqliteConsistencyResult) -> Void)
}

final class DefaultSqliteConsistencyChecker: SqliteConsistencyChecker {
	// We return the inconsistent result once each time the app is launched to avoid spamming logs.
	private var foundInconsistencyInMessages = false
	private var foundInconsistencyInMetrics = false

	func check(
		dbMessages: [StoredLogMessage],
		storeMessages: [StoredLogMessage],
		resultHandler: (SqliteConsistencyResult) -> Void
	) {
		guard !foundInconsistencyInMessages else {
			return
		}

		// The store only returns the messages/metrics in the latest block. The amount of metrics in the latest block might be less than the current offset.
		// The database, in turn, always returns the amount of messages/metrics that equals the current offset (if there are enough messages/metrics in the database; otherwise, it returns all the metrics/messages it has, which is less than the offset amount).
		guard dbMessages.count >= storeMessages.count else {
			foundInconsistencyInMessages = true
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

		if consistent {
			resultHandler(.consistent)
		} else {
			foundInconsistencyInMessages = true
			resultHandler(.inconsistent)
		}
	}

	func check(
		dbMetrics: [StoredLogMetric],
		storeMetrics: [StoredLogMetric],
		resultHandler: (SqliteConsistencyResult) -> Void
	) {
		guard !foundInconsistencyInMetrics else {
			return
		}

		guard dbMetrics.count >= storeMetrics.count else {
			foundInconsistencyInMetrics = true
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

		if consistent {
			resultHandler(.consistent)
		} else {
			foundInconsistencyInMetrics = true
			resultHandler(.inconsistent)
		}
	}
}
