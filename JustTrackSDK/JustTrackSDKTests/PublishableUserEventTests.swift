import XCTest

@testable import JustTrackSDK

final class PublishableUserEventTests: XCTestCase {
	// MARK: - init(name:sessionId:dimensions:value:unit:currency:happenedAt:)

	func testInitConvertsSecondsToMilliseconds() {
		let event = PublishableUserEvent(
			name: "test",
			sessionId: "s1",
			dimensions: [:],
			value: 3.0,
			unit: .seconds,
			currency: nil,
			happenedAt: nil
		)
		XCTAssertEqual(event.value, 3000.0, accuracy: 0.001)
		XCTAssertEqual(event.unit, .milliseconds)
	}

	func testInitPreservesMillisecondsUnit() {
		let event = PublishableUserEvent(
			name: "test",
			sessionId: "s1",
			dimensions: [:],
			value: 500.0,
			unit: .milliseconds,
			currency: nil,
			happenedAt: nil
		)
		XCTAssertEqual(event.value, 500.0, accuracy: 0.001)
		XCTAssertEqual(event.unit, .milliseconds)
	}

	func testInitPreservesCountUnit() {
		let event = PublishableUserEvent(
			name: "e",
			sessionId: "s",
			dimensions: [:],
			value: 7.0,
			unit: .count,
			currency: nil,
			happenedAt: nil
		)
		XCTAssertEqual(event.value, 7.0, accuracy: 0.001)
		XCTAssertEqual(event.unit, .count)
	}

	func testInitPreservesNilUnit() {
		let event = PublishableUserEvent(
			name: "e",
			sessionId: "s",
			dimensions: [:],
			value: 1.0,
			unit: nil,
			currency: "EUR",
			happenedAt: nil
		)
		XCTAssertNil(event.unit)
		XCTAssertEqual(event.currency, "EUR")
	}

	func testInitStoresDimensions() {
		let dims = ["k1": "v1", "k2": "v2"]
		let event = PublishableUserEvent(
			name: "e",
			sessionId: "s",
			dimensions: dims,
			value: 1.0,
			unit: .count,
			currency: nil,
			happenedAt: nil
		)
		XCTAssertEqual(event.dimensions, dims)
	}

	func testInitStoresHappenedAt() {
		let date = Date(timeIntervalSince1970: 1_000_000)
		let event = PublishableUserEvent(
			name: "e",
			sessionId: "s",
			dimensions: [:],
			value: 1.0,
			unit: .count,
			currency: nil,
			happenedAt: date
		)
		XCTAssertEqual(event.happenedAt, date)
	}

	// MARK: - init?(encoded:)

	func testDecodingSucceedsWithMinimalValidPayload() {
		let encoded: [String: Any] = [
			"name": "my_event",
			"sessionId": "ses-1",
			"dimensions": [String: Any](),
			"value": Double(5.0),
		]
		let event = PublishableUserEvent(encoded: encoded)
		XCTAssertNotNil(event)
		XCTAssertEqual(event?.name, "my_event")
		XCTAssertEqual(event?.sessionId, "ses-1")
		XCTAssertEqual(event?.value ?? -1, 5.0, accuracy: 0.001)
		XCTAssertNil(event?.unit)
		XCTAssertNil(event?.currency)
		XCTAssertNil(event?.happenedAt)
	}

	func testDecodingSucceedsWithUnit() {
		let encoded: [String: Any] = [
			"name": "e",
			"sessionId": "s",
			"dimensions": [String: Any](),
			"value": Double(1.0),
			"unit": "count",
		]
		let event = PublishableUserEvent(encoded: encoded)
		XCTAssertEqual(event?.unit, .count)
	}

	func testDecodingSucceedsWithCurrency() {
		let encoded: [String: Any] = [
			"name": "e",
			"sessionId": "s",
			"dimensions": [String: Any](),
			"value": Double(1.0),
			"currency": "USD",
		]
		let event = PublishableUserEvent(encoded: encoded)
		XCTAssertEqual(event?.currency, "USD")
	}

	func testDecodingFailsOnMissingName() {
		let encoded: [String: Any] = [
			"sessionId": "s",
			"dimensions": [String: Any](),
			"value": Double(1.0),
		]
		XCTAssertNil(PublishableUserEvent(encoded: encoded))
	}

	func testDecodingFailsOnMissingSessionId() {
		let encoded: [String: Any] = [
			"name": "e",
			"dimensions": [String: Any](),
			"value": Double(1.0),
		]
		XCTAssertNil(PublishableUserEvent(encoded: encoded))
	}

	func testDecodingFailsOnMissingValue() {
		let encoded: [String: Any] = [
			"name": "e",
			"sessionId": "s",
			"dimensions": [String: Any](),
		]
		XCTAssertNil(PublishableUserEvent(encoded: encoded))
	}

	func testDecodingFailsOnMissingDimensions() {
		let encoded: [String: Any] = [
			"name": "e",
			"sessionId": "s",
			"value": Double(1.0),
		]
		XCTAssertNil(PublishableUserEvent(encoded: encoded))
	}

	func testDecodingFailsOnUnknownUnit() {
		let encoded: [String: Any] = [
			"name": "e",
			"sessionId": "s",
			"dimensions": [String: Any](),
			"value": Double(1.0),
			"unit": "unknownUnit",
		]
		XCTAssertNil(PublishableUserEvent(encoded: encoded))
	}

