import os.log

public protocol Logger: AnyObject {
	func debug(_ message: String, _ fields: LoggerFields...)
	func info(_ message: String, _ fields: LoggerFields...)
	func warn(_ message: String, _ fields: LoggerFields...)
	func error(_ message: String, _ fields: LoggerFields...)
	func error(_ message: String, _ exception: Error, _ fields: LoggerFields...)
	func publishMetric(_ metric: Metric, _ value: Double, _ dimensions: LoggerFields...)

	func debug(_ message: String, _ fields: [LoggerFields])
	func info(_ message: String, _ fields: [LoggerFields])
	func warn(_ message: String, _ fields: [LoggerFields])
	func error(_ message: String, _ fields: [LoggerFields])
	func error(_ message: String, _ exception: Error, _ fields: [LoggerFields])
	func publishMetric(_ metric: Metric, _ value: Double, _ dimensions: [LoggerFields])
}

public extension Logger {
	/// Logs a debug message with optional fields.
	/// - Parameters:
	///   - message: The message to log.
	///   - fields: Optional fields to include with the message.
	func debug(_ message: String, _ fields: LoggerFields...) {
		debug(message, fields)
	}

	/// Logs an info message with optional fields.
	/// - Parameters:
	///   - message: The message to log.
	///   - fields: Optional fields to include with the message.
	func info(_ message: String, _ fields: LoggerFields...) {
		info(message, fields)
	}

	/// Logs a warning message with optional fields.
	/// - Parameters:
	///   - message: The message to log.
	///   - fields: Optional fields to include with the message.
	func warn(_ message: String, _ fields: LoggerFields...) {
		warn(message, fields)
	}

	/// Logs an error message with optional fields.
	/// - Parameters:
	///   - message: The message to log.
	///   - fields: Optional fields to include with the message.
	func error(_ message: String, _ fields: LoggerFields...) {
		error(message, fields)
	}

	/// Logs an error message with an exception and optional fields.
	/// - Parameters:
	///   - message: The message to log.
	///   - exception: The error to log.
	///   - fields: Optional fields to include with the message.
	func error(_ message: String, _ exception: Error, _ fields: LoggerFields...) {
		error(message, exception, fields)
	}

	/// Publishes a metric with a value and optional dimensions.
	/// - Parameters:
	///   - metric: The metric to publish.
	///   - value: The metric value.
	///   - dimensions: Optional dimensions for the metric.
	func publishMetric(_ metric: Metric, _ value: Double, _ dimensions: LoggerFields...) {
		publishMetric(metric, value, dimensions)
	}
}

/// Protocol for providing fields to include in log messages.
public protocol LoggerFields {
	/// Returns the fields as a dictionary.
	/// - Returns: Dictionary of field names to values.
	func getFields() -> [String: String]
}

public protocol LoggerFieldsBuilder: LoggerFields {
	func with(_ field: String, _ value: String?) -> LoggerFieldsBuilder
	func with(_ field: String, _ value: Error?) -> LoggerFieldsBuilder
	func with(_ field: String, _ value: Character?) -> LoggerFieldsBuilder
	func with(_ field: String, _ value: Bool?) -> LoggerFieldsBuilder
	func with(_ field: String, _ value: UInt8?) -> LoggerFieldsBuilder
	func with(_ field: String, _ value: Int8?) -> LoggerFieldsBuilder
	func with(_ field: String, _ value: UInt16?) -> LoggerFieldsBuilder
	func with(_ field: String, _ value: Int16?) -> LoggerFieldsBuilder
	func with(_ field: String, _ value: UInt32?) -> LoggerFieldsBuilder
	func with(_ field: String, _ value: Int32?) -> LoggerFieldsBuilder
	func with(_ field: String, _ value: UInt64?) -> LoggerFieldsBuilder
	func with(_ field: String, _ value: Int64?) -> LoggerFieldsBuilder
	func with(_ field: String, _ value: UInt?) -> LoggerFieldsBuilder
	func with(_ field: String, _ value: Int?) -> LoggerFieldsBuilder
	func with(_ field: String, _ value: Float?) -> LoggerFieldsBuilder
	func with(_ field: String, _ value: Double?) -> LoggerFieldsBuilder
	func with(_ field: String, _ value: Date?) -> LoggerFieldsBuilder
}

