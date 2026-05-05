import Foundation

protocol DTO {
	func json() throws -> Data
}

protocol JsonSerializable {
	init(data: Data) throws
}

extension DTOAppVersion {
	init(_ appVersion: AppVersion) {
		code = appVersion.code
		name = appVersion.name
	}
}

extension DTOSdkVersion {
	init(_ version: any Version, platformType: PlatformType) {
		major = version.major
		minor = version.minor
		patch = version.patch
		name = version.name
		platform = "ios"
		wrapper = platformType.wrapper
	}

	init(_ version: any Version) {
		major = version.major
		minor = version.minor
		patch = version.patch
		name = version.name
		platform = "ios"
		wrapper = nil
	}
}

let enUs = Locale.init(identifier: "en_US")
let utc = TimeZone(abbreviation: "UTC")
let dateFormatSeconds = "yyyy-MM-dd'T'HH:mm:ss'Z'"
let dateFormatMilliseconds = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

func formatDateSeconds(_ date: Date) -> String {
	let formatter = DateFormatter()
	formatter.dateFormat = dateFormatSeconds
	formatter.timeZone = utc
	formatter.locale = enUs

	return formatter.string(from: date)
}

func formatDateMilliseconds(_ date: Date) -> String {
	let formatter = DateFormatter()
	formatter.dateFormat = dateFormatMilliseconds
	formatter.timeZone = utc
	formatter.locale = enUs

	return formatter.string(from: date)
}

func parseDate(_ date: String) -> Date? {
	let formatter = DateFormatter()
	formatter.dateFormat = dateFormatMilliseconds
	formatter.timeZone = utc
	formatter.locale = enUs

	if let date = formatter.date(from: date) {
		return date
	}

	formatter.dateFormat = dateFormatSeconds

	return formatter.date(from: date)
}

class DTODecodingError: NSObject, LocalizedError {
	let message: String

	init(_ message: String) {
		self.message = message
	}

	override var description: String {
		"DTODecodingError: \(message)"
	}
}
