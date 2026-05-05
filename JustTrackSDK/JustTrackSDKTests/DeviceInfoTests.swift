import XCTest

@testable import JustTrackSDK

class DeviceInfoTests: XCTestCase {
	func testGetDevice() {
		let value = DeviceInfo.getDevice()

		// should be something like x86_64
		XCTAssertNotEqual("", value)
	}

	func testGetBuild() {
		let value = DeviceInfo.getBuild()

		// should be something like 21G115
		XCTAssertNotEqual("", value)
	}

	func testGetMachine() {
		let value = DeviceInfo.getMachine()

		// should be something like x86_64
		XCTAssertNotEqual("", value)
	}

	func testGetProduct() {
		let value = DeviceInfo.getProduct()

		// should be something like iPad
		XCTAssertNotEqual("", value)
	}

	func testGetSystemName() {
		let value = DeviceInfo.getSystemName()

		// should be something like iPadOS
		XCTAssertNotEqual("", value)
	}

	func testGetSystemVersion() {
		let value = DeviceInfo.getSystemVersion()

		// should be something like 15.5
		XCTAssertNotEqual("", value)
	}

	func testGetDarwinVersion() {
		let value = DeviceInfo.getDarwinVersion()

		// should be something like 21.6.0
		XCTAssertNotEqual("", value)
	}
}
