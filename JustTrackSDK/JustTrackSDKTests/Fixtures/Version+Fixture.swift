@testable import JustTrackSDK

extension DTOAppVersion {
	static func fixture(
		code: String = "1",
		name: String = "1.0.0"
	) -> DTOAppVersion {
		DTOAppVersion(AppVersionImpl(code: code, name: name))
	}
}

extension DTOSdkVersion {
	static func fixture(
		major: UInt32 = 1,
		minor: UInt32 = 1,
		patch: UInt32 = 1,
		name: String = "1.1.1",
		platform: String = "ios",
		wrapper: String? = nil
	) -> DTOSdkVersion {
		DTOSdkVersion(major: major, minor: minor, patch: patch, name: name, platform: platform, wrapper: wrapper)
	}
}
