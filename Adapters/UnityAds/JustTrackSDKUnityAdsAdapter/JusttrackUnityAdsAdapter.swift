import Foundation
import JustTrackSDK

public final class JusttrackUnityAdsAdapter: JusttrackAdapter {
	static let name = "\(JusttrackUnityAdsAdapter.self) v\(JusttrackUnityAdsAdapter.version)"
	
	static let version = "1.0.1"
	
	public init() {
	}
	
	public func integrate(
		sdk: any JustTrackSdk,
		logger: any JustTrackSDK.Logger
	) -> Future<Void> {
		let promise = FutureImpl<Void>()
		JusttrackObjCUnityAdsAdapter().integrate(
			forwardBlock: { eventName, placement, isComplete in
				switch eventName {
				case "banner":
					let impression = AdImpression(unit: "banner", sdkName: "unityAds")
						.set(placement: placement)
					
					sdk.forward(adImpression: impression).observe { forwardResult in
						switch forwardResult {
						case let .failure(error):
							logger.warn("[\(JusttrackUnityAdsAdapter.name)] Could not forward UnityAds banner impression: \(error.localizedDescription)")
						case .success:
							logger.debug("[\(JusttrackUnityAdsAdapter.name)] Successfully forwarded UnityAds banner impression")
						}
					}
				case "impression":
					let unit = isComplete == true ? "rewarded" : "interstitial"
					let impression = AdImpression(unit: unit, sdkName: "unityAds")
						.set(placement: placement)
					
					sdk.forward(adImpression: impression).observe { forwardResult in
						switch forwardResult {
						case let .failure(error):
							logger.warn("[\(JusttrackUnityAdsAdapter.name)] Could not forward UnityAds \(unit) impression: \(error.localizedDescription)")
						case .success:
							logger.debug("[\(JusttrackUnityAdsAdapter.name)] Successfully forwarded UnityAds \(unit) impression")
						}
					}
				default:
					logger.warn("[\(JusttrackUnityAdsAdapter.name)] Unknown event type: \(eventName)")
				}
			},
			reporting: { message in
				logger.warn("[\(JusttrackUnityAdsAdapter.name)] Integration warning: \(message)")
			},
			onSuccess: { version in
				logger.info("[\(JusttrackUnityAdsAdapter.name)] Successfully integrated UnityAds version: \(version)")
				promise.resolve(())
			},
			onFailure: { error in
				logger.warn("[\(JusttrackUnityAdsAdapter.name)] Couldn't integrate UnityAds: \(error.localizedDescription)")
				promise.reject(error)
			}
		)
		return promise.toFuture()
	}
}
