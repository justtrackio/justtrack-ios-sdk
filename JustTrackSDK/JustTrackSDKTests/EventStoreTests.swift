import Foundation
import XCTest

@testable import JustTrackSDK

final class EventStoreTests: XCTestCase {
	private let dimensions1: [String: String] = [
		Dimension.jtAdNetwork.stringValue: "adNetwork"
	]
	private let dimensions2: [String: String] = [:]
	private let dimensions3: [String: String] = [
		"custom_1": "custom1",
		"custom_3": "custom3",
		Dimension.jtAdNetwork.stringValue: "adNetwork",
	]

	func testCanParseStoredEvent() {
		let event1 = PublishableUserEvent(name: "name1", sessionId: "session id", dimensions: dimensions1, value: 1, unit: nil, currency: nil, happenedAt: nil)
		let event2 = PublishableUserEvent(name: "name2", sessionId: "session id", dimensions: dimensions2, value: 3, unit: .count, currency: nil, happenedAt: nil)
		let event3 = PublishableUserEvent(name: "name3", sessionId: "session id", dimensions: dimensions3, value: 4, unit: .seconds, currency: nil, happenedAt: nil)
		let storedEvent1 = StorableEvent(id: 1, event: event1, sequenceNumber: 1)
		let storedEvent2 = StorableEvent(id: 2, event: event2, sequenceNumber: 2)
		let storedEvent3 = StorableEvent(id: 3, event: event3, sequenceNumber: 3)
		let parsedEvent1 = StorableEvent(id: 1, encoded: storedEvent1.encode())
		let parsedEvent2 = StorableEvent(id: 2, encoded: storedEvent2.encode())
		let parsedEvent3 = StorableEvent(id: 3, encoded: storedEvent3.encode())
		XCTAssertEqual(storedEvent1, parsedEvent1)
		XCTAssertEqual(storedEvent2, parsedEvent2)
		XCTAssertEqual(storedEvent3, parsedEvent3)
	}

	func testEventStore() {
		JustTrack.resetForTesting(clearStorage: true)
		let event1 = PublishableUserEvent(name: "name1", sessionId: "session id", dimensions: dimensions1, value: 1, unit: nil, currency: nil, happenedAt: nil)
		let event2 = PublishableUserEvent(name: "name2", sessionId: "session id", dimensions: dimensions2, value: 3, unit: .count, currency: nil, happenedAt: nil)
		let event3 = PublishableUserEvent(name: "name3", sessionId: "session id", dimensions: dimensions3, value: 4, unit: .seconds, currency: nil, happenedAt: nil)
		var store = EventStore()
		let id1 = store.getNextId()
		let id2 = store.getNextId()
		let id3 = store.getNextId()
		XCTAssertEqual(id1, 1)
		XCTAssertEqual(id2, 2)
		XCTAssertEqual(id3, 3)
		store.storeEvent(event: StorableEvent(id: id1, event: event1, sequenceNumber: 1))
		store.storeEvent(event: StorableEvent(id: id2, event: event2, sequenceNumber: 2))
		store.storeEvent(event: StorableEvent(id: id3, event: event3, sequenceNumber: 3))
		// we have no stored events yet as these are always from the events stored during init
		XCTAssertNil(store.readStoredEvent())
		store = EventStore()
		let id4 = store.getNextId()
		XCTAssertEqual(id4, 4)
		let stored1 = store.readStoredEvent()
		let stored2 = store.readStoredEvent()
		let stored3 = store.readStoredEvent()
		XCTAssertNil(store.readStoredEvent())
		XCTAssertEqual(stored1?.event, event1)
		XCTAssertEqual(stored2?.event, event2)
		XCTAssertEqual(stored3?.event, event3)
		XCTAssertEqual(stored1?.id, id1)
		XCTAssertEqual(stored2?.id, id2)
		XCTAssertEqual(stored3?.id, id3)
		store.removeEvent(event: stored2!)
		store = EventStore()
		let id5 = store.getNextId()
		XCTAssertEqual(id5, 5)
		let stored4 = store.readStoredEvent()
		let stored5 = store.readStoredEvent()
		XCTAssertNil(store.readStoredEvent())
		XCTAssertEqual(stored4?.event, event1)
		XCTAssertEqual(stored5?.event, event3)
		XCTAssertEqual(stored4?.id, id1)
		XCTAssertEqual(stored5?.id, id3)
	}

