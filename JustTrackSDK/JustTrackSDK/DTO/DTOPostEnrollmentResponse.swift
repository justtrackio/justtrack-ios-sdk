import Foundation

struct DTOPostEnrollmentResponse: JsonSerializable {
	let enrolledAssignments: [DTOAssignment]

	init(data: Data) throws {
		let response = try JSONDecoder().decode(PostEnrollmentResponseCodable.self, from: data)
		self.enrolledAssignments = response.enrolledAssignments
	}

	init(enrolledAssignments: [DTOAssignment]) {
		self.enrolledAssignments = enrolledAssignments
	}
}

private struct PostEnrollmentResponseCodable: Codable {
	let enrolledAssignments: [DTOAssignment]
}