public extension LoggerFieldsBuilder {
	/// Adds a Character field to the logger fields.
	/// - Parameters:
	///   - field: The field name.
	///   - value: The Character value to add.
	/// - Returns: The builder for chaining.
	func with(_ field: String, _ value: Character?) -> LoggerFieldsBuilder {
		guard let value else { return self }
		return with(field, String(value))
	}

	/// Adds a Bool field to the logger fields.
	/// - Parameters:
	///   - field: The field name.
	///   - value: The Bool value to add.
	/// - Returns: The builder for chaining.
	func with(_ field: String, _ value: Bool?) -> LoggerFieldsBuilder {
		guard let value else { return self }
		return with(field, String(value))
	}

	/// Adds a UInt8 field to the logger fields.
	/// - Parameters:
	///   - field: The field name.
	///   - value: The UInt8 value to add.
	/// - Returns: The builder for chaining.
	func with(_ field: String, _ value: UInt8?) -> LoggerFieldsBuilder {
		guard let value else { return self }
		return with(field, String(value))
	}

	/// Adds an Int8 field to the logger fields.
	/// - Parameters:
	///   - field: The field name.
	///   - value: The Int8 value to add.
	/// - Returns: The builder for chaining.
	func with(_ field: String, _ value: Int8?) -> LoggerFieldsBuilder {
		guard let value else { return self }
		return with(field, String(value))
	}

	/// Adds a UInt16 field to the logger fields.
	/// - Parameters:
	///   - field: The field name.
	///   - value: The UInt16 value to add.
	/// - Returns: The builder for chaining.
	func with(_ field: String, _ value: UInt16?) -> LoggerFieldsBuilder {
		guard let value else { return self }
		return with(field, String(value))
	}

	/// Adds an Int16 field to the logger fields.
	/// - Parameters:
	///   - field: The field name.
	///   - value: The Int16 value to add.
	/// - Returns: The builder for chaining.
	func with(_ field: String, _ value: Int16?) -> LoggerFieldsBuilder {
		guard let value else { return self }
		return with(field, String(value))
	}

	/// Adds a UInt32 field to the logger fields.
	/// - Parameters:
	///   - field: The field name.
	///   - value: The UInt32 value to add.
	/// - Returns: The builder for chaining.
	func with(_ field: String, _ value: UInt32?) -> LoggerFieldsBuilder {
		guard let value else { return self }
		return with(field, String(value))
	}

	/// Adds an Int32 field to the logger fields.
	/// - Parameters:
	///   - field: The field name.
	///   - value: The Int32 value to add.
	/// - Returns: The builder for chaining.
	func with(_ field: String, _ value: Int32?) -> LoggerFieldsBuilder {
		guard let value else { return self }
		return with(field, String(value))
	}

	/// Adds a UInt64 field to the logger fields.
	/// - Parameters:
	///   - field: The field name.
	///   - value: The UInt64 value to add.
	/// - Returns: The builder for chaining.
	func with(_ field: String, _ value: UInt64?) -> LoggerFieldsBuilder {
		guard let value else { return self }
		return with(field, String(value))
	}

	/// Adds an Int64 field to the logger fields.
	/// - Parameters:
	///   - field: The field name.
	///   - value: The Int64 value to add.
	/// - Returns: The builder for chaining.
	func with(_ field: String, _ value: Int64?) -> LoggerFieldsBuilder {
		guard let value else { return self }
		return with(field, String(value))
	}

