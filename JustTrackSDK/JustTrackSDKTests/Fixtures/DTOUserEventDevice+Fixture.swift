@testable import JustTrackSDK

extension DTOUserEventDevice {
	static func fixture(
		connectionType: String = "connectionType",
		os: DTOUserEventDeviceOS = .fixture(),
		date: Date = Date.init(timeIntervalSince1970: 41)
	) -> DTOUserEventDevice {
		DTOUserEventDevice(
			connectionType: connectionType,
			os: os,
			date: date
		)
	}
}

extension DTOUserEventDevice: @retroactive Equatable {
	public static func == (lhs: DTOUserEventDevice, rhs: DTOUserEventDevice) -> Bool {
		lhs.connectionType == rhs.connectionType && lhs.os == rhs.os && lhs.date == rhs.date
	}
}
