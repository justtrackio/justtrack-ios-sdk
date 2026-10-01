@testable import JustTrackSDK

final class MockLogger: Logger {
	enum Level: String, Equatable {
		case debug
		case info
		case warn
		case error
		case metric
	}

	struct Entry: Equatable {
		let level: Level
		let message: String
		let fields: [[String: String]]
		let exception: String?

		init(level: Level, message: String, fields: [[String: String]] = [], exception: String? = nil) {
			self.level = level
			self.message = message
			self.fields = fields
			self.exception = exception
		}
	}

	private(set) var entries = [Entry]()

	func debug(_ message: String, _ fields: [LoggerFields]) {
		entries.append(Entry(level: .debug, message: message, fields: fields.map { $0.getFields() }))
	}

	func info(_ message: String, _ fields: [LoggerFields]) {
		entries.append(Entry(level: .info, message: message, fields: fields.map { $0.getFields() }))
	}

	func warn(_ message: String, _ fields: [LoggerFields]) {
		entries.append(Entry(level: .warn, message: message, fields: fields.map { $0.getFields() }))
	}

	func error(_ message: String, _ fields: [LoggerFields]) {
		entries.append(Entry(level: .error, message: message, fields: fields.map { $0.getFields() }))
	}

	func error(_ message: String, _ exception: Error, _ fields: [LoggerFields]) {
		entries.append(Entry(level: .error, message: message, fields: fields.map { $0.getFields() }, exception: exception.localizedDescription))
	}

	func publishMetric(_ metric: Metric, _ value: Double, _ dimensions: [LoggerFields]) {
		entries.append(Entry(level: .metric, message: metric.metric, fields: dimensions.map { $0.getFields() }))
	}
}
