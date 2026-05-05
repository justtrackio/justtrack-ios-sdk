import Foundation

/// Represents a monetary value with currency.
public struct Money {
	/// The numeric monetary value.
	public let value: Double
	/// The ISO 4217 3-letter currency code.
	public let currency: String

	/// Initializes a new Money value.
	/// - Parameters:
	///   - value: The numeric monetary value.
	///   - currency: The ISO 4217 3-letter currency code.
	public init(value: Double, currency: String) {
		self.value = value
		self.currency = currency
	}

	/// Validates the monetary value.
	/// - Throws: InvalidFieldError if the value is invalid or currency format is incorrect.
	public func validate() throws {
		if !value.isFinite {
			throw InvalidFieldError(name: "value", value: value)
		}

		if currency.count != 3 || currency != currency.uppercased() {
			throw InvalidFieldError(name: "currency", value: currency, encoding: "The value needs to be an uppercase 3-letter ISO 4217 string.")
		}
	}
}
