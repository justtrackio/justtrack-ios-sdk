import Foundation
import UIKit

protocol LogAggregator {
	func addLog(message: DTOLogMessage)
	func addLog(metric: DTOLogMetric)
	func addLog(breadcrumb: Breadcrumb)
	func sendLogsAndMetrics(_ sender: @escaping ([DTOLogMessage], [DTOLogMetric]) -> Future<Data>)
	func getBreadcrumbs() -> [Breadcrumb]
	func moveToBackground()
}

final class LogAggregatorImpl: LogAggregator {
	private var currentlyStored: [Int: Bool]
	private var breadcrumbs: RingBuffer<Breadcrumb>

	private let logStore: LogStore
	private let maxBufferSize: Int
	private let messages: Deque<StoredLogMessage>
	private let metrics: Deque<StoredLogMetric>
	private let queue: DispatchQueue
	private let sqliteDriver: SqliteDriver
	private let sqliteConsistencyChecker: SqliteConsistencyChecker

	init(
		breadcrumbsLimit: Int = 20,
		maxBlockCount: Int = 150,
		maxBlockSize: Int = 150,
		queue: DispatchQueue = DispatchQueue(label: "io.justtrack.JustTrackSDK.LogAggregatorImpl.queue", qos: .userInteractive),
		sqliteDriver: SqliteDriver,
		sqliteConsistencyChecker: SqliteConsistencyChecker = DefaultSqliteConsistencyChecker(),
		isConsoleLoggingEnabled: Bool = true
	) {
		self.logStore = LogStore(maxBlockSize: maxBlockSize, maxBlockCount: maxBlockCount, isConsoleLoggingEnabled: isConsoleLoggingEnabled)
		self.maxBufferSize = logStore.maxBlockSize
		self.messages = Deque(initialCapacity: maxBufferSize)
		self.metrics = Deque(initialCapacity: maxBufferSize)
		self.queue = queue
		self.sqliteDriver = sqliteDriver
		self.sqliteConsistencyChecker = sqliteConsistencyChecker
		self.currentlyStored = [:]
		self.breadcrumbs = RingBuffer(capacity: breadcrumbsLimit)

		queue.async { [self] in
			var readMessages = [StoredLogMessage]()
			var readMetrics = [StoredLogMetric]()

			logStore.fetchNextBlock(
				onReadLogMessage: { message in
					store(message: message)
					readMessages.append(message)
				},
				onReadLogMetric: { metric in
					store(metric: metric)
					readMetrics.append(metric)
				}
			)

			var readDatabaseMessages = [StoredLogMessage]()
			var readDatabaseMetrics = [StoredLogMetric]()

			do {
				try sqliteDriver.fetchNextBlockOfMessagesAndMetrics(
					blockSize: maxBufferSize,
					onReadLogMessage: { message in
						readDatabaseMessages.append(message)
					},
					onReadLogMetric: { metric in
						readDatabaseMetrics.append(metric)
					}
				)
			} catch {
				logDatabaseError("Failed to fetch next block of messages and metrics", error: error, usingDatabase: true)
			}
		}
	}

	func addLog(
		message: DTOLogMessage
	) {
		queue.async {
			self.addLog(message: message, usingDatabase: true)
		}
	}

	func addLog(
		metric: DTOLogMetric
	) {
		queue.async { [self] in
			let storedMetric = logStore.store(metric: metric)
			do {
				try sqliteDriver.storeMetric(storedMetric)
			} catch {
				logDatabaseError("Failed to store metric in database", error: error, usingDatabase: false)
			}

			if currentlyStored[storedMetric.getId()] == nil {
				store(metric: storedMetric)
			}

			while metrics.count > maxBufferSize {
				if let deleted = metrics.removeFirst() {
					currentlyStored.removeValue(forKey: deleted.getId())
				}
			}
		}
	}

	func addLog(
		breadcrumb: Breadcrumb
	) {
		queue.async { [self] in
			breadcrumbs.write(breadcrumb)
		}
	}

	func sendLogsAndMetrics(
		_ sender: @escaping ([DTOLogMessage], [DTOLogMetric]) -> Future<Data>
	) {
		queue.async {
			self.sendLogsAndMetrics(sender, 0)
		}
	}

	func getBreadcrumbs() -> [Breadcrumb] {
		queue.sync {
			breadcrumbs.elements(reversed: true)
		}
	}

	func moveToBackground() {
		let container = UIBackgroundTaskIdentifierContainer()
		container.identifier = UIApplication.shared.beginBackgroundTask {
			UIApplication.shared.endBackgroundTask(container.identifier)
		}

		queue.async {
			UIApplication.shared.endBackgroundTask(container.identifier)
		}
	}

	private func addLog(
		message: DTOLogMessage,
		usingDatabase: Bool
	) {
		let storedMessage = logStore.store(message: message)
		if usingDatabase {
			do {
				try sqliteDriver.storeMessage(storedMessage)
			} catch {
				logDatabaseError("Failed to store message in database", error: error, usingDatabase: false)
			}
		}

		if currentlyStored[storedMessage.getId()] == nil {
			store(message: storedMessage)
		}

		while messages.count > maxBufferSize {
			if let deleted = messages.removeFirst() {
				currentlyStored.removeValue(forKey: deleted.getId())
			}
		}
	}

