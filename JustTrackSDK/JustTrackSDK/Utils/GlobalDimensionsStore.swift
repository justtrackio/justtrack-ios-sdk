import Foundation

/// Thread-safe persistent store for global dimensions that are automatically attached to all events.
final class GlobalDimensionsStore {
	static let key = "io.justtrack.globalDimensions"

	private let userDefaults: UserDefaults
	private let lock = NSLock()

	init(userDefaults: UserDefaults = .standard) {
		self.userDefaults = userDefaults
	}

	/// Sets a global dimension value. Pass `nil` to clear the dimension.
	///
	/// The value is validated the same way regular event dimension values are: it must be shorter than
	/// 4096 characters and only contain ISO 8859-1 characters. Invalid values are rejected and not stored.
	/// - Returns: `true` if the value was stored (or the dimension cleared), `false` if the value was invalid.
	@discardableResult
	func set(dimension: Dimension, value: String?) -> Bool {
		if let value, !isValid(dimension: dimension.rawValue, value: value) {
			return false
		}

		lock.lock()
		defer { lock.unlock() }

		var dict = userDefaults.dictionary(forKey: Self.key) ?? [:]
		if let value {
			dict[dimension.rawValue] = value
		} else {
			dict.removeValue(forKey: dimension.rawValue)
		}
		userDefaults.setValue(dict, forKey: Self.key)
		return true
	}

	/// Returns all currently set global dimensions as a dictionary of raw dimension keys to values.
	func getAll() -> [String: String] {
		lock.lock()
		defer { lock.unlock() }

		guard let dict = userDefaults.dictionary(forKey: Self.key) else {
			return [:]
		}

		var result: [String: String] = [:]
		for (key, value) in dict {
			if let stringValue = value as? String {
				result[key] = stringValue
			}
		}
		return result
	}
}
