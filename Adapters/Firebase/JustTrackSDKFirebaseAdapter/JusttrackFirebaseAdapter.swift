import Foundation
import JustTrackSDK

public final class JusttrackFirebaseAdapter: JusttrackAdapter {
	static let name = "\(JusttrackFirebaseAdapter.self) v\(JusttrackFirebaseAdapter.version)"

	static let version = "1.0.0"

	public init() {
	}

	public func integrate(
		sdk: any JustTrackSdk,
		logger: any JustTrackSDK.Logger
	) -> Future<Void> {
		func log(
			error: Error
		) {
			logger.warn("[\(JusttrackFirebaseAdapter.name)] Couldn't integrate Firebase: \(error.localizedDescription)")
		}

		let promise = FutureImpl<Void>()

		JusttrackObjCFirebaseAdapter().integrate(
			onSuccess: { firebaseAppInstanceId in
				sdk.set(firebaseAppInstanceId: firebaseAppInstanceId).observe { settingResult in
					switch settingResult {
					case let .failure(error):
						log(error: error)
						promise.reject(error)
					case .success:
						logger.info("[\(JusttrackFirebaseAdapter.name)] Successfully integrated Firebase")
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
