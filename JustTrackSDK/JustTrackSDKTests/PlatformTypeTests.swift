import Foundation
import XCTest

@testable import JustTrackSDK

final class PlatformTypeTests: XCTestCase {
	func testAllDescriptions() {
		XCTAssertEqual(PlatformType.native.description, "iOS")
		XCTAssertEqual(PlatformType.unity.description, "Unity; iOS")
		XCTAssertEqual(PlatformType.reactNative.description, "ReactNative; iOS")
		XCTAssertEqual(PlatformType.flutter.description, "Flutter; iOS")
	}

	func testAllWrappers() {
		XCTAssertNil(PlatformType.native.wrapper)
		XCTAssertEqual(PlatformType.unity.wrapper, "unity")
		XCTAssertEqual(PlatformType.reactNative.wrapper, "react-native")
		XCTAssertEqual(PlatformType.flutter.wrapper, "flutter")
	}

	func testRawValues() {
		XCTAssertEqual(PlatformType.native.rawValue, "native")
		XCTAssertEqual(PlatformType.unity.rawValue, "unity")
		XCTAssertEqual(PlatformType.reactNative.rawValue, "reactNative")
		XCTAssertEqual(PlatformType.flutter.rawValue, "flutter")
	}
}
