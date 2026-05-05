@testable import JustTrackSDK

extension DTOUserEventEvent {
	static func fixture(
		id: String = "id",
		name: String = "name",
		dimensions: [String: String] = [:],
		value: Double = 1.0,
		unit: Unit? = .milliseconds,
		currency: String? = "currency",
		sessionId: String = "sessionId",
		happenedAt: Date = Date.init(timeIntervalSince1970: 41),
		sequenceNumber: Int = 41
	) -> DTOUserEventEvent {
		DTOUserEventEvent(
			id: id,
			name: name,
			dimensions: dimensions,
			value: value,
			unit: unit,
			currency: currency,
			sessionId: sessionId,
			happenedAt: happenedAt,
			sequenceNumber: sequenceNumber
		)
	}
}

extension DTOUserEventEvent: @retroactive Equatable {
	public static func == (lhs: DTOUserEventEvent, rhs: DTOUserEventEvent) -> Bool {
		lhs.id == rhs.id && lhs.name == rhs.name && lhs.dimensions == rhs.dimensions && lhs.value == rhs.value && lhs.unit == rhs.unit && lhs.currency == rhs.currency
			&& lhs.sessionId == rhs.sessionId && lhs.happenedAt == rhs.happenedAt
	}
}
