@testable import JustTrackSDK

extension DTOAttributionRequest {
	static func fixture(
		appVersion: DTOAppVersion = .fixture(),
		sdkVersion: DTOSdkVersion = .fixture(),
		user: DTOAttributionRequestUser = .fixture(),
		device: DTOAttributionRequestDevice = .fixture(),
		claims: [String] = [],
		parameters: [String: String] = [:]
	) -> DTOAttributionRequest {
		DTOAttributionRequest(
			appVersion: appVersion,
			sdkVersion: sdkVersion,
			user: user,
			device: device,
			claims: claims,
			parameters: parameters
		)
	}
}
