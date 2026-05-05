import Foundation

@testable import JustTrackSDK

extension DTOAnonymizeRequest {
	static func fixture(
		installInstanceId: StringID = StringID(),
		deviceId: StringID? = StringID(),
		idfv: StringID? = StringID()
	) -> DTOAnonymizeRequest {
		return DTOAnonymizeRequest(
			installInstanceId: installInstanceId,
			deviceId: deviceId,
			idfv: idfv
		)
	}
}
