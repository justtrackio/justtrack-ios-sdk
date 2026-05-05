import Foundation

struct DTOPostEnrollmentRequest: Codable, Equatable {
	let installInstanceId: String
	let experimentIds: [String]

	func json() throws -> Data {
		let encoder = JSONEncoder()
		encoder.outputFormatting = .sortedKeys
		return try encoder.encode(self)
	}
}

extension DTOPostEnrollmentRequest {
	init(installId: StringID, experimentIds: [String]) {
		self.installInstanceId = installId.value
		self.experimentIds = experimentIds
	}
}
