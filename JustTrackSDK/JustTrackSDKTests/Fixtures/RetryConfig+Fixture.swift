@testable import JustTrackSDK

extension RetryConfig {
	static func fixture(
		attributionRequestRetries: Int = 5,
		fetchClaimRetries: Int = 5,
		publishEventsRetries: Int = 5
	) -> RetryConfig {
		RetryConfig(
			attributionRequestRetries: attributionRequestRetries,
			fetchClaimRetries: fetchClaimRetries,
			publishEventsRetries: publishEventsRetries
		)
	}
}
