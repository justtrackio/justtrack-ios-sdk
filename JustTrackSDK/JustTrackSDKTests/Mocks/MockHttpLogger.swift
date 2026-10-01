@testable import JustTrackSDK

final class MockHttpLogger: HttpLogger {
	enum Level {
		case debug
		case info
		case warn
		case error
		case metric
	}

	struct Entry {
		let level: Level
		let message: String
	}

	struct MetricEntry {
		let name: String
		let value: Double
		let unit: String
	}

	private(set) var entries = [Entry]()
	private(set) var metricEntries = [MetricEntry]()

	func breadcrumb(
		message: String,
		category: String,
		level: String,
		fields: [LoggerFields]
	) {
	}

	func debug(
		_ message: String,
		_ fields: [LoggerFields]
	) {
		entries.append(Entry(level: .debug, message: message))
	}

	func error(
		_ message: String,
		_ exception: Error,
		_ fields: [LoggerFields]
	) {
		entries.append(Entry(level: .error, message: message))
	}

	func error(
		_ message: String,
		_ fields: [LoggerFields]
	) {
		entries.append(Entry(level: .error, message: message))
	}

	func getFallback() -> Logger {
		self
	}

	func info(
		_ message: String,
		_ fields: [LoggerFields]
	) {
		entries.append(Entry(level: .info, message: message))
	}

	func publishMetric(
		_ metric: Metric,
		_ value: Double,
		_ dimensions: [LoggerFields]
	) {
		entries.append(Entry(level: .metric, message: metric.metric))
		metricEntries.append(MetricEntry(name: metric.metric, value: value, unit: metric.unit.rawValue))
	}

	var onSendToServer: (() -> Void)?

	func sendToServer() {
		onSendToServer?()
	}

	func set(
		installId: StringID
	) {
	}

	func warn(
		_ message: String,
		_ fields: [LoggerFields]
	) {
		entries.append(Entry(level: .warn, message: message))
	}
}
