struct PublishingEvent {
	let event: StorableEvent
	let promise: FutureImpl<Void>

	init(
		event: StorableEvent
	) {
		self.event = event
		self.promise = FutureImpl()
	}

	func eventId() -> StringID {
		return event.eventId
	}

	func baseEvent() -> PublishableUserEvent {
		return event.event
	}

	func happenedAt() -> Date {
		return event.happenedAt
	}

	func sequenceNumber() -> Int {
		return event.sequenceNumber
	}
}
