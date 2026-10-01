import Foundation

/// Deeplink handler for Google Ads campaigns.
///
/// Extracts the `gbraid` parameter from deeplink URLs. The `gbraid` parameter is used by Google
/// for attribution measurement on iOS as a privacy-preserving alternative to device-level tracking.
enum GoogleDeeplinkHandler {
	/// Extracts the `gbraid` value from a deeplink URL, or returns `nil` if not present or empty.
	static func handle(url: URL) -> String? {
		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
			let queryItems = components.queryItems,
			let gbraid = queryItems.first(where: { $0.name == "gbraid" })?.value,
			!gbraid.isEmpty
		else {
			return nil
		}

		return gbraid
	}
}
