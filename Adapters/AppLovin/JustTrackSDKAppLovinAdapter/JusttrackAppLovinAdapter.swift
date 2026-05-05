import Foundation
import JustTrackSDK

public final class JusttrackAppLovinAdapter: JusttrackAdapter {
	static let name = "\(JusttrackAppLovinAdapter.self) v\(JusttrackAppLovinAdapter.version)"

	static let version = "1.0.1"

	private let customUserId: String?

	public init(
		customUserId: String? = nil
	) {
		self.customUserId = customUserId
	}

	public func integrate(
		sdk: any JustTrackSdk,
		logger: any JustTrackSDK.Logger
	) -> Future<Void> {
		let promise = FutureImpl<Void>()

		let impressionDataBlock: JusttrackALImpressionDataBlock = { impressionData in
			let impression = AdImpression(unit: impressionData.format, sdkName: "appLovin")
				.set(network: impressionData.network)
				.set(placement: impressionData.placement)
				.set(revenue: Money(value: impressionData.revenue.doubleValue, currency: "USD"))

			sdk.forward(adImpression: impression).observe { forwardResult in
				switch forwardResult {
				case let .failure(error):
					logger.warn("[\(JusttrackAppLovinAdapter.name)] Could not publish AppLovin impression: \(error.localizedDescription)")
				case .success:
					break
				}
			}
		}

		JusttrackObjCAppLovinAdapter().integrateCustomUserId(
			customUserId,
			impressionDataBlock: impressionDataBlock,
			onSuccess: {
				logger.info("[\(JusttrackAppLovinAdapter.name)] Successfully integrated AppLovin")
				promise.resolve(())
			},
			onFailure: { error in
				logger.error("[\(JusttrackAppLovinAdapter.name)] Couldn't integrate AppLovin: \(error.localizedDescription)")
				promise.reject(error)
			}
		)

		return promise.toFuture()
	}
}
