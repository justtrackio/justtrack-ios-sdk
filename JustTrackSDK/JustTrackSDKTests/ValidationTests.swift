import XCTest

@testable import JustTrackSDK

final class ValidationTests: XCTestCase {
	// MARK: - isValid(dimension:)

	func testIsValidDimension() {
		let table: [(dimension: String, want: Bool)] = [
			("helloworld123", true),
			("hello_world123", true),
			("abcdef_", true),
			("_leadingunderscore", true),
			("trailingunderscore_", true),
			("123_456", true),
			("bye", true),
			("multiple__underscores", true),
			("123", true),
			("helloworld!", false),
			("", false),
			(" ", false),
			("hello-world", false),
			("hello world", false),
			("こんにちは", false),
			("grüße", false),
			("tschüss", false),
			("special$char", false),
			("special*char", false),
			("HelloWorld123", false),
			("Hello_World123", false),
			("ABCdef_", false),
			("_leadingUnderscore", false),
			("trailingUnderscore_", false),
		]

		for test in table {
			XCTAssertEqual(
				isValid(dimension: test.dimension),
				test.want,
				"\"\(test.dimension)\" \(test.want ? "should not be valid" : "should be valid")"
			)
		}
	}

	func testIsValidDimensionExactly255CharactersIsValid() {
		let value = String(repeating: "a", count: 255)
		XCTAssertTrue(isValid(dimension: value))
	}

	// MARK: - isValid(dimension:value:)

	func testIsValidDimensionValueJtTokenIsAlwaysValid() {
		// jtToken dimension bypasses value restrictions entirely
		XCTAssertTrue(isValid(dimension: Dimension.jtToken.rawValue, value: ""))
		XCTAssertTrue(isValid(dimension: Dimension.jtToken.rawValue, value: String(repeating: "x", count: 5000)))
		XCTAssertTrue(isValid(dimension: Dimension.jtToken.rawValue, value: "\u{0001}control"))
	}

	func testIsValidDimensionValueNormalDimensionRejectsLongValues() {
		let longValue = String(repeating: "a", count: 4096)
		XCTAssertFalse(isValid(dimension: "some_dimension", value: longValue))
	}

	func testIsValidDimensionValueNormalDimensionAcceptsShortAsciiValue() {
		XCTAssertTrue(isValid(dimension: "some_dimension", value: "hello"))
	}

	func testIsValidDimensionValueNormalDimensionRejectsControlCharacter() {
		// U+0001 is a control character outside ISO-8859-1 printable range
		XCTAssertFalse(isValid(dimension: "some_dimension", value: "\u{0001}"))
	}

	func testIsValidDimensionValueNormalDimensionAcceptsIso88591ExtendedChars() {
		// é (U+00E9) is within ISO-8859-1 printable range (0xA0–0xFF)
		XCTAssertTrue(isValid(dimension: "some_dimension", value: "café"))
	}

	// MARK: - isValid(trackingId:)

	func testIsValidTrackingIdAcceptsAsciiString() {
		XCTAssertTrue(isValid(trackingId: "abc-123_XYZ"))
	}

	func testIsValidTrackingIdRejectsNonAscii() {
		XCTAssertFalse(isValid(trackingId: "tschüss"))
	}

	func testIsValidTrackingIdRejectsTooLong() {
		let longId = String(repeating: "a", count: 4096)
		XCTAssertFalse(isValid(trackingId: longId))
	}

	func testIsValidTrackingIdAcceptsEmptyString() {
		XCTAssertTrue(isValid(trackingId: ""))
	}

	func testIsValidTrackingIdRejectsControlCharacter() {
		XCTAssertFalse(isValid(trackingId: "\u{0001}"))
	}

	// MARK: - isValid(trackingProvider:)

	func testIsValidTrackingProviderAcceptsAsciiString() {
		XCTAssertTrue(isValid(trackingProvider: "appsflyer"))
	}

	func testIsValidTrackingProviderRejectsNonAscii() {
		XCTAssertFalse(isValid(trackingProvider: "grüße"))
	}

	func testIsValidTrackingProviderRejectsTooLong() {
		let longProvider = String(repeating: "a", count: 4096)
		XCTAssertFalse(isValid(trackingProvider: longProvider))
	}

