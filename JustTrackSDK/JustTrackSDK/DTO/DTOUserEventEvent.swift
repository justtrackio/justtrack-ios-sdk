import Foundation

struct DTOUserEventEvent: Codable {
	let id: String
	let name: String
	let dimensions: [String: String]
	let value: Double
	let unit: Unit?
	let currency: String?
	let sessionId: String
	let happenedAt: String
	let sequenceNumber: Int

	init(id: String, name: String, dimensions: [String: String], value: Double, unit: Unit?, currency: String?, sessionId: String, happenedAt: Date, sequenceNumber: Int) {
		self.id = id
		self.name = name
		self.dimensions = dimensions
		self.value = value
		self.unit = unit
		self.currency = currency
		self.sessionId = sessionId
		self.happenedAt = formatDateMilliseconds(happenedAt)
		self.sequenceNumber = sequenceNumber
	}

	enum CodingKeys: String, CodingKey {
		case id, name, dimensions, value, unit, currency, sessionId, happenedAt, sequenceNumber
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(id, forKey: .id)
		try container.encode(name, forKey: .name)

		// Only encoded if the dict is not empty
		if !dimensions.isEmpty {
			try container.encode(dimensions, forKey: .dimensions)
		}

		// Only encode value if unit or currency is present
		if unit != nil || currency != nil {
			try container.encode(value, forKey: .value)
		}

		if let unit {
			try container.encode(unit, forKey: .unit)
		}

		if let currency {
			try container.encode(currency, forKey: .currency)
		}

		try container.encode(sessionId, forKey: .sessionId)
		try container.encode(happenedAt, forKey: .happenedAt)
		try container.encode(sequenceNumber, forKey: .sequenceNumber)
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(String.self, forKey: .id)
		name = try container.decode(String.self, forKey: .name)
		dimensions = try container.decodeIfPresent([String: String].self, forKey: .dimensions) ?? [:]
		value = try container.decodeIfPresent(Double.self, forKey: .value) ?? 0
		unit = try container.decodeIfPresent(Unit.self, forKey: .unit)
		currency = try container.decodeIfPresent(String.self, forKey: .currency)
		sessionId = try container.decode(String.self, forKey: .sessionId)
		happenedAt = try container.decode(String.self, forKey: .happenedAt)
		sequenceNumber = try container.decode(Int.self, forKey: .sequenceNumber)
	}
}
