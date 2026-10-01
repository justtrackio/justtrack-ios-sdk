import Foundation
import XCTest

@testable import JustTrackSDK

final class MoneyTests: XCTestCase {
	func testInit() {
		let money = Money(value: 9.99, currency: "USD")
		XCTAssertEqual(money.value, 9.99)
		XCTAssertEqual(money.currency, "USD")
	}

	func testValidateValid() {
		let money = Money(value: 0.0, currency: "EUR")
		XCTAssertNoThrow(try money.validate())
	}

	func testValidateInfinityThrows() {
		let money = Money(value: .infinity, currency: "USD")
		XCTAssertThrowsError(try money.validate())
	}

	func testValidateNanThrows() {
		let money = Money(value: .nan, currency: "USD")
		XCTAssertThrowsError(try money.validate())
	}

	func testValidateLowercaseCurrencyThrows() {
		let money = Money(value: 1.0, currency: "usd")
		XCTAssertThrowsError(try money.validate())
	}

	func testValidateTwoLetterCurrencyThrows() {
		let money = Money(value: 1.0, currency: "US")
		XCTAssertThrowsError(try money.validate())
	}

	func testValidateFourLetterCurrencyThrows() {
		let money = Money(value: 1.0, currency: "USDD")
		XCTAssertThrowsError(try money.validate())
	}

	func testValidateMixedCaseCurrencyThrows() {
		let money = Money(value: 1.0, currency: "Usd")
		XCTAssertThrowsError(try money.validate())
	}
}
