import Foundation

final class EventStore: EventStoring {
	static let key = "io.justtrack.attribution.storedEvents"
	private static let version: Int = 1

	private static let keyDataVersion = "version"
	private static let keyNextId = "nextId"
	private static let keyPrefix = "event-"

	private let userDefaults: UserDefaults
	private var storedEvents: [StorableEvent]

	init() {
		self.userDefaults = .standard
		self.storedEvents = []

		guard let storedData = userDefaults.dictionary(forKey: Self.key) else { return }
		let version = storedData[Self.keyDataVersion] as? Int ?? -1
		if version != Self.version {
			let dict: [String: Any] = [:]
			userDefaults.setValue(dict, forKey: Self.key)
			return
		}

		for entry in storedData {
			if !entry.key.hasPrefix(Self.keyPrefix) {
				continue
			}
			guard let id = Int(entry.key[Self.keyPrefix.endIndex...]) else { continue }
			guard let eventObject = entry.value as? [String: Any] else { continue }
			guard let event = StorableEvent(id: id, encoded: eventObject) else { continue }
			storedEvents.append(event)
		}

		// ensure we have a consistent ordering of events, mainly useful for the test, but also
		// ensures we roughly publish events in more or less the same order
		storedEvents.sort(by: \.id)
		// and reverse the collection so that we can remove elements from the end and still get the first element first
		// this mainly makes tests nicer because storing A, B, C and then reading them results in A, B, C, and not C, B, A
		storedEvents.reverse()
	}

	func storeEvent(event: StorableEvent) {
		var storedData = userDefaults.dictionary(forKey: Self.key) ?? [:]
		if storedData[Self.keyDataVersion] as? Int != Self.version {
			storedData = [Self.keyDataVersion: Self.version]
		}
		storedData["\(Self.keyPrefix)\(event.id)"] = event.encode()
		userDefaults.setValue(storedData, forKey: Self.key)
	}

	func removeEvent(event: StorableEvent) {
		var storedData = userDefaults.dictionary(forKey: Self.key) ?? [:]
		if storedData[Self.keyDataVersion] as? Int != Self.version {
			storedData = [Self.keyDataVersion: Self.version]
		}
		storedData.removeValue(forKey: "\(Self.keyPrefix)\(event.id)")
		userDefaults.setValue(storedData, forKey: Self.key)
	}

	func readStoredEvent() -> StorableEvent? {
		return storedEvents.popLast()
	}

	func getNextId() -> Int {
		var storedData = userDefaults.dictionary(forKey: Self.key) ?? [:]
		if storedData[Self.keyDataVersion] as? Int != Self.version {
			storedData = [Self.keyDataVersion: Self.version]
		}
		let nextId = storedData[Self.keyNextId] as? Int ?? 1
		storedData[Self.keyNextId] = nextId + 1
		userDefaults.setValue(storedData, forKey: Self.key)
		return nextId
	}
}

struct StorableEvent: Equatable {
	static func == (lhs: StorableEvent, rhs: StorableEvent) -> Bool {
		lhs.id == rhs.id && lhs.eventId == rhs.eventId && lhs.event == rhs.event && lhs.happenedAt == rhs.happenedAt && lhs.sequenceNumber == rhs.sequenceNumber
			&& lhs.sdkVersion.name == rhs.sdkVersion.name
	}

	let id: Int
	let eventId: StringID
	let event: PublishableUserEvent
	let happenedAt: Date
	let sequenceNumber: Int
	let sdkVersion: any Version

	init(
		id: Int,
		event: PublishableUserEvent,
		sequenceNumber: Int,
		sdkVersion: any Version = currentSdkVersion()
	) {
		self.id = id
		self.eventId = StringID()
		self.event = event
		self.happenedAt = event.happenedAt ?? Date(timeIntervalSince1970: Date().timeIntervalSince1970)
		self.sequenceNumber = sequenceNumber
		self.sdkVersion = sdkVersion
	}

	init?(id: Int, encoded: [String: Any]) {
		self.id = id
		guard let eventIdString = encoded["eventId"] as? String else { return nil }
		guard let eventId = StringID(value: eventIdString) else { return nil }
		self.eventId = eventId
		guard let eventObject = encoded["event"] as? [String: Any] else { return nil }
		guard let event = PublishableUserEvent(encoded: eventObject) else { return nil }
		self.event = event
		guard let happenedAtInterval = encoded["happenedAt"] as? TimeInterval else { return nil }
		self.happenedAt = Date(timeIntervalSince1970: happenedAtInterval)
		guard let sequenceNumber = encoded["sequenceNumber"] as? Int else { return nil }
		self.sequenceNumber = sequenceNumber
		guard let sdkVersionObject = encoded["sdkVersion"] as? [String: Any],
			let major = sdkVersionObject["major"] as? UInt32,
			let minor = sdkVersionObject["minor"] as? UInt32,
			let patch = sdkVersionObject["patch"] as? UInt32,
			let name = sdkVersionObject["name"] as? String
		else { return nil }
		sdkVersion = VersionImpl(major: major, minor: minor, patch: patch, name: name)
	}

	func encode() -> [String: Any] {
		return [
			"eventId": eventId.value,
			"event": event.encode(),
			"happenedAt": happenedAt.timeIntervalSince1970,
			"sequenceNumber": sequenceNumber,
			"sdkVersion": [
				"major": sdkVersion.major,
				"minor": sdkVersion.minor,
				"patch": sdkVersion.patch,
				"name": sdkVersion.name,
			],
		]
	}
}

extension Array {
	mutating func sort<T: Comparable>(by keyPath: KeyPath<Element, T>) {
		return sort { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
	}
}