	/// Adds a UInt field to the logger fields.
	/// - Parameters:
	///   - field: The field name.
	///   - value: The UInt value to add.
	/// - Returns: The builder for chaining.
	func with(_ field: String, _ value: UInt?) -> LoggerFieldsBuilder {
		guard let value else { return self }
		return with(field, String(value))
	}

	/// Adds an Int field to the logger fields.
	/// - Parameters:
	///   - field: The field name.
	///   - value: The Int value to add.
	/// - Returns: The builder for chaining.
	func with(_ field: String, _ value: Int?) -> LoggerFieldsBuilder {
		guard let value else { return self }
		return with(field, String(value))
	}

	/// Adds a Float field to the logger fields.
	/// - Parameters:
	///   - field: The field name.
	///   - value: The Float value to add.
	/// - Returns: The builder for chaining.
	func with(_ field: String, _ value: Float?) -> LoggerFieldsBuilder {
		guard let value else { return self }
		return with(field, String(value))
	}

	/// Adds a Double field to the logger fields.
	/// - Parameters:
	///   - field: The field name.
	///   - value: The Double value to add.
	/// - Returns: The builder for chaining.
	func with(_ field: String, _ value: Double?) -> LoggerFieldsBuilder {
		guard let value else { return self }
		return with(field, String(value))
	}

	/// Adds a Date field to the logger fields.
	/// - Parameters:
	///   - field: The field name.
	///   - value: The Date value to add.
	/// - Returns: The builder for chaining.
	func with(_ field: String, _ value: Date?) -> LoggerFieldsBuilder {
		guard let value else { return self }
		return with(field, formatDateMilliseconds(value))
	}
}

class LoggerFieldsImpl: LoggerFieldsBuilder {
	private var fields: [String: String]

	init(fields: [String: String] = [:]) {
		self.fields = fields
	}

	public func with(_ field: String, _ value: String?) -> LoggerFieldsBuilder {
		fields[field] = value

		return self
	}

	public func with(_ field: String, _ value: Error?) -> LoggerFieldsBuilder {
		fields[field] = value?.justTrackGetErrorDescription()

		return self
	}

	public func getFields() -> [String: String] {
		return fields
	}
}

public extension Error {
	/// Returns a detailed description of the error including domain, code, and localized information.
	/// - Returns: A formatted string with error details.
	func justTrackGetErrorDescription() -> String {
		let nsError = self as NSError

		return
			"Error Domain=\(nsError.domain) Code=\(nsError.code) Description=\(nsError.localizedDescription) FailureReason=\(nsError.localizedFailureReason ?? "nil") RecoveryOptions=\(nsError.localizedRecoveryOptions ?? []) RecoverySuggestion=\(nsError.localizedRecoverySuggestion ?? "nil")"
	}
}

enum MetricUnit: String {
	case count
	case seconds
	case milliseconds
	case countAverage
	case countMaximum
	case countMinimum
	case secondsAverage
	case secondsMaximum
	case secondsMinimum
	case millisecondsAverage
	case millisecondsMaximum
	case millisecondsMinimum

	func getUnit() -> String {
		switch self {
		case .count:
			return "Count"
		case .seconds:
			return "Seconds"
		case .milliseconds:
			return "Milliseconds"
		case .countAverage:
			return "UnitCountAverage"
		case .countMaximum:
			return "UnitCountMaximum"
		case .countMinimum:
			return "UnitCountMinimum"
		case .secondsAverage:
			return "UnitSecondsAverage"
		case .secondsMaximum:
			return "UnitSecondsMaximum"
		case .secondsMinimum:
			return "UnitSecondsMinimum"
		case .millisecondsAverage:
			return "UnitMillisecondsAverage"
		case .millisecondsMaximum:
			return "UnitMillisecondsMaximum"
		case .millisecondsMinimum:
			return "UnitMillisecondsMinimum"
		}
	}
}

public struct Metric: LoggerFields {
	let metric: String
	let defaultDimensions: [String: String]
	let unit: MetricUnit

