import Foundation
import XCTest

@testable import JustTrackSDK

final class AdUnitTests: XCTestCase {
	func testAllCasesHaveCorrectRawValue() {
		XCTAssertEqual(AdUnit.banner.rawValue, "banner")
		XCTAssertEqual(AdUnit.interstitial.rawValue, "interstitial")
		XCTAssertEqual(AdUnit.rewarded.rawValue, "rewarded")
		XCTAssertEqual(AdUnit.rewardedInterstitial.rawValue, "rewarded_interstitial")
		XCTAssertEqual(AdUnit.native.rawValue, "native")
		XCTAssertEqual(AdUnit.appOpen.rawValue, "app_open")
	}

	func testNameMatchesRawValue() {
		XCTAssertEqual(AdUnit.banner.name, "banner")
		XCTAssertEqual(AdUnit.interstitial.name, "interstitial")
		XCTAssertEqual(AdUnit.rewarded.name, "rewarded")
		XCTAssertEqual(AdUnit.rewardedInterstitial.name, "rewarded_interstitial")
		XCTAssertEqual(AdUnit.native.name, "native")
		XCTAssertEqual(AdUnit.appOpen.name, "app_open")
	}
}