	func testDecodingFiltersNonStringDimensionValues() {
		let encoded: [String: Any] = [
			"name": "e",
			"sessionId": "s",
			"dimensions": ["valid": "value", "invalid": 42] as [String: Any],
			"value": Double(1.0),
		]
		let event = PublishableUserEvent(encoded: encoded)
		XCTAssertEqual(event?.dimensions, ["valid": "value"])
	}

	// MARK: - encode()

	func testEncodeRoundTrip() {
		let original = PublishableUserEvent(
			name: "checkout",
			sessionId: "session-99",
			dimensions: ["screen": "cart"],
			value: 9.99,
			unit: .count,
			currency: "EUR",
			happenedAt: nil
		)
		let encoded = original.encode()
		let decoded = PublishableUserEvent(encoded: encoded)
		XCTAssertNotNil(decoded)
		XCTAssertEqual(decoded?.name, original.name)
		XCTAssertEqual(decoded?.sessionId, original.sessionId)
		XCTAssertEqual(decoded?.value ?? -1, original.value, accuracy: 0.001)
		XCTAssertEqual(decoded?.unit, original.unit)
		XCTAssertEqual(decoded?.currency, original.currency)
	}

	func testEncodeOmitsNilUnit() {
		let event = PublishableUserEvent(
			name: "e",
			sessionId: "s",
			dimensions: [:],
			value: 1.0,
			unit: nil,
			currency: nil,
			happenedAt: nil
		)
		let encoded = event.encode()
		XCTAssertNil(encoded["unit"])
	}

	func testEncodeOmitsNilCurrency() {
		let event = PublishableUserEvent(
			name: "e",
			sessionId: "s",
			dimensions: [:],
			value: 1.0,
			unit: .count,
			currency: nil,
			happenedAt: nil
		)
		let encoded = event.encode()
		XCTAssertNil(encoded["currency"])
	}

	func testEncodeIncludesUnitRawValue() {
		let event = PublishableUserEvent(
			name: "e",
			sessionId: "s",
			dimensions: [:],
			value: 1.0,
			unit: .milliseconds,
			currency: nil,
			happenedAt: nil
		)
		let encoded = event.encode()
		XCTAssertEqual(encoded["unit"] as? String, "milliseconds")
	}

	// MARK: - description

	func testDescriptionContainsEventName() {
		let event = PublishableUserEvent(
			name: "my_event",
			sessionId: "s",
			dimensions: [:],
			value: 1.0,
			unit: .count,
			currency: nil,
			happenedAt: nil
		)
		XCTAssertTrue(event.description.contains("my_event"))
	}

	func testDescriptionShowsCurrencyWhenUnitIsNil() {
		let event = PublishableUserEvent(
			name: "purchase",
			sessionId: "s",
			dimensions: [:],
			value: 9.99,
			unit: nil,
			currency: "USD",
			happenedAt: nil
		)
		XCTAssertTrue(event.description.contains("USD"))
	}

	func testDescriptionShowsNullWhenBothUnitAndCurrencyAreNil() {
		let event = PublishableUserEvent(
			name: "e",
			sessionId: "s",
			dimensions: [:],
			value: 1.0,
			unit: nil,
			currency: nil,
			happenedAt: nil
		)
		XCTAssertTrue(event.description.contains("null"))
	}

	func testDescriptionContainsDimensions() {
		let event = PublishableUserEvent(
			name: "e",
			sessionId: "s",
			dimensions: ["key": "val"],
			value: 1.0,
			unit: .count,
			currency: nil,
			happenedAt: nil
		)
		XCTAssertTrue(event.description.contains("key"))
		XCTAssertTrue(event.description.contains("val"))
	}

	func testDescriptionContainsNowWhenHappenedAtIsNil() {
		let event = PublishableUserEvent(
			name: "e",
			sessionId: "s",
			dimensions: [:],
			value: 1.0,
			unit: .count,
			currency: nil,
			happenedAt: nil
		)
		XCTAssertTrue(event.description.contains("now"))
	}

	func testDescriptionContainsDateWhenHappenedAtIsSet() {
		let date = Date(timeIntervalSince1970: 0)
		let event = PublishableUserEvent(
			name: "e",
			sessionId: "s",
			dimensions: [:],
			value: 1.0,
			unit: .count,
			currency: nil,
			happenedAt: date
		)
		// The description should NOT contain "now"
		XCTAssertFalse(event.description.contains("now"))
	}

	// MARK: - Equatable

	func testEqualEventsAreEqual() {
		let date = Date(timeIntervalSince1970: 1_000_000)
		let a = PublishableUserEvent(
			name: "e",
			sessionId: "s",
			dimensions: ["k": "v"],
			value: 2.0,
			unit: .count,
			currency: "EUR",
			happenedAt: date
		)
		let b = PublishableUserEvent(
			name: "e",
			sessionId: "s",
			dimensions: ["k": "v"],
			value: 2.0,
			unit: .count,
			currency: "EUR",
			happenedAt: date
		)
		XCTAssertEqual(a, b)
	}

	func testDifferentNameProducesInequality() {
		let a = PublishableUserEvent(name: "a", sessionId: "s", dimensions: [:], value: 1.0, unit: .count, currency: nil, happenedAt: nil)
		let b = PublishableUserEvent(name: "b", sessionId: "s", dimensions: [:], value: 1.0, unit: .count, currency: nil, happenedAt: nil)
		XCTAssertNotEqual(a, b)
	}
}
