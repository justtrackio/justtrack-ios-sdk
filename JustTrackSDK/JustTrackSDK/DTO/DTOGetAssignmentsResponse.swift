import Foundation

struct DTOAssignment: Codable, Equatable {
	let experiment: String
	let variant: String
	let experimentId: String
	let variantId: String
	let configKey: String
	let configValue: String
	let pending: Bool?
}

struct DTOGetAssignmentsResponse: JsonSerializable {
	let assignments: [DTOAssignment]

	init(data: Data) throws {
		let response = try JSONDecoder().decode(GetAssignmentsResponseCodable.self, from: data)
		self.assignments = response.assignments ?? []
	}

	init(assignments: [DTOAssignment]) {
		self.assignments = assignments
	}
}

private struct GetAssignmentsResponseCodable: Codable {
	// Backend can return null for assignments. Codable cannot parse null as empty array,
	// so we use optional here and default to [] in DTOGetAssignmentsResponse.init(data:)
	let assignments: [DTOAssignment]?  // swiftlint:disable:this discouraged_optional_collection
}
