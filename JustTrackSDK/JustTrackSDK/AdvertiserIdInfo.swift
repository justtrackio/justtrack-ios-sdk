/// Protocol that provides access to advertising identifier information.
public protocol AdvertiserIdInfo {
	/// The advertiser ID (IDFA) of the user (if the user opted in to ad tracking).
	var advertiserId: String? { get }
	/// True if the user hasn't opted in to ad tracking.
	var isLimitedAdTracking: Bool { get }
}
