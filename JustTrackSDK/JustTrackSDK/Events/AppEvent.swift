import Foundation

/// Represents a set of dimensions for the AppEvent
public typealias Dimensions = [String: String]

/// Represents an application event that can be tracked by the justtrack SDK.
public class AppEvent {
	private static let maxDimensionSize = 10

	let name: String
	private(set) var sessionId: String?
	private(set) var dimensions: [String: String]
	private(set) var value: Double
	private(set) var unit: Unit?
	private(set) var currency: String?
	private(set) var happenedAt: Date?

	/// Initializes a new AppEvent with a name.
	/// - Parameter name: The name of the event.
	public init(
		_ name: String
	) {
		self.name = name
		self.sessionId = nil
		self.dimensions = [:]
		self.value = 0.0
		self.unit = nil
		self.currency = nil
		self.happenedAt = nil
	}

	/// Initializes a new AppEvent with a name, value and unit.
	/// - Parameters:
	///   - name: The name of the event.
	///   - value: The numeric value associated with the event.
	///   - unit: The unit of measurement for the value.
	public init(
		name: String,
		value: Double,
		unit: Unit
	) {
		self.name = name
		self.sessionId = nil
		self.dimensions = [:]
		self.value = value
		self.unit = unit
		self.currency = nil
		self.happenedAt = nil
	}

	/// Initializes a new AppEvent with a name and monetary value.
	/// - Parameters:
	///   - name: The name of the event.
	///   - money: The monetary value associated with the event.
	public init(
		name: String,
		money: Money
	) {
		self.name = name
		self.sessionId = nil
		self.dimensions = [:]
		self.value = money.value
		self.unit = nil
		self.currency = money.currency
		self.happenedAt = nil
	}

	init(
		name: String,
		sessionId: String?,
		dimensions: Dimensions,
		value: Double?,
		unit: Unit?,
		currency: String?,
		happenedAt: Date?
	) {
		self.name = name
		self.sessionId = sessionId
		self.dimensions = dimensions
		self.value = value ?? 0
		self.unit = unit
		self.currency = currency
		self.happenedAt = happenedAt
	}

	/// Initializes a new AppEvent with a name, dimensions and optional value, unit, and currency.
	/// - Parameters:
	///   - name: The name of the event.
	///   - dimensions: The dimensions of the event.
	///   - value: The numeric value associated with the event.
	///   - unit: The unit of measurement for the value.
	public init(
		name: String,
		dimensions: Dimensions,
		value: Double? = nil,
		unit: Unit? = nil,
		currency: String? = nil
	) {
		self.name = name
		self.sessionId = nil
		self.dimensions = dimensions
		self.value = value ?? 0
		self.unit = unit
		self.currency = currency
		self.happenedAt = nil
	}

	/// Adds a dimension to the event.
	/// - Parameters:
	///   - dimension: The dimension to add.
	///   - value: The value for the dimension.
	/// - Returns: The event itself for method chaining.
	public func add(dimension: Dimension, value: String) -> AppEvent {
		return add(dimension: dimension.stringValue, value: value)
	}

	/// Adds a dimension to the event.
	/// - Parameters:
	///   - dimension: The dimension name to add.
	///   - value: The value for the dimension.
	/// - Returns: The event itself for method chaining.
	public func add(dimension: String, value: String) -> AppEvent {
		if dimension != "" {
			if value == "" {
				self.dimensions.removeValue(forKey: dimension)
			} else {
				self.dimensions[dimension] = value
			}
		}

		return self
	}

	/// Removes a dimension from the event.
	/// - Parameter dimension: The dimension to remove.
	/// - Returns: The event itself for method chaining.
	public func remove(dimension: Dimension) -> AppEvent {
		return self.remove(dimension: dimension.stringValue)
	}

	/// Removes a dimension from the event.
	/// - Parameter dimension: The dimension name to remove.
	/// - Returns: The event itself for method chaining.
	public func remove(dimension: String) -> AppEvent {
		self.dimensions.removeValue(forKey: dimension)

		return self
	}

	/// Sets a value with unit for the event.
	/// - Parameters:
	///   - value: The numeric value to set.
	///   - unit: The unit of measurement for the value.
	/// - Returns: The event itself for method chaining.
	public func set(value: Double?, unit: Unit) -> AppEvent {
		guard let value else {
			return self
		}

		self.value = value
		self.unit = unit
		self.currency = nil

		return self
	}

	/// Sets a monetary value for the event.
	/// - Parameter money: The monetary value to set.
	/// - Returns: The event itself for method chaining.
	public func set(money: Money) -> AppEvent {
		self.value = money.value
		self.unit = nil
		self.currency = money.currency

		return self
	}

	/// Sets a count value for the event.
	/// - Parameter count: The count value to set.
	/// - Returns: The event itself for method chaining.
	public func set(count: Double) -> AppEvent {
		set(value: count, unit: .count)
	}

	/// Sets a time value in seconds for the event.
	/// - Parameter seconds: The time value in seconds.
	/// - Returns: The event itself for method chaining.
	public func set(seconds: Double) -> AppEvent {
		set(value: seconds, unit: .seconds)
	}

	/// Sets a time value in milliseconds for the event.
	/// - Parameter milliseconds: The time value in milliseconds.
	/// - Returns: The event itself for method chaining.
	public func set(milliseconds: Double) -> AppEvent {
		set(value: milliseconds, unit: .milliseconds)
	}

	/// Validates the event to ensure all fields meet requirements.
	/// - Throws: InvalidFieldError if validation fails.
	public func validate() throws {
		if name.isEmpty || !isValid(eventName: name) {
			throw InvalidFieldError(name: "name", value: name, minLength: 1, maxLength: 256, encoding: "ISO 8859-1")
		}

		for (dimensionName, dimensionValue) in dimensions {
			if !isValid(dimension: dimensionName) {
				throw InvalidFieldError(name: "dimensions", value: dimensionName, maxLength: 256, encoding: "[a-z0-9_]+")
			}
			if !isValid(dimension: dimensionName, value: dimensionValue) {
				throw InvalidFieldError(name: "dimensions.\(dimensionName)", value: dimensionValue, maxLength: 4096, encoding: "ISO 8859-1")
			}
		}

		if dimensions.count > AppEvent.maxDimensionSize {
			throw InvalidFieldError(fieldValue: dimensions, maxDimensions: AppEvent.maxDimensionSize, currentDimensions: dimensions.count)
		}

		if !value.isFinite {
			throw InvalidFieldError(name: "value", value: value)
		}

		if let currency {
			try Money(value: value, currency: currency).validate()
		}
	}

	func getDimensions() -> [String: String] {
		return dimensions
	}

	func add(dimension: Dimension, value: String?) -> AppEvent {
		guard let value else {
			return self
		}

		return add(dimension: dimension, value: value)
	}

	func set(money: Money?) -> AppEvent {
		guard let money else {
			return self
		}

		return set(money: money)
	}

	func build(sessionId: String) -> PublishableUserEvent {
		PublishableUserEvent(name: name, sessionId: self.sessionId ?? sessionId, dimensions: dimensions, value: value, unit: unit, currency: currency, happenedAt: happenedAt)
	}
}
