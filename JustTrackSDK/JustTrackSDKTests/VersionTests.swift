import XCTest

@testable import JustTrackSDK

final class VersionTests: XCTestCase {
	func testInitialized() {
		let version = VersionImpl(major: 1, minor: 2, patch: 3, name: "1.2.3")
		XCTAssertEqual(version.major, 1)
		XCTAssertEqual(version.minor, 2)
		XCTAssertEqual(version.patch, 3)
		XCTAssertEqual(version.name, "1.2.3")
	}

	func testCompared() {
		let v1 = VersionImpl(major: 1, minor: 0, patch: 0, name: "1.0.0")
		let v2 = VersionImpl(major: 1, minor: 1, patch: 0, name: "1.1.0")
		let v3 = VersionImpl(major: 1, minor: 1, patch: 1, name: "1.1.1")
		let v4 = VersionImpl(major: 2, minor: 0, patch: 0, name: "2.0.0")
		let v5 = VersionImpl(major: 1, minor: 0, patch: 0, name: "1.0.0-alpha")
		let v6 = VersionImpl(major: 1, minor: 0, patch: 0, name: "1.0.0-beta")

		XCTAssertEqual(v1.compare(v2), .orderedAscending)
		XCTAssertEqual(v2.compare(v1), .orderedDescending)
		XCTAssertEqual(v2.compare(v3), .orderedAscending)
		XCTAssertEqual(v3.compare(v4), .orderedAscending)
		XCTAssertEqual(v4.compare(v1), .orderedDescending)
		XCTAssertEqual(v5.compare(v6), .orderedAscending)
		XCTAssertEqual(v6.compare(v5), .orderedDescending)
	}

	func testEqual() {
		let v1 = VersionImpl(major: 1, minor: 2, patch: 3, name: "1.2.3")
		let v2 = VersionImpl(major: 1, minor: 2, patch: 3, name: "1.2.3")
		let v3 = VersionImpl(major: 1, minor: 2, patch: 4, name: "1.2.4")

		XCTAssertEqual(v1, v2)
		XCTAssertNotEqual(v1, v3)
	}
}
