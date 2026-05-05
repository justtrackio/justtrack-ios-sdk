/// Protocol for integrating third-party adapters with the justtrack SDK.
public protocol JusttrackAdapter {
	/// Integrates the adapter with the justtrack SDK.
	/// - Parameters:
	///   - sdk: The justtrack SDK instance.
	///   - logger: The logger to use for the adapter.
	/// - Returns: A future that completes when integration is done.
	func integrate(sdk: JustTrackSdk, logger: JustTrackSDK.Logger) -> Future<Void>
}
