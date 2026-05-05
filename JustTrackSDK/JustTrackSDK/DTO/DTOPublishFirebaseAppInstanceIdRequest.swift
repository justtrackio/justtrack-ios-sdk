import Foundation

struct DTOPublishFirebaseAppInstanceIdRequest: Codable, Equatable, DTO {
	let uuid: String
	let firebaseInstanceId: String

	func json() throws -> Data {
		return try JSONEncoder().encode(self)
	}
}
