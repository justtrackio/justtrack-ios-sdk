import XCTest

@testable import JustTrackSDK

final class UserDefaultsSequenceNumberProviderTests: XCTestCase {
	override func setUp() {
		UserDefaults.standard.removeObject(forKey: "io.justtrack.sdk.UserDefaultsSequenceNumberProvider.key")
		UserDefaults.standard.removeObject(forKey: "custom-key")
	}

	func testProvidesCorrectNumberWhenCustomKeyIsNotSet() {
		let provider = UserDefaultsSequenceNumberProvider()
		for expectedNumber in 0...199 {
			XCTAssertEqual(provider.provideNext(), expectedNumber)
		}
	}

	func testProvidesCorrectNumberWhenCustomKeyIsSet() {
		let provider = UserDefaultsSequenceNumberProvider(key: "custom-key")
		for expectedNumber in 0...199 {
			XCTAssertEqual(provider.provideNext(), expectedNumber)
		}
	}
}
