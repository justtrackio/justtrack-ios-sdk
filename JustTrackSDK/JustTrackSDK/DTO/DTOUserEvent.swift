import Foundation

struct DTOUserEvent: DTO, Codable {
	let appVersion: DTOAppVersion
	let sdkVersion: DTOSdkVersion
	let user: DTOUserEventUser
	let device: DTOUserEventDevice
	let events: [DTOUserEventEvent]

	func json() throws -> Data {
		return try JSONEncoder().encode(self)
	}
}
