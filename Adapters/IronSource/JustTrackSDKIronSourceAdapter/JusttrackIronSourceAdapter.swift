import Foundation
import JustTrackSDK

public final class JusttrackIronSourceAdapter: JusttrackAdapter {
	static let name = "\(JusttrackIronSourceAdapter.self) v\(JusttrackIronSourceAdapter.version)"

	static let version = "2.0.0"

	public init() {}

	public func integrate(
		sdk: any JustTrackSdk,
		logger: any JustTrackSDK.Logger
	) -> Future<Void> {
		let promise = FutureImpl<Void>()

		JusttrackObjCIronSourceAdapter().integrateImpressionDataBlock(
			{ impressionData in
				guard let impressionData = impressionData, let adUnit = impressionData.adUnit else {
					logger.warn("[\(JusttrackIronSourceAdapter.name)] Received nil impression data")
					return
				}
				
				var impression = AdImpression(
					unit: adUnit,
					sdkName: "ironSource"
				)
				.set(network: impressionData.adNetwork)
				.set(placement: impressionData.placement)
				.set(testGroup: impressionData.abTesting)
				.set(segmentName: impressionData.segmentName)
				.set(instanceName: impressionData.instanceName)
				
				if let revenue = impressionData.revenue {
					impression = impression.set(revenue: Money(value: revenue.doubleValue, currency: "USD"))
				}
				
				sdk.forward(adImpression: impression).observe { forwardResult in
					switch forwardResult {
					case let .failure(error):
						logger.warn("[\(JusttrackIronSourceAdapter.name)] Could not forward IronSource impression: \(error.localizedDescription)")
					case .success:
						logger.debug("[\(JusttrackIronSourceAdapter.name)] Successfully forwarded IronSource impression")
					}
				}
			},
			onSuccess: {
				logger.info("[\(JusttrackIronSourceAdapter.name)] Successfully integrated IronSource")
				promise.resolve(())
			}, onFailure: { error in
				logger.warn("[\(JusttrackIronSourceAdapter.name)] Couldn't integrate IronSource: \(error.localizedDescription)")
				promise.reject(error)
			}
		)

		return promise.toFuture()
	}
}
