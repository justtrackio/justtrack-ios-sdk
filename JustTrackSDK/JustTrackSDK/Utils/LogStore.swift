import Foundation

// See the Android version of this store for an explanation how we store the logs.
final class LogStore {
	static let key = "io.justtrack.attribution.logStore"
	private static let version: Int = 2

	private static let maxRetentionTime: TimeInterval = 3 * 24 * 3600

	private static let keyDataVersion = "version"
	private static let keyBlockId = "blockId"
	private static let keyNextMessageOrMetricId = "nextMessageOrMetricId"
	fileprivate static let keyBlockPrefix = "block-"
	fileprivate static let keyMessagePrefix = "message-"
	fileprivate static let keyMetricPrefix = "metric-"

	internal let maxBlockSize: Int
	internal let maxBlockCount: Int
	private let fileStore: PListStore
	private var blockQueue: Deque<LogStoreBlock>

	convenience init() {
		self.init(maxBlockSize: 100, maxBlockCount: 100)
	}

	init(maxBlockSize: Int, maxBlockCount: Int, isConsoleLoggingEnabled: Bool = true) {
		self.maxBlockSize = maxBlockSize
		self.maxBlockCount = maxBlockCount
		self.fileStore = PListStore(isConsoleLoggingEnabled: isConsoleLoggingEnabled)
		self.blockQueue = Deque(initialCapacity: maxBlockSize)

		guard var storedData = fileStore.readFile(filename: LogStore.key) else { return }
		let version = storedData[LogStore.keyDataVersion] as? Int ?? 0

		if version != LogStore.version {
			storedData = [
				LogStore.keyDataVersion: LogStore.version
			]
			fileStore.writeFile(filename: LogStore.key, data: storedData)

			return
		}

		let cutoff = Date(timeIntervalSinceNow: -LogStore.maxRetentionTime)
		var blocksToDelete: [LogStoreBlock] = []
		var blocksToAdd: [LogStoreBlock] = []

		forAllBlocks { block in
			if block.isExpired(cutoff) {
				blocksToDelete.append(block)
			} else {
				blocksToAdd.append(block)
			}
		}

		blocksToAdd.sort()
		blocksToAdd.forEach(blockQueue.addLast(_:))

		if !blocksToDelete.isEmpty {
			for block in blocksToDelete {
				delete(block: block, storedData: &storedData)
			}

			fileStore.writeFile(filename: LogStore.key, data: storedData)
		}
	}

	func clearForTesting() {
		var dict: [String: Any] = [
			LogStore.keyDataVersion: LogStore.version
		]

		for i in 0..<maxBlockCount {
			delete(block: LogStoreBlockHeader(i), storedData: &dict)
		}

		fileStore.writeFile(filename: LogStore.key, data: dict)

		while !blockQueue.isEmpty {
			_ = blockQueue.removeFirst()
		}
	}

	func store(message: DTOLogMessage) -> StoredLogMessage {
		return storeMessageOrMetric(
			message,
			{ (id, message) in
				StoredLogMessage(id: id, message: message)
			}
		)
	}

	func store(metric: DTOLogMetric) -> StoredLogMetric {
		return storeMessageOrMetric(
			metric,
			{ (id, metric) in
				StoredLogMetric(id: id, metric: metric)
			}
		)
	}

	func fetchNextBlock(onReadLogMessage: (StoredLogMessage) -> Void, onReadLogMetric: (StoredLogMetric) -> Void) {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		guard let firstBlock = blockQueue.peekFirst() else { return }
		let isEmpty = readBlock(firstBlock, onReadLogMessage, onReadLogMetric)

		if isEmpty {
			guard var storedData = fileStore.readFile(filename: LogStore.key) else { return }
			let nextId = storedData[LogStore.keyNextMessageOrMetricId] as? Int ?? 0
			let currentBlockId = getBlockId(nextId, maxBlockSize: maxBlockSize)

			if currentBlockId != firstBlock.id {
				// remove first empty block
				delete(block: firstBlock, storedData: &storedData)
				_ = blockQueue.removeFirst()
				fileStore.writeFile(filename: LogStore.key, data: storedData)
				// and try again
				fetchNextBlock(onReadLogMessage: onReadLogMessage, onReadLogMetric: onReadLogMetric)
			}
		}
	}

	func remove(messages: [StoredLogMessage], metrics: [StoredLogMetric]) {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		var storedData =
			fileStore.readFile(filename: LogStore.key) ?? [
				LogStore.keyDataVersion: LogStore.version
			]
		let nextId = storedData[LogStore.keyNextMessageOrMetricId] as? Int ?? 0
		let currentBlockId = getBlockId(nextId, maxBlockSize: maxBlockSize)
		var blocks: [LogStoreBlockHeader: [String: Any]] = [:]

		for message in messages {
			removeMessageOrMetricFromBlock(blocks: &blocks, datum: message)
		}

		for metric in metrics {
			removeMessageOrMetricFromBlock(blocks: &blocks, datum: metric)
		}

		for blockEntry in blocks {
			let block = blockEntry.key
			fileStore.writeFile(filename: block.key(maxBlockCount: maxBlockCount), data: blockEntry.value)

			if currentBlockId != block.id && isEmptyBlock(block) {
				delete(block: block, storedData: &storedData)
				if let firstBlock = blockQueue.peekFirst() {
					if block == firstBlock {
						_ = blockQueue.removeFirst()
					}
				}
			}
		}

		fileStore.writeFile(filename: LogStore.key, data: storedData)
	}

