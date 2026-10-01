import Foundation
import XCTest

@testable import JustTrackSDK

final class AdImpressionTests: XCTestCase {
	func testInitWithStringUnit() {
		let impression = AdImpression(unit: "banner", sdkName: "TestSDK")
		XCTAssertEqual(impression.unit, "banner")
		XCTAssertEqual(impression.sdkName, "TestSDK")
		XCTAssertNil(impression.network)
		XCTAssertNil(impression.placement)
		XCTAssertNil(impression.testGroup)
		XCTAssertNil(impression.segmentName)
		XCTAssertNil(impression.instanceName)
		XCTAssertNil(impression.bundleId)
		XCTAssertNil(impression.revenue)
	}

	func testInitWithAdUnit() {
		let impression = AdImpression(unit: .rewarded, sdkName: "AdMob")
		XCTAssertEqual(impression.unit, "rewarded")
		XCTAssertEqual(impression.sdkName, "AdMob")
	}

	func testSettersChaining() {
		let money = Money(value: 1.5, currency: "USD")
		let impression = AdImpression(unit: .banner, sdkName: "SDK")
			.set(network: "network1")
			.set(placement: "placement1")
			.set(testGroup: "groupA")
			.set(segmentName: "segment1")
			.set(instanceName: "instance1")
			.set(bundleId: "com.example.app")
			.set(revenue: money)

		XCTAssertEqual(impression.network, "network1")
		XCTAssertEqual(impression.placement, "placement1")
		XCTAssertEqual(impression.testGroup, "groupA")
		XCTAssertEqual(impression.segmentName, "segment1")
		XCTAssertEqual(impression.instanceName, "instance1")
		XCTAssertEqual(impression.bundleId, "com.example.app")
		XCTAssertEqual(impression.revenue?.value, 1.5)
		XCTAssertEqual(impression.revenue?.currency, "USD")
	}

	func testSettersWithNil() {
		let impression = AdImpression(unit: .interstitial, sdkName: "SDK")
			.set(network: nil)
			.set(placement: nil)
			.set(testGroup: nil)
			.set(segmentName: nil)
			.set(instanceName: nil)
			.set(bundleId: nil)
			.set(revenue: nil)

		XCTAssertNil(impression.network)
		XCTAssertNil(impression.placement)
		XCTAssertNil(impression.testGroup)
		XCTAssertNil(impression.segmentName)
		XCTAssertNil(impression.instanceName)
		XCTAssertNil(impression.bundleId)
		XCTAssertNil(impression.revenue)
	}
}
