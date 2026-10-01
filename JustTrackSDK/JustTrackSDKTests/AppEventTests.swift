import Foundation
import XCTest

@testable import JustTrackSDK

final class AppEventTests: XCTestCase {
	func testInitWithNameOnly() {
		let event = AppEvent("test_event")
		XCTAssertEqual(event.name, "test_event")
		XCTAssertNil(event.sessionId)
		XCTAssertTrue(event.dimensions.isEmpty)
		XCTAssertEqual(event.value, 0.0)
		XCTAssertNil(event.unit)
		XCTAssertNil(event.currency)
		XCTAssertNil(event.happenedAt)
	}

	func testInitWithValueAndUnit() {
		let event = AppEvent(name: "score", value: 42.5, unit: .count)
		XCTAssertEqual(event.name, "score")
		XCTAssertEqual(event.value, 42.5)
		XCTAssertEqual(event.unit, .count)
		XCTAssertNil(event.currency)
	}

	func testInitWithMoney() {
		let money = Money(value: 9.99, currency: "EUR")
		let event = AppEvent(name: "purchase", money: money)
		XCTAssertEqual(event.name, "purchase")
		XCTAssertEqual(event.value, 9.99)
		XCTAssertEqual(event.currency, "EUR")
		XCTAssertNil(event.unit)
	}

	func testInitWithDimensions() {
		let dims: Dimensions = ["key1": "val1", "key2": "val2"]
		let event = AppEvent(name: "event", dimensions: dims, value: 1.0, unit: .seconds, currency: nil)
		XCTAssertEqual(event.dimensions.count, 2)
		XCTAssertEqual(event.dimensions["key1"], "val1")
		XCTAssertEqual(event.value, 1.0)
		XCTAssertEqual(event.unit, .seconds)
	}

	func testInitWithDimensionsNoOptionals() {
		let event = AppEvent(name: "event", dimensions: [:])
		XCTAssertEqual(event.value, 0.0)
		XCTAssertNil(event.unit)
		XCTAssertNil(event.currency)
	}

	func testInternalInitWithAllParams() {
		let date = Date()
		let event = AppEvent(
			name: "internal",
			sessionId: "sess-123",
			dimensions: ["d1": "v1"],
			value: nil,
			unit: .milliseconds,
			currency: "USD",
			happenedAt: date
		)
		XCTAssertEqual(event.sessionId, "sess-123")
		XCTAssertEqual(event.value, 0.0)
		XCTAssertEqual(event.unit, .milliseconds)
		XCTAssertEqual(event.currency, "USD")
		XCTAssertEqual(event.happenedAt, date)
	}

	func testAddDimensionWithEnum() {
		let event = AppEvent("event")
			.add(dimension: JustTrackSDK.Dimension.jtAction, value: "click")
		XCTAssertEqual(event.dimensions[JustTrackSDK.Dimension.jtAction.rawValue], "click")
	}

	func testAddDimensionWithString() {
		let event = AppEvent("event")
			.add(dimension: "custom_dim", value: "custom_val")
		XCTAssertEqual(event.dimensions["custom_dim"], "custom_val")
	}

	func testAddDimensionWithEmptyStringKeyDoesNothing() {
		let event = AppEvent("event")
			.add(dimension: "", value: "value")
		XCTAssertTrue(event.dimensions.isEmpty)
	}

	func testAddDimensionWithEmptyValueRemovesDimension() {
		let event = AppEvent("event")
			.add(dimension: "key", value: "val")
			.add(dimension: "key", value: "")
		XCTAssertNil(event.dimensions["key"])
	}

	func testRemoveDimensionWithEnum() {
		let event = AppEvent("event")
			.add(dimension: JustTrackSDK.Dimension.jtAction, value: "click")
			.remove(dimension: JustTrackSDK.Dimension.jtAction)
		XCTAssertNil(event.dimensions[JustTrackSDK.Dimension.jtAction.rawValue])
	}

	func testRemoveDimensionWithString() {
		let event = AppEvent("event")
			.add(dimension: "key", value: "val")
			.remove(dimension: "key")
		XCTAssertNil(event.dimensions["key"])
	}

	func testSetValueWithUnit() {
		let event = AppEvent("event")
			.set(value: 100.0, unit: .count)
		XCTAssertEqual(event.value, 100.0)
		XCTAssertEqual(event.unit, .count)
		XCTAssertNil(event.currency)
	}

	func testSetValueNilDoesNothing() {
		let event = AppEvent("event")
			.set(value: nil, unit: .count)
		XCTAssertEqual(event.value, 0.0)
		XCTAssertNil(event.unit)
	}

	func testSetMoney() {
		let money = Money(value: 5.0, currency: "GBP")
		let event = AppEvent("event")
			.set(money: money)
		XCTAssertEqual(event.value, 5.0)
		XCTAssertEqual(event.currency, "GBP")
		XCTAssertNil(event.unit)
	}

