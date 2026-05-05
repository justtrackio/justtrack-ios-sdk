/// Represents errors that can occur within the justtrack SDK.
public enum JustTrackError: Error, CustomStringConvertible, LocalizedError, Equatable {
	case badApiToken(String)
	case custom(String)
	case missingBundleIdentifier
	case notOnMainThread
	case stopped
}

public extension JustTrackError {
	/// Returns a string representation of the error.
	var description: String {
		message
	}

	/// Returns a localized description of the error.
	var errorDescription: String? {
		NSLocalizedString(message, comment: comment)
	}
}

extension JustTrackError {
	var message: String {
		switch self {
		case let .badApiToken(apiToken):
			return "The provided API token is invalid: '\(apiToken)'"
		case let .custom(message):
			return "A custom error: \(message)"
		case .missingBundleIdentifier:
			return "Failed to determine the bundle identifier of the app."
		case .notOnMainThread:
			return "The called method must be called from the main thread only."
		case .stopped:
			return "The SDK is not running. Call the start() method first and then retry your request."
		}
	}

	var comment: String {
		switch self {
		case .badApiToken:
			return "Invalid Credentials"
		case let .custom(message):
			return message
		case .missingBundleIdentifier:
			return "Wrong App Setup"
		case .notOnMainThread:
			return "Wrong App Implementation"
		case .stopped:
			return "To make the SDK operatable please call its start() method."
		}
	}
}
