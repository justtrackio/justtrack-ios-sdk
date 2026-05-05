import Foundation

struct DTOLogInput: Codable, Equatable, DTO {
	let messages: [DTOLogMessage]
	let metrics: [DTOLogMetric]
	let appVersion: DTOAppVersion
	let sdkVersion: DTOSdkVersion
	let clientDate: String

	init(messages: [DTOLogMessage], metrics: [DTOLogMetric], appVersion: DTOAppVersion, sdkVersion: DTOSdkVersion, clientDate: Date) {
		self.messages = messages
		self.metrics = metrics
		self.appVersion = appVersion
		self.sdkVersion = sdkVersion
		self.clientDate = formatDateMilliseconds(clientDate)
	}

	func json() throws -> Data {
		return try JSONEncoder().encode(self)
	}
}
