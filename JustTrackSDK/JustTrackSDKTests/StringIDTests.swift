import XCTest

@testable import JustTrackSDK

final class StringIDTests: XCTestCase {
	func testInitsWithUUIDWhenValidUUIDIsProvided() {
		let uuid = UUID()
		let stringID = StringID(value: uuid)

		XCTAssertEqual(stringID.value, uuid.uuidString.lowercased())
	}

	func testInitsWithUUIDTWhenValidUUIDTIsProvided() {
		let uuid = UUID()
		let uuidt = uuid.uuid
		let stringID = StringID(value: uuidt)

		XCTAssertEqual(stringID.value, uuid.uuidString.lowercased())
	}

	func testInitsWithUniqueStringsWhenCalledMultipleTimes() {
		let stringID1 = StringID()
		let stringID2 = StringID()

		XCTAssertNotEqual(stringID1.value, stringID2.value)

		XCTAssertNotNil(UUID(uuidString: stringID1.value))
		XCTAssertNotNil(UUID(uuidString: stringID2.value))

		XCTAssertEqual(stringID1.value, stringID1.value.lowercased())
		XCTAssertEqual(stringID2.value, stringID2.value.lowercased())
	}

	func testInitsFromStringWhenValidLowercaseUUIDStringIsProvided() {
		let uuidString = "550e8420-e29b-41d4-a716-446655450000"
		let stringID = StringID(value: uuidString)

		XCTAssertEqual(stringID?.value, uuidString)
	}

	func testInitsFromStringWhenValidUppercaseUUIDStringIsProvided() {
		let uuidString = "550E8420-E29B-41D4-A716-446655445000"
		let stringID = StringID(value: uuidString)

		XCTAssertEqual(stringID?.value, uuidString.lowercased())
	}

	func testDoesNotInitFromInvalidStrings() {
		let invalidStrings = [
			"not-a-uuid",
			"",
			"550E8420-E29B-41D4-A716",  // Too short
			"550E8420-E29B-41D4-A716-446655445000-EXTRA",  // Too long
			"550E8420-E29B-41D4-XXXX-446655445000",  // Invalid characters
			"550E8420E29B41D4A716446655445000",  // Missing hyphens
		]

		for string in invalidStrings {
			let stringID = StringID(value: string)
			XCTAssertNil(stringID, "StringID should be nil for invalid string: \(string)")
		}
	}

	func testDescriptionIsCorrect() {
		let uuid = UUID()
		let stringID = StringID(value: uuid)

		XCTAssertEqual(stringID.description, uuid.uuidString.lowercased())
	}

	func testInitsFromDescriptionWhenValidLowercaseUUIDStringIsProvided() {
		let uuidString = "550e8420-e29b-41d4-a716-446655445000"
		let stringID = StringID(uuidString)

		XCTAssertEqual(stringID?.description, uuidString)
	}

	func testInitsFromDescriptionWhenValidUppercaseUUIDStringIsProvided() {
		let uuidString = "550E8420-E29B-41D4-A716-446655445000"
		let stringID = StringID(uuidString)

		XCTAssertEqual(stringID?.value, uuidString.lowercased())
	}

	func testDoesNotInitFromDescriptionWhenInvalidStringIsProvided() {
		let stringID = StringID("invalid-uuid")
		XCTAssertNil(stringID)
	}

	func testEqualsAnotherStringIDWhenTwoStringIDsAreCreatedFromSameUUID() {
		let uuid = UUID()
		let stringID1 = StringID(value: uuid)
		let stringID2 = StringID(value: uuid)

		XCTAssertEqual(stringID1, stringID2)
	}

	func testEqualsAnotherStringIDWhenStringIDsHaveSameValueButDifferentCase() {
		let stringID1 = StringID(value: "550E8420-E29B-41D4-A716-446655445000")
		let stringID2 = StringID(value: "550e8420-e29b-41d4-a716-446655445000")

		XCTAssertEqual(stringID1, stringID2)
	}

	func testDoesNotEqualAnotherStringIDWhenTwoStringIDsHaveDifferentValues() {
		let stringID1 = StringID()
		let stringID2 = StringID()

		XCTAssertNotEqual(stringID1, stringID2)
	}

	func testConsistentLowercasingReturnsEqualStringIDsWhenCreatedThroughDifferentInitPaths() {
		let mixedCaseUUID = "550E8420-e29B-41D4-a716-446655445000"

		let stringID1 = StringID(value: mixedCaseUUID)
		let stringID2 = StringID(mixedCaseUUID)
		let uuid = UUID(uuidString: mixedCaseUUID)!
		let stringID3 = StringID(value: uuid)

		let expectedValue = mixedCaseUUID.lowercased()

		XCTAssertEqual(stringID1?.value, expectedValue)
		XCTAssertEqual(stringID2?.value, expectedValue)
		XCTAssertEqual(stringID3.value, expectedValue)

		XCTAssertEqual(stringID1, stringID2)
		XCTAssertEqual(stringID2, stringID3)
	}
}
