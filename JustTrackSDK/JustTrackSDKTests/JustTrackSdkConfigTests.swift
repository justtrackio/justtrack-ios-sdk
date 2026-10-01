import Foundation
import XCTest

@testable import JustTrackSDK

final class JustTrackSdkConfigTests: XCTestCase {
	func testDefaultInit() {
		let config = JustTrackSdkConfig()
		XCTAssertNil(config.trackingInfo)
		XCTAssertNil(config.userId)
	}

	func testInitWithTrackingInfo() {
		let info = try! JustTrackSdkConfig.TrackingInfo(id: "testId", provider: "testProvider")
		let config = JustTrackSdkConfig(trackingInfo: info)
		XCTAssertNotNil(config.trackingInfo)
		XCTAssertEqual(config.trackingInfo?.id, "testId")
		XCTAssertEqual(config.trackingInfo?.provider, "testProvider")
	}

	func testSetValidUserId() throws {
		var config = JustTrackSdkConfig()
		try config.set(userId: "user123")
		XCTAssertEqual(config.userId, "user123")
	}

	func testSetNilUserId() throws {
		var config = JustTrackSdkConfig()
		try config.set(userId: "user123")
		try config.set(userId: nil)
		XCTAssertNil(config.userId)
	}

	func testSetInvalidUserIdThrows() {
		var config = JustTrackSdkConfig()
		// Non-ASCII characters are invalid
		XCTAssertThrowsError(try config.set(userId: "usör"))
	}

	func testSetEmptyUserIdThrows() {
		var config = JustTrackSdkConfig()
		XCTAssertThrowsError(try config.set(userId: ""))
	}

	func testTrackingInfoWithEmptyIdReturnsNil() throws {
		let info = try JustTrackSdkConfig.TrackingInfo(id: "", provider: "provider")
		XCTAssertNil(info)
	}

	func testTrackingInfoWithEmptyProviderReturnsNil() throws {
		let info = try JustTrackSdkConfig.TrackingInfo(id: "id", provider: "")
		XCTAssertNil(info)
	}

	func testTrackingInfoWithBothEmptyReturnsNil() throws {
		let info = try JustTrackSdkConfig.TrackingInfo(id: "", provider: "")
		XCTAssertNil(info)
	}

	func testTrackingInfoWithInvalidIdThrows() {
		XCTAssertThrowsError(try JustTrackSdkConfig.TrackingInfo(id: "ünvalid", provider: "provider"))
	}

	func testTrackingInfoWithInvalidProviderThrows() {
		XCTAssertThrowsError(try JustTrackSdkConfig.TrackingInfo(id: "valid", provider: "ünvalid"))
	}

	func testDefaultStaticConfig() {
		let config = JustTrackSdkConfig.default
		XCTAssertNil(config.trackingInfo)
		XCTAssertNil(config.userId)
	}
}