	func testSetCount() {
		let event = AppEvent("event").set(count: 3.0)
		XCTAssertEqual(event.value, 3.0)
		XCTAssertEqual(event.unit, .count)
	}

	func testSetSeconds() {
		let event = AppEvent("event").set(seconds: 120.0)
		XCTAssertEqual(event.value, 120.0)
		XCTAssertEqual(event.unit, .seconds)
	}

	func testSetMilliseconds() {
		let event = AppEvent("event").set(milliseconds: 500.0)
		XCTAssertEqual(event.value, 500.0)
		XCTAssertEqual(event.unit, .milliseconds)
	}

	func testValidateValidEvent() {
		let event = AppEvent("valid_event")
			.add(dimension: "jt_action", value: "click")
			.set(count: 1.0)
		XCTAssertNoThrow(try event.validate())
	}

	func testValidateEmptyNameThrows() {
		let event = AppEvent("")
		XCTAssertThrowsError(try event.validate())
	}

	func testValidateInvalidNameThrows() {
		// Name with characters outside ISO 8859-1 boundary (control chars)
		let event = AppEvent(String(Character(Unicode.Scalar(0x01))))
		XCTAssertThrowsError(try event.validate())
	}

	func testValidateInvalidDimensionNameThrows() {
		let event = AppEvent(name: "event", dimensions: ["INVALID": "value"])
		XCTAssertThrowsError(try event.validate())
	}

	func testValidateTooManyDimensionsThrows() {
		var dims: Dimensions = [:]
		for i in 0...10 {
			dims["dim_\(i)"] = "val"
		}
		let event = AppEvent(name: "event", dimensions: dims)
		XCTAssertThrowsError(try event.validate())
	}

	func testValidateNonFiniteValueThrows() {
		let event = AppEvent(name: "event", value: Double.infinity, unit: .count)
		XCTAssertThrowsError(try event.validate())
	}

	func testValidateNanValueThrows() {
		let event = AppEvent(name: "event", value: Double.nan, unit: .count)
		XCTAssertThrowsError(try event.validate())
	}

	func testValidateWithValidCurrency() {
		let event = AppEvent(name: "purchase", money: Money(value: 9.99, currency: "USD"))
		XCTAssertNoThrow(try event.validate())
	}

	func testValidateWithInvalidCurrencyThrows() {
		let event = AppEvent(name: "purchase", money: Money(value: 9.99, currency: "usd"))
		XCTAssertThrowsError(try event.validate())
	}

	func testGetDimensions() {
		let event = AppEvent("event")
			.add(dimension: "key", value: "val")
		XCTAssertEqual(event.getDimensions(), ["key": "val"])
	}

	func testInternalAddDimensionWithNilValueDoesNothing() {
		let event = AppEvent("event")
		let result = event.add(dimension: .jtAction, value: nil as String?)
		XCTAssertTrue(result.dimensions.isEmpty)
	}

	func testInternalSetMoneyNilDoesNothing() {
		let event = AppEvent("event")
		let result = event.set(money: nil as Money?)
		XCTAssertEqual(result.value, 0.0)
		XCTAssertNil(result.currency)
	}

	func testBuild() {
		let event = AppEvent("test_event")
			.add(dimension: "key", value: "val")
			.set(count: 5.0)
		let publishable = event.build(sessionId: "sess-id")
		XCTAssertEqual(publishable.name, "test_event")
		XCTAssertEqual(publishable.sessionId, "sess-id")
		XCTAssertEqual(publishable.value, 5.0)
		XCTAssertEqual(publishable.unit, .count)
	}

	func testBuildUsesEventSessionIdIfSet() {
		let event = AppEvent(
			name: "test_event",
			sessionId: "event-session",
			dimensions: [:],
			value: 0,
			unit: nil,
			currency: nil,
			happenedAt: nil
		)
		let publishable = event.build(sessionId: "fallback-session")
		XCTAssertEqual(publishable.sessionId, "event-session")
	}

	func testValidateInvalidDimensionValueThrows() {
		// Value containing control char in non-jtToken dimension
		let controlChar = String(Character(Unicode.Scalar(0x01)))
		let event = AppEvent(name: "event", dimensions: ["jt_action": controlChar])
		XCTAssertThrowsError(try event.validate())
	}

	func testInternalAddDimensionWithNonNilOptionalValue() {
		let event = AppEvent("event")
		let result = event.add(dimension: .jtAction, value: "click" as String?)
		XCTAssertEqual(result.dimensions[JustTrackSDK.Dimension.jtAction.rawValue], "click")
	}

	func testInternalSetMoneyWithNonNilOptionalValue() {
		let event = AppEvent("event")
		let money = Money(value: 9.99, currency: "USD")
		let result = event.set(money: money as Money?)
		XCTAssertEqual(result.value, 9.99)
		XCTAssertEqual(result.currency, "USD")
		XCTAssertNil(result.unit)
	}
}
