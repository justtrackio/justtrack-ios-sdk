import XCTest

@testable import JustTrackSDK

final class UserDataTests: XCTestCase {
	func testProvidesIdfaWhenIdfaIsNotNil() {
		XCTAssertTrue(
			UserData(
				idfa: StringID(),
				userId: StringID(),
				installId: StringID()
			).providesIdfa
		)
	}

	func testDoesNotProvideIdfaWhenIdfaIsNil() {
		XCTAssertFalse(
			UserData(
				idfa: nil,
				userId: StringID(),
				installId: StringID()
			).providesIdfa
		)
	}
}
