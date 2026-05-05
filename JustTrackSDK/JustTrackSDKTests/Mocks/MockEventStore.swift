@testable import JustTrackSDK

final class MockEventStore: EventStoring {
	enum Call: Equatable {
		case readStoredEvent
		case getNextId
		case storeEvent(StorableEvent)
		case removeEvent(StorableEvent)
	}

	var calls = [Call]()

	var onStoreEvent: (StorableEvent) -> Void = { _ in }
	var onRemoveEvent: (StorableEvent) -> Void = { _ in }

	func reset() {
		calls = []
	}

	var readStoredEventResult: StorableEvent?
	var getNextIdResult = -1

	func readStoredEvent() -> StorableEvent? {
		calls.append(.readStoredEvent)
		return readStoredEventResult
	}

	func getNextId() -> Int {
		calls.append(.getNextId)
		getNextIdResult += 1
		return getNextIdResult
	}

	func storeEvent(event: StorableEvent) {
		onStoreEvent(event)
		calls.append(.storeEvent(event))
	}

	func removeEvent(event: StorableEvent) {
		onRemoveEvent(event)
		calls.append(.removeEvent(event))
	}
}
