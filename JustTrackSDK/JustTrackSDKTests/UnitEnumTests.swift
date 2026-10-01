import Foundation
import XCTest

@testable import JustTrackSDK

final class UnitEnumTests: XCTestCase {
	func testDescription() {
		XCTAssertEqual(Unit.count.description, "count")
		XCTAssertEqual(Unit.milliseconds.description, "milliseconds")
		XCTAssertEqual(Unit.seconds.description, "seconds")
	}

	func testCaseIterable() {
		XCTAssertEqual(Unit.allCases.count, 3)
		XCTAssertTrue(Unit.allCases.contains(.count))
		XCTAssertTrue(Unit.allCases.contains(.milliseconds))
		XCTAssertTrue(Unit.allCases.contains(.seconds))
	}

	func testTimeUnitGroupMilliseconds() {
		XCTAssertEqual(TimeUnitGroup.milliseconds.unitValue, .milliseconds)
	}

	func testTimeUnitGroupSeconds() {
		XCTAssertEqual(TimeUnitGroup.seconds.unitValue, .seconds)
	}
}
