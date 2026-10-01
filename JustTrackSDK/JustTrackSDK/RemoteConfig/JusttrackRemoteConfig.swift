import Foundation

/// Configuration settings for remote config.
public struct JusttrackRemoteConfigSettings {
	/// The default minimum interval between fetches in seconds.
	/// Default value is 3600 (1 hour).
	public static let defaultMinFetchIntervalInSec: TimeInterval = 60 * 60

	/// The minimum interval between fetches in seconds.
	/// If fetch is called before this interval has elapsed, cached values will be returned.
	/// Default is 3600 (1 hour).
	public var minFetchIntervalInSec: TimeInterval

	/// Creates a new configuration with the specified settings.
	///
	/// - Parameter minFetchIntervalInSec: The minimum interval between fetches in seconds.
	public init(minFetchIntervalInSec: TimeInterval = JusttrackRemoteConfigSettings.defaultMinFetchIntervalInSec) {
		self.minFetchIntervalInSec = minFetchIntervalInSec
	}
}

/// Information about an experiment assignment.
public final class JusttrackExperimentAssignment {
	/// The unique identifier of the experiment (UUID format).
	public let experimentId: String
	/// The human-readable name of the experiment.
	let experimentName: String
	/// The variant assigned to this user.
	let variant: String
	/// The config key associated with this assignment.
	public let configKey: String
	/// The raw config value for this assignment.
	public let configValue: String
	/// Whether this assignment is pending activation.
	public internal(set) var isPending: Bool

	/// Returns the config value as a String.
	public var stringValue: String { configValue }

	/// Returns the config value as an Int, or nil if conversion fails.
	public var intValue: Int? { Int(configValue) }

	/// Returns the config value as a Double, or nil if conversion fails.
	public var doubleValue: Double? { Double(configValue) }

	/// Returns the config value as a Bool (true if "true", false if "false", nil otherwise).
	public var boolValue: Bool? {
		switch configValue.lowercased() {
		case "true": return true
		case "false": return false
		default: return nil
		}
	}

	init(
		experimentId: String,
		experimentName: String,
		variant: String,
		configKey: String,
		configValue: String,
		isPending: Bool
	) {
		self.experimentId = experimentId
		self.experimentName = experimentName
		self.variant = variant
		self.configKey = configKey
		self.configValue = configValue
		self.isPending = isPending
	}
}

/// Remote config functionality for retrieving and activating experiment assignments.
public protocol JusttrackRemoteConfig {
	/// All current experiment assignments.
	var allAssignments: [JusttrackExperimentAssignment] { get }

	/// Fetches remote config assignments from the server if the minimum fetch interval has elapsed.
	/// Otherwise uses the cached assignments.
	///
	/// - Parameter completion: Called when the fetch completes, with an error if it failed.
	func fetch(completion: @escaping (Error?) -> Void)

	/// Fetches remote config assignments from the server if the minimum fetch interval has elapsed.
	/// Otherwise uses the cached assignments.
	///
	/// - Throws: An error if the fetch fails and no cached assignments are available.
	@available(iOS 13.0, *)
	func fetch() async throws

	/// Returns the assignment for the given config key, or nil if not found.
	///
	/// - Parameter configKey: The config key to look up.
	/// - Returns: The assignment if found, nil otherwise.
	func get(configKey: String) -> JusttrackExperimentAssignment?

	/// Returns the string value for the given config key, or nil if not found.
	///
	/// - Parameter configKey: The config key to look up.
	/// - Returns: The string value if found, nil otherwise.
	func getString(configKey: String) -> String?

	/// Returns the bool value for the given config key, or nil if not found or not a valid bool.
	///
	/// - Parameter configKey: The config key to look up.
	/// - Returns: The bool value if found and valid, nil otherwise.
	func getBool(configKey: String) -> Bool?

	/// Returns the int value for the given config key, or nil if not found or not a valid int.
	///
	/// - Parameter configKey: The config key to look up.
	/// - Returns: The int value if found and valid, nil otherwise.
	func getInt(configKey: String) -> Int?

	/// Returns the double value for the given config key, or nil if not found or not a valid double.
	///
	/// - Parameter configKey: The config key to look up.
	/// - Returns: The double value if found and valid, nil otherwise.
	func getDouble(configKey: String) -> Double?

	/// Activates experiment assignments by confirming enrollment with the server.
	/// After successful activation, the `isPending` property of each assignment is set to `false`.
	///
	/// - Parameters:
	///   - assignments: The assignments to activate.
	///   - completion: Called when the activation completes, with an error if it failed.
	func activate(_ assignments: [JusttrackExperimentAssignment], completion: @escaping (Error?) -> Void)

	/// Activates experiment assignments by confirming enrollment with the server.
	/// After successful activation, the `isPending` property of each assignment is set to `false`.
	///
	/// - Parameter assignments: The assignments to activate.
	/// - Throws: An error if the activation fails.
	@available(iOS 13.0, *)
	func activate(_ assignments: [JusttrackExperimentAssignment]) async throws

	/// Activates experiments by their IDs by confirming enrollment with the server.
	/// After successful activation, the `isPending` property of each matching assignment is set to `false`.
	///
	/// - Parameters:
	///   - experimentIds: The experiment IDs to activate.
	///   - completion: Called when the activation completes, with an error if it failed.
	func activate(experimentIds: [String], completion: @escaping (Error?) -> Void)

	/// Activates experiments by their IDs by confirming enrollment with the server.
	/// After successful activation, the `isPending` property of each matching assignment is set to `false`.
	///
	/// - Parameter experimentIds: The experiment IDs to activate.
	/// - Throws: An error if the activation fails.
	@available(iOS 13.0, *)
	func activate(experimentIds: [String]) async throws

	/// A convenience method that fetches and then activates all pending experiments in one call.
	///
	/// - Parameter completion: Called when the operation completes, with an error if it failed.
	func fetchAndActivate(completion: @escaping (Error?) -> Void)

	/// A convenience method that fetches and then activates all pending experiments in one call.
	///
	/// - Throws: An error if either fetch or activate fails.
	@available(iOS 13.0, *)
	func fetchAndActivate() async throws

	/// Applies configuration settings for remote config.
	///
	/// - Parameter settings: The configuration settings to apply.
	func setConfig(_ settings: JusttrackRemoteConfigSettings)
}