	private func sendLogsAndMetrics(_ sender: @escaping ([DTOLogMessage], [DTOLogMetric]) -> Future<Data>, _ nesting: Int) {
		if messages.isEmpty && metrics.isEmpty {
			return
		}

		var storedMessages: [StoredLogMessage] = []
		storedMessages.reserveCapacity(messages.count)
		var dtoMessages: [DTOLogMessage] = []
		dtoMessages.reserveCapacity(messages.count)
		while let message = messages.removeFirst() {
			storedMessages.append(message)
			dtoMessages.append(message.message)
		}

		var storedMetrics: [StoredLogMetric] = []
		storedMetrics.reserveCapacity(metrics.count)
		var dtoMetrics: [DTOLogMetric] = []
		dtoMetrics.reserveCapacity(metrics.count)
		while let metric = metrics.removeFirst() {
			storedMetrics.append(metric)
			dtoMetrics.append(metric.metric)
		}

		currentlyStored.removeAll()

		sender(dtoMessages, dtoMetrics).observe(on: queue) { [self] result in
			switch result {
			case .success:
				logStore.remove(messages: storedMessages, metrics: storedMetrics)
				do {
					try sqliteDriver.removeMessagesAndMetrics(messageIds: storedMessages.map(\.id), metricIds: storedMetrics.map(\.id))
				} catch {
					logDatabaseError("Failed to remove messages and metrics from database", error: error, usingDatabase: true)
				}

				var readMessages = [StoredLogMessage]()
				var readMetrics = [StoredLogMetric]()

				logStore.fetchNextBlock(
					onReadLogMessage: { message in
						if currentlyStored[message.getId()] == nil {
							store(message: message)
							readMessages.append(message)
						}
					},
					onReadLogMetric: { metric in
						if currentlyStored[metric.getId()] == nil {
							store(metric: metric)
							readMetrics.append(metric)
						}
					}
				)

				var readDatabaseMessages = [StoredLogMessage]()
				var readDatabaseMetrics = [StoredLogMetric]()

				do {
					try sqliteDriver.fetchNextBlockOfMessagesAndMetrics(
						blockSize: maxBufferSize,
						onReadLogMessage: { message in
							readDatabaseMessages.append(message)
						},
						onReadLogMetric: { metric in
							readDatabaseMetrics.append(metric)
						}
					)
				} catch {
					logDatabaseError("Failed to fetch next block of messages and metrics", error: error, usingDatabase: true)
				}

				sqliteConsistencyChecker.check(dbMessages: readDatabaseMessages, storeMessages: readMessages) { result in
					switch result {
					case .consistent:
						break
					case .inconsistent:
						logDatabaseError("Messages in DB do not match messages in Store", usingDatabase: true)
					}
				}

				sqliteConsistencyChecker.check(dbMetrics: readDatabaseMetrics, storeMetrics: readMetrics) { result in
					switch result {
					case .consistent:
						break
					case .inconsistent:
						logDatabaseError("Metrics in DB do not match metrics in Store", usingDatabase: true)
					}
				}

				if nesting < 10 {
					sendLogsAndMetrics(sender, nesting + 1)
				}
			case .failure:
				for i in (0..<storedMessages.count).reversed() {
					if messages.count >= maxBufferSize {
						break
					}

					if currentlyStored[storedMessages[i].getId()] == nil {
						storeFront(message: storedMessages[i])
					}
				}

				for i in (0..<storedMetrics.count).reversed() {
					if metrics.count >= maxBufferSize {
						break
					}

					if currentlyStored[storedMetrics[i].getId()] == nil {
						storeFront(metric: storedMetrics[i])
					}
				}
			}
		}
	}

	private func store(message: StoredLogMessage) {
		messages.addLast(message)
		currentlyStored[message.getId()] = true
	}

	private func store(metric: StoredLogMetric) {
		metrics.addLast(metric)
		currentlyStored[metric.getId()] = true
	}

	private func storeFront(message: StoredLogMessage) {
		messages.addFirst(message)
		currentlyStored[message.getId()] = true
	}

	private func storeFront(metric: StoredLogMetric) {
		metrics.addFirst(metric)
		currentlyStored[metric.getId()] = true
	}

	private func logDatabaseError(
		_ message: String,
		error: Error? = nil,
		fields: LoggerFields...,
		usingDatabase: Bool
	) {
		queue.async {
			var encodedFields = [String: String]()
			for field in fields {
				for f in field.getFields() {
					encodedFields[f.key] = f.value
				}
			}

			if let error {
				encodedFields["error"] = error.justTrackGetErrorDescription()
			}

			let message = DTOLogMessage(
				"error",
				"<LogAggregatorImpl> \(message)",
				encodedFields,
				Date()
			)

			self.addLog(message: message, usingDatabase: usingDatabase)
		}
	}
}
