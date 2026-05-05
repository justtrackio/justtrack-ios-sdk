import JustTrackSDK
import SwiftUI

final class LogMessage: ObservableObject {
	@Published var level: Level = .debug
	@Published var message: String = "Message_1"
	@Published var fields: [String: String] = [:]
}

extension LogMessage {
	enum Level: String, CaseIterable {
		case debug
		case info
		case warn
		case error
	}
}
