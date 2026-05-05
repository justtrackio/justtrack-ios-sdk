import Foundation

struct DTOPublishCustomUserIdRequest: DTO, Codable, Equatable {
	let installId: String
	let customUserId: String

	func json() throws -> Data {
		return try JSONEncoder().encode(self)
	}
}
