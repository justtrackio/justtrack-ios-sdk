protocol SqliteDriver {
	func fetchEvents() throws -> [StorableEvent]

	func fetchNextBlockOfMessagesAndMetrics(blockSize: Int, onReadLogMessage: @escaping (StoredLogMessage) -> Void, onReadLogMetric: @escaping (StoredLogMetric) -> Void) throws

	func removeEvents(eventIds: [Int]) throws

	func removeMessagesAndMetrics(messageIds: [Int], metricIds: [Int]) throws

	func storeEvent(_ event: StorableEvent) throws

	func storeMessage(_ message: StoredLogMessage) throws

	func storeMetric(_ metric: StoredLogMetric) throws
}
