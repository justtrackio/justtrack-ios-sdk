@testable import JustTrackSDK

extension DTOLogMessage {
	static func fixture(
		level: String = "warn",
		message: String = "message_1",
		fields: [String: String] = [:],
		timestamp: Date = Date(timeIntervalSince1970: 41)
	) -> DTOLogMessage {
		DTOLogMessage(level, message, fields, timestamp)
	}
}