	func testStoreSdkVersion() {
		JustTrack.resetForTesting(clearStorage: true)
		let event1 = PublishableUserEvent(name: "name1", sessionId: "session id", dimensions: dimensions1, value: 1, unit: nil, currency: nil, happenedAt: nil)
		let event2 = PublishableUserEvent(name: "name2", sessionId: "session id", dimensions: dimensions2, value: 3, unit: .count, currency: nil, happenedAt: nil)
		let event3 = PublishableUserEvent(name: "name3", sessionId: "session id", dimensions: dimensions3, value: 4, unit: .seconds, currency: nil, happenedAt: nil)
		var store = EventStore()
		let id1 = store.getNextId()
		let id2 = store.getNextId()
		let id3 = store.getNextId()
		let v1 = VersionImpl(major: 5, minor: 0, patch: 0, name: "5.0.0")
		let v2 = VersionImpl(major: 5, minor: 0, patch: 1, name: "5.0.1")
		let v3 = VersionImpl(major: 6, minor: 0, patch: 0, name: "6.0.0")
		store.storeEvent(event: StorableEvent(id: id1, event: event1, sequenceNumber: 1, sdkVersion: v1))
		store.storeEvent(event: StorableEvent(id: id2, event: event2, sequenceNumber: 2, sdkVersion: v2))
		store.storeEvent(event: StorableEvent(id: id3, event: event3, sequenceNumber: 3, sdkVersion: v3))

		// we have no stored events yet as these are always from the events stored during init
		XCTAssertNil(store.readStoredEvent())
		store = EventStore()

		let stored1 = store.readStoredEvent()
		let stored2 = store.readStoredEvent()
		let stored3 = store.readStoredEvent()

		XCTAssertEqual(stored1?.event, event1)
		XCTAssertEqual(stored2?.event, event2)
		XCTAssertEqual(stored3?.event, event3)

		XCTAssertEqual(stored1?.id, id1)
		XCTAssertEqual(stored2?.id, id2)
		XCTAssertEqual(stored3?.id, id3)

		XCTAssertEqual(stored1?.sdkVersion.major, v1.major)
		XCTAssertEqual(stored1?.sdkVersion.minor, v1.minor)
		XCTAssertEqual(stored1?.sdkVersion.patch, v1.patch)
		XCTAssertEqual(stored1?.sdkVersion.name, v1.name)

		XCTAssertEqual(stored2?.sdkVersion.major, v2.major)
		XCTAssertEqual(stored2?.sdkVersion.minor, v2.minor)
		XCTAssertEqual(stored2?.sdkVersion.patch, v2.patch)
		XCTAssertEqual(stored2?.sdkVersion.name, v2.name)

		XCTAssertEqual(stored3?.sdkVersion.major, v3.major)
		XCTAssertEqual(stored3?.sdkVersion.minor, v3.minor)
		XCTAssertEqual(stored3?.sdkVersion.patch, v3.patch)
		XCTAssertEqual(stored3?.sdkVersion.name, v3.name)
	}

	func testDoNotReturnEventsWithoutSdkVersion() {
		JustTrack.resetForTesting(clearStorage: true)

		let event1 = PublishableUserEvent(name: "event_1", sessionId: "session_1", dimensions: dimensions1, value: 1, unit: nil, currency: nil, happenedAt: nil)
		var store = EventStore()
		let id1 = store.getNextId()
		let id2 = store.getNextId()

		store.storeEvent(event: StorableEvent(id: id1, event: event1, sequenceNumber: 1))

		var storedData = UserDefaults.standard.dictionary(forKey: EventStore.key) ?? [:]
		let eventWithoutSdkVersion: [String: Any] = [
			"eventId": UUID().uuidString,
			"event": event1.encode(),
			"happenedAt": Date().timeIntervalSince1970,
			"sequenceNumber": 2,
		]
		storedData["event-\(id2)"] = eventWithoutSdkVersion
		UserDefaults.standard.setValue(storedData, forKey: EventStore.key)

		store = EventStore()

		let stored1 = store.readStoredEvent()
		XCTAssertNotNil(stored1)
		XCTAssertEqual(stored1?.id, id1)
		XCTAssertEqual(stored1?.event, event1)

		let stored2 = store.readStoredEvent()
		XCTAssertNil(stored2)
	}
}