	// MARK: - isValid(eventName:)

	func testIsValidEventNameAcceptsShortIso88591String() {
		XCTAssertTrue(isValid(eventName: "purchase"))
	}

	func testIsValidEventNameAcceptsExtendedIso88591Char() {
		XCTAssertTrue(isValid(eventName: "café"))
	}

	func testIsValidEventNameRejectsTooLong() {
		let longName = String(repeating: "a", count: 256)
		XCTAssertFalse(isValid(eventName: longName))
	}

	func testIsValidEventNameRejectsControlCharacter() {
		XCTAssertFalse(isValid(eventName: "\u{0001}purchase"))
	}

	func testIsValidEventNameRejectsCharAbove0xFF() {
		// U+0100 is above ISO-8859-1 range
		XCTAssertFalse(isValid(eventName: "\u{0100}"))
	}

	func testIsValidEventNameRejectsCharBetween0x7FAnd0x9F() {
		// U+0081 is in the 0x7F–0x9F excluded range
		XCTAssertFalse(isValid(eventName: "\u{0081}"))
	}

	// MARK: - isValid(customUserId:)

	func testIsValidCustomUserIdAcceptsNormalString() {
		XCTAssertTrue(isValid(customUserId: "user_123"))
	}

	func testIsValidCustomUserIdRejectsEmpty() {
		XCTAssertFalse(isValid(customUserId: ""))
	}

	func testIsValidCustomUserIdRejectsTooLong() {
		let longId = String(repeating: "a", count: 4096)
		XCTAssertFalse(isValid(customUserId: longId))
	}

	func testIsValidCustomUserIdRejectsNonAscii() {
		XCTAssertFalse(isValid(customUserId: "tschüss"))
	}

	// MARK: - isValid(firebaseAppInstanceId:)

	func testIsValidFirebaseAppInstanceIdAcceptsValidId() {
		XCTAssertTrue(isValid(firebaseAppInstanceId: "abcdefgh"))
	}

	func testIsValidFirebaseAppInstanceIdRejectsTooShort() {
		XCTAssertFalse(isValid(firebaseAppInstanceId: "abc"))
	}

	func testIsValidFirebaseAppInstanceIdRejectsTooLong() {
		let longId = String(repeating: "a", count: 256)
		XCTAssertFalse(isValid(firebaseAppInstanceId: longId))
	}

	func testIsValidFirebaseAppInstanceIdRejectsNonAscii() {
		XCTAssertFalse(isValid(firebaseAppInstanceId: "abcdefgü"))
	}

	// MARK: - InvalidFieldError descriptions

	func testInvalidFieldErrorMaxLengthDescription() {
		let err = InvalidFieldError(name: "name", value: "val", maxLength: 10, encoding: "ASCII")
		XCTAssertTrue(err.description.contains("name"))
		XCTAssertTrue(err.description.contains("val"))
		XCTAssertTrue(err.description.contains("10"))
	}

	func testInvalidFieldErrorMinMaxLengthDescription() {
		let err = InvalidFieldError(name: "name", value: "val", minLength: 2, maxLength: 10, encoding: "ASCII")
		XCTAssertTrue(err.description.contains("2"))
		XCTAssertTrue(err.description.contains("10"))
	}

	func testInvalidFieldErrorDoubleValueDescription() {
		let err = InvalidFieldError(name: "price", value: Double.infinity)
		XCTAssertTrue(err.description.contains("price"))
		XCTAssertTrue(err.description.contains("finite"))
	}

	func testInvalidFieldErrorEncodingDescription() {
		let err = InvalidFieldError(name: "field", value: "v", encoding: "must be ASCII")
		XCTAssertTrue(err.description.contains("field"))
		XCTAssertTrue(err.description.contains("must be ASCII"))
	}

	func testInvalidFieldErrorDimensionsDescription() {
		let err = InvalidFieldError(fieldValue: ["k": "v"], maxDimensions: 5, currentDimensions: 6)
		XCTAssertTrue(err.description.contains("5"))
		XCTAssertTrue(err.description.contains("6"))
	}
}
