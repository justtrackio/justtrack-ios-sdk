@testable import JustTrackSDK

extension DTOAttributionRequestUser {
	static func fixture(
		userId: StringID = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!,
		installInstanceId: StringID = StringID(value: "41C70613-2994-42DC-BBE1-325968AF9000")!,
		idfv: StringID = StringID(value: "6C65D465-00A5-4153-8D1C-EA3B7D51958B")!,
		idfa: StringID? = nil,
		hasLimitedAdTracking: Bool = false,
		trackingId: String? = nil,
		trackingProvider: String? = nil,
		countryIso: String? = nil
	) -> DTOAttributionRequestUser {
		DTOAttributionRequestUser(
			userId: userId,
			installInstanceId: installInstanceId,
			idfv: idfv,
			idfa: idfa,
			hasLimitedAdTracking: hasLimitedAdTracking,
			trackingId: trackingId,
			trackingProvider: trackingProvider,
			countryIso: countryIso
		)
	}
}