	private func forAllBlocks(onBlock: (LogStoreBlock) -> Void) {
		guard let storedData = fileStore.readFile(filename: LogStore.key) else { return }

		for entry in storedData where entry.key.hasPrefix(LogStore.keyBlockPrefix) {
			guard let id = Int(entry.key[LogStore.keyBlockPrefix.endIndex...]) else { continue }
			guard let storedAt = parseDate(entry.value as? String ?? "") else { continue }
			onBlock(LogStoreBlock(id: id, timestamp: storedAt))
		}
	}

	private func delete(block: LogStoreBlockHeader, storedData: inout [String: Any]) {
		storedData.removeValue(forKey: block.dataKey())
		fileStore.removeFile(filename: block.key(maxBlockCount: maxBlockCount))
	}

	private func readBlock(
		_ block: LogStoreBlockHeader,
		_ onReadLogMessage: (StoredLogMessage) -> Void,
		_ onReadLogMetric: (StoredLogMetric) -> Void
	) -> Bool {
		guard let storedData = fileStore.readFile(filename: block.key(maxBlockCount: maxBlockCount)) else { return true }
		var messagesToDelete: [StoredLogMessage] = []
		var metricsToDelete: [StoredLogMetric] = []
		let cutoff = Date(timeIntervalSinceNow: -LogStore.maxRetentionTime)
		var isEmpty = true

		for entry in storedData {
			if entry.key.hasPrefix(LogStore.keyMessagePrefix) {
				guard let id = Int(entry.key[LogStore.keyMessagePrefix.endIndex...]) else { continue }
				guard let eventObject = entry.value as? [String: Any] else { continue }
				guard let message = StoredLogMessage(id: id, encoded: eventObject) else { continue }
				if message.isExpired(cutoff) {
					messagesToDelete.append(message)
				} else {
					onReadLogMessage(message)
					isEmpty = false
				}
			} else if entry.key.hasPrefix(LogStore.keyMetricPrefix) {
				guard let id = Int(entry.key[LogStore.keyMetricPrefix.endIndex...]) else { continue }
				guard let eventObject = entry.value as? [String: Any] else { continue }
				guard let metric = StoredLogMetric(id: id, encoded: eventObject) else { continue }
				if metric.isExpired(cutoff) {
					metricsToDelete.append(metric)
				} else {
					onReadLogMetric(metric)
					isEmpty = false
				}
			}
		}

		if !messagesToDelete.isEmpty || !metricsToDelete.isEmpty {
			remove(messages: messagesToDelete, metrics: metricsToDelete)
		}

		return isEmpty
	}

	private func isEmptyBlock(_ block: LogStoreBlockHeader) -> Bool {
		return readBlock(block, { _ in }, { _ in })
	}

	private func removeMessageOrMetricFromBlock(blocks: inout [LogStoreBlockHeader: [String: Any]], datum: LogStoreDatum) {
		let block = getBlockHeader(datum, maxBlockSize: maxBlockSize)
		var storedData: [String: Any]
		if let storedBlockData = blocks[block] {
			storedData = storedBlockData
		} else {
			storedData = fileStore.readFile(filename: block.key(maxBlockCount: maxBlockCount)) ?? [:]
		}

		storedData.removeValue(forKey: datum.getKey())
		blocks[block] = storedData
	}

	private func storeMessageOrMetric<T, R: LogStoreDatum>(_ toStore: T, _ makeResult: (Int, T) -> R) -> R {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		var storedData =
			fileStore.readFile(filename: LogStore.key) ?? [
				LogStore.keyDataVersion: LogStore.version
			]
		let nextId = storedData[LogStore.keyNextMessageOrMetricId] as? Int ?? 0
		storedData[LogStore.keyNextMessageOrMetricId] = nextId + 1
		let result = makeResult(nextId, toStore)

		let blockId = getBlockId(nextId, maxBlockSize: maxBlockSize)
		let block = LogStoreBlock(id: blockId, timestamp: Date())
		var shouldClear = false
		var blockForAppend: LogStoreBlock
		if let lastBlock = blockQueue.peekLast() {
			if lastBlock < block {
				blockQueue.addLast(block)
				blockForAppend = block
				shouldClear = true
			} else {
				blockForAppend = lastBlock
			}
		} else {
			blockQueue.addLast(block)
			blockForAppend = block
			shouldClear = true
		}

		if let firstBlock = blockQueue.peekFirst() {
			if firstBlock.storedInSameFileAs(blockForAppend, maxBlockCount: maxBlockCount) {
				storedData.removeValue(forKey: firstBlock.dataKey())
				_ = blockQueue.removeFirst()
			}
		}

		var blockData =
			fileStore.readFile(filename: blockForAppend.key(maxBlockCount: maxBlockCount)) ?? [
				LogStore.keyBlockId: blockId
			]
		if shouldClear {
			storedData[blockForAppend.dataKey()] = formatDateMilliseconds(block.timestamp)
			blockData = [
				LogStore.keyBlockId: blockId
			]
		}

		blockData[result.getKey()] = result.encode()

		fileStore.writeFile(filename: LogStore.key, data: storedData)
		fileStore.writeFile(filename: blockForAppend.key(maxBlockCount: maxBlockCount), data: blockData)

		return result
	}
}

