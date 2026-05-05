import Foundation

struct DTOLogMessage: Codable, Equatable {
	let level: String
	let message: String
	let fields: [String: String]
	let timestamp: String

	init(_ level: String, _ message: String, _ fields: [String: String], _ timestamp: Date) {
		self.level = level
		self.message = message
		self.fields = fields
		self.timestamp = formatDateMilliseconds(timestamp)
	}

	init?(encoded: [String: Any]) {
		guard let level = encoded["level"] as? String else { return nil }
		guard let message = encoded["message"] as? String else { return nil }
		guard let fieldsDict = encoded["fields"] as? [String: Any] else { return nil }
		var fields: [String: String] = [:]
		for (fieldName, fieldValue) in fieldsDict {
			guard let value = fieldValue as? String else { return nil }
			fields[fieldName] = value
		}
		guard let timestampString = encoded["timestamp"] as? String else { return nil }
		guard let timestamp = parseDate(timestampString) else { return nil }
		self.init(level, message, fields, timestamp)
	}

	func encode() -> [String: Any] {
		return [
			"level": level,
			"message": message,
			"fields": fields,
			"timestamp": timestamp,
		]
	}
}

struct DTOLogMetric: Codable, Equatable {
	let metric: String
	let dimensions: [String: String]
	let value: Double
	let unit: String
	let timestamp: String

	init(_ metric: String, _ dimensions: [String: String], _ value: Double, _ unit: String, _ timestamp: Date) {
		self.metric = metric
		self.dimensions = dimensions
		self.value = value
		self.unit = unit
		self.timestamp = formatDateMilliseconds(timestamp)
	}

	init?(encoded: [String: Any]) {
		guard let metric = encoded["metric"] as? String else { return nil }
		guard let dimensionsDict = encoded["dimensions"] as? [String: Any] else { return nil }
		var dimensions: [String: String] = [:]
		for (dimensionName, dimensionValue) in dimensionsDict {
			guard let value = dimensionValue as? String else { return nil }
			dimensions[dimensionName] = value
		}
		guard let value = encoded["value"] as? Double else { return nil }
		guard let unit = encoded["unit"] as? String else { return nil }
		guard let timestampString = encoded["timestamp"] as? String else { return nil }
		guard let timestamp = parseDate(timestampString) else { return nil }
		self.init(metric, dimensions, value, unit, timestamp)
	}

	func encode() -> [String: Any] {
		return [
			"metric": metric,
			"dimensions": dimensions,
			"value": value,
			"unit": unit,
			"timestamp": timestamp,
		]
	}
}