	init(metric: String, defaultDimensions: [String: String], unit: MetricUnit) {
		self.metric = metric
		self.defaultDimensions = defaultDimensions
		self.unit = unit
	}

	init(metric: String) {
		self.init(metric: metric, defaultDimensions: [:], unit: .count)
	}

	init(metric: String, unit: MetricUnit) {
		self.init(metric: metric, defaultDimensions: [:], unit: unit)
	}

	public func getFields() -> [String: String] {
		return defaultDimensions
	}
}

final class LoggerImpl: Logger {
	@available(iOS 14.0, *)
	private static let log = os.Logger(subsystem: "io.justtrack", category: "network")

	public func debug(_ message: String, _ fields: [LoggerFields]) {
		doLog(message: message, level: .debug, fields)
	}

	public func info(_ message: String, _ fields: [LoggerFields]) {
		doLog(message: message, level: .info, fields)
	}

	public func warn(_ message: String, _ fields: [LoggerFields]) {
		// os_log does not support warnings, so log them as info instead
		doLog(message: message, level: .info, fields)
	}

	public func error(_ message: String, _ fields: [LoggerFields]) {
		doLog(message: message, level: .error, fields)
	}

	public func error(_ message: String, _ exception: Error, _ fields: [LoggerFields]) {
		let newFields =
			[
				LoggerFieldsImpl().with("exception", exception)
			] + fields
		doLog(message: message, level: .error, newFields)
	}

	public func publishMetric(_ metric: Metric, _ value: Double, _ dimensions: [LoggerFields]) {
		let allDimensions =
			[
				LoggerFieldsImpl().with("metricName", metric.metric),
				LoggerFieldsImpl().with("metricValue", value),
				LoggerFieldsImpl().with("metricUnit", metric.unit.getUnit()),
			] + dimensions

		info("Writing metric to console", allDimensions)
	}

	private func doLog(message: String, level: OSLogType, _ fields: [LoggerFields]) {
		var logMessage = message

		for loggerFields in fields {
			for field in loggerFields.getFields() {
				logMessage += ", " + field.key + " = " + field.value
			}
		}

		if #available(iOS 14.0, *) {
			LoggerImpl.log.log(level: level, "JustTrackSDK: \(logMessage, privacy: .public)")
		} else {
			os_log("JustTrackSDK: %s", type: level, logMessage)
		}
	}
}

final class IdleLogger: Logger {
	func debug(_ message: String, _ fields: [LoggerFields]) {
	}

	func info(_ message: String, _ fields: [LoggerFields]) {
	}

	func warn(_ message: String, _ fields: [LoggerFields]) {
	}

	func error(_ message: String, _ fields: [LoggerFields]) {
	}

	func error(_ message: String, _ exception: Error, _ fields: [LoggerFields]) {
	}

	func publishMetric(_ metric: Metric, _ value: Double, _ dimensions: [LoggerFields]) {
	}
}

final class CompositeLogger: Logger {
	private let loggers: [Logger]

	init(
		loggers: [Logger]
	) {
		self.loggers = loggers
	}

	func debug(_ message: String, _ fields: [LoggerFields]) {
		for logger in loggers {
			logger.debug(message, fields)
		}
	}

	func info(_ message: String, _ fields: [LoggerFields]) {
		for logger in loggers {
			logger.info(message, fields)
		}
	}

	func warn(_ message: String, _ fields: [LoggerFields]) {
		for logger in loggers {
			logger.warn(message, fields)
		}
	}

	func error(_ message: String, _ fields: [LoggerFields]) {
		for logger in loggers {
			logger.error(message, fields)
		}
	}

	func error(_ message: String, _ exception: Error, _ fields: [LoggerFields]) {
		for logger in loggers {
			logger.error(message, exception, fields)
		}
	}

	func publishMetric(_ metric: Metric, _ value: Double, _ dimensions: [LoggerFields]) {
		for logger in loggers {
			logger.publishMetric(metric, value, dimensions)
		}
	}
}
