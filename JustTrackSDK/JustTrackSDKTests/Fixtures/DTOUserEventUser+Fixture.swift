@testable import JustTrackSDK

extension DTOUserEventUser {
	static func fixture(
		installInstanceId: String = "installInstanceId",
		countryIso: String? = "countryIso",
		localeCode: String? = "localeCode",
		deviceId: String? = "deviceId",
		idfv: String? = "idfv",
		userId: String? = "userId"
	) -> DTOUserEventUser {
		DTOUserEventUser(
			installInstanceId: installInstanceId,
			countryIso: countryIso,
			localeCode: localeCode,
			deviceId: deviceId,
			idfv: idfv,
			userId: userId
		)
	}
}

extension DTOUserEventUser: @retroactive Equatable {
	public static func == (lhs: DTOUserEventUser, rhs: DTOUserEventUser) -> Bool {
		lhs.installInstanceId == rhs.installInstanceId && lhs.countryIso == rhs.countryIso
			&& lhs.localeCode == rhs.localeCode && lhs.deviceId == rhs.deviceId
			&& lhs.idfv == rhs.idfv && lhs.userId == rhs.userId
	}
}
