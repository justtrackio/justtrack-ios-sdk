protocol EventStoring {
	func readStoredEvent() -> StorableEvent?

	func getNextId() -> Int
	func storeEvent(event: StorableEvent)
	func removeEvent(event: StorableEvent)
}

extension EventStoring {
	func readEvents() -> [StorableEvent] {
		var eventsToFetch: [StorableEvent] = []
		while let storedEvent = readStoredEvent() {
			eventsToFetch.append(storedEvent)
		}
		return eventsToFetch
	}
}
