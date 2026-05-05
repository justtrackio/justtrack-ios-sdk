@testable import JustTrackSDK

extension DTOUserEvent {
	static func fixture(
		appVersion: DTOAppVersion = .fixture(),
		sdkVersion: DTOSdkVersion = .fixture(),
		user: DTOUserEventUser = .fixture(),
		device: DTOUserEventDevice = .fixture(),
		events: [DTOUserEventEvent] = [.fixture()]
	) -> DTOUserEvent {
		DTOUserEvent(
			appVersion: appVersion,
			sdkVersion: sdkVersion,
			user: user,
			device: device,
			events: events
		)
	}
}

extension DTOUserEvent: @retroactive Equatable {
	public static func == (lhs: DTOUserEvent, rhs: DTOUserEvent) -> Bool {
		lhs.appVersion == rhs.appVersion && lhs.sdkVersion == rhs.sdkVersion && lhs.user == rhs.user && lhs.device == rhs.device
			&& lhs.events == rhs.events
	}
}
