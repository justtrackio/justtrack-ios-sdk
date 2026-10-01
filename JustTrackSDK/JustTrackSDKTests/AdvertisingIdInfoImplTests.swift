import Foundation
import XCTest

@testable import JustTrackSDK

final class AdvertisingIdInfoImplTests: XCTestCase {
	func testWithAdvertiserIdIsNotLimited() {
		let info = AdvertisingIdInfoImpl(advertiserId: "some-id")
		XCTAssertEqual(info.advertiserId, "some-id")
		XCTAssertFalse(info.isLimitedAdTracking)
	}

	func testWithNilAdvertiserIdIsLimited() {
		let info = AdvertisingIdInfoImpl(advertiserId: nil)
		XCTAssertNil(info.advertiserId)
		XCTAssertTrue(info.isLimitedAdTracking)
	}
}