class LogStoreBlockHeader {
	private static let dataNamePrefix: String = "io.justtrack.attribution.logStoreBlock-"
	fileprivate let id: Int

	fileprivate init(_ id: Int) {
		self.id = id
	}

	fileprivate func key(maxBlockCount: Int) -> String {
		return Self.dataNamePrefix + String(id % maxBlockCount)
	}

	fileprivate func dataKey() -> String {
		return LogStore.keyBlockPrefix + String(id)
	}

	fileprivate func storedInSameFileAs(_ other: LogStoreBlockHeader, maxBlockCount: Int) -> Bool {
		return id != other.id && (id % maxBlockCount) == (other.id % maxBlockCount)
	}
}

extension LogStoreBlockHeader: Equatable {
	static func == (lhs: LogStoreBlockHeader, rhs: LogStoreBlockHeader) -> Bool {
		return lhs.id == rhs.id
	}
}

extension LogStoreBlockHeader: Comparable {
	static func < (lhs: LogStoreBlockHeader, rhs: LogStoreBlockHeader) -> Bool {
		return lhs.id < rhs.id
	}
}

extension LogStoreBlockHeader: Hashable {
	func hash(into hasher: inout Hasher) {
		id.hash(into: &hasher)
	}
}

class LogStoreBlock: LogStoreBlockHeader {
	fileprivate let timestamp: Date

	fileprivate init(id: Int, timestamp: Date) {
		self.timestamp = timestamp
		super.init(id)
	}

	fileprivate func isExpired(_ cutoff: Date) -> Bool {
		return timestamp < cutoff
	}
}

protocol LogStoreDatum {
	func getId() -> Int
	func getKey() -> String
	func encode() -> [String: Any]
}

struct StoredLogMessage: LogStoreDatum {
	let id: Int
	let message: DTOLogMessage

	init(
		id: Int,
		message: DTOLogMessage
	) {
		self.id = id
		self.message = message
	}

	init?(
		id: Int,
		encoded: [String: Any]
	) {
		guard let message = DTOLogMessage(encoded: encoded) else { return nil }
		self.init(id: id, message: message)
	}

	func getId() -> Int {
		return id
	}

	func getKey() -> String {
		return LogStore.keyMessagePrefix + String(id)
	}

	func isExpired(_ cutoff: Date) -> Bool {
		guard let timestamp = parseDate(message.timestamp) else { return true }

		return timestamp < cutoff
	}

	func encode() -> [String: Any] {
		return message.encode()
	}
}

extension StoredLogMessage: Equatable {
	static func == (lhs: StoredLogMessage, rhs: StoredLogMessage) -> Bool {
		lhs.id == rhs.id && lhs.message == rhs.message
	}
}

struct StoredLogMetric: LogStoreDatum {
	let id: Int
	let metric: DTOLogMetric

	init(
		id: Int,
		metric: DTOLogMetric
	) {
		self.id = id
		self.metric = metric
	}

	init?(
		id: Int,
		encoded: [String: Any]
	) {
		guard let metric = DTOLogMetric(encoded: encoded) else { return nil }
		self.init(id: id, metric: metric)
	}

	func getId() -> Int {
		return id
	}

	func getKey() -> String {
		return LogStore.keyMetricPrefix + String(id)
	}

	func isExpired(_ cutoff: Date) -> Bool {
		guard let timestamp = parseDate(metric.timestamp) else { return true }

		return timestamp < cutoff
	}

	func encode() -> [String: Any] {
		return metric.encode()
	}
}

extension StoredLogMetric: Equatable {
	static func == (lhs: StoredLogMetric, rhs: StoredLogMetric) -> Bool {
		lhs.id == rhs.id && lhs.metric == rhs.metric
	}
}

private func getBlockHeader(_ datum: LogStoreDatum, maxBlockSize: Int) -> LogStoreBlockHeader {
	return LogStoreBlockHeader(getBlockId(datum.getId(), maxBlockSize: maxBlockSize))
}

private func getBlockId(_ id: Int, maxBlockSize: Int) -> Int {
	return id / maxBlockSize
}
