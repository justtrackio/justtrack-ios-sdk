import Foundation
import JustTrackSDK

public final class JusttrackGoogleOdmAdapter: JusttrackAdapter {
	static let name = "\(JusttrackGoogleOdmAdapter.self) v\(JusttrackGoogleOdmAdapter.version)"

	static let version = "1.0.1"

	public init() {
	}

	public func integrate(
		sdk: any JustTrackSdk,
		logger: any JustTrackSDK.Logger
	) -> Future<Void> {
		func log(
			error: Error
		) {
			logger.warn("[\(JusttrackGoogleOdmAdapter.name)] Couldn't integrate Google ODM: \(error.localizedDescription)")
		}

		let promise = FutureImpl<Void>()

		JusttrackObjCGoogleOdmAdapter().fetchOdmInfo(
			onSuccess: { odmInfo in
				guard let odmInfo else {
					logger.info("[\(JusttrackGoogleOdmAdapter.name)] No Google ODM info available")
					promise.resolve(())
					return
				}

				sdk.set(odmInfo: odmInfo).observe { settingResult in
					switch settingResult {
					case let .failure(error):
						log(error: error)
						promise.reject(error)
					case .success:
						logger.info("[\(JusttrackGoogleOdmAdapter.name)] Successfully integrated Google ODM")
						promise.resolve(())
					}
				}
			}, onFailure: { error in
				log(error: error)
				promise.reject(error)
			}
		)

		return promise.toFuture()
	}
}
