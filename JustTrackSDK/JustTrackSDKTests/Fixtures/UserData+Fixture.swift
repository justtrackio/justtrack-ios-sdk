@testable import JustTrackSDK

extension UserData {
	static func fixture(
		idfa: StringID? = nil,
		userId: StringID = StringID(value: "9DC781DE-1B7B-4A27-AC86-BD87448C4413")!,
		installId: StringID = StringID(value: "4135A1F0-D826-47E9-B1AA-A3A16AAF6B16")!
	) -> UserData {
		UserData(
			idfa: idfa,
			userId: userId,
			installId: installId
		)
	}
}
