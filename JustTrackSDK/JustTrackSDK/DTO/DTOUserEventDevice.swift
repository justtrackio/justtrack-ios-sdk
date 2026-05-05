import Foundation

struct DTOUserEventDevice: Codable {
	let connectionType: String
	let os: DTOUserEventDeviceOS
	let date: String

	init(connectionType: String, os: DTOUserEventDeviceOS, date: Date) {
		self.connectionType = connectionType
		self.os = os
		self.date = formatDateMilliseconds(date)
	}
}
