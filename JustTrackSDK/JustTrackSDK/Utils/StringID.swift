import Foundation

/// A lowercased representation of UUID.
struct StringID: Equatable {
	let value: String

	init(
		value: UUID
	) {
		self.value = value.uuidString.lowercased()
	}

	init(
		value: uuid_t
	) {
		self.init(value: UUID(uuid: value))
	}

	init() {
		self.init(value: UUID())
	}

	init?(
		value: String
	) {
		guard let uuid = UUID(uuidString: value) else { return nil }
		self.init(value: uuid)
	}
}

extension StringID: LosslessStringConvertible {
	var description: String { value }

	init?(
		_ description: String
	) {
		self.init(value: description)
	}
}
