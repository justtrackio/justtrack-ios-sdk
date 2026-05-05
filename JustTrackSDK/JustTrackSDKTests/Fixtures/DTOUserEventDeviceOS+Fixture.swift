@testable import JustTrackSDK

extension DTOUserEventDeviceOS {
	static func fixture(
		name: String = "iOS",
		version: String = "version"
	) -> DTOUserEventDeviceOS {
		DTOUserEventDeviceOS(
			name: name,
			version: version
		)
	}
}

extension DTOUserEventDeviceOS: @retroactive Equatable {
	public static func == (lhs: DTOUserEventDeviceOS, rhs: DTOUserEventDeviceOS) -> Bool {
		lhs.name == rhs.name && lhs.version == rhs.version
	}
}
