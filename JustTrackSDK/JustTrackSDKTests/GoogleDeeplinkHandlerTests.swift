import Foundation
import XCTest

@testable import JustTrackSDK

final class GoogleDeeplinkHandlerTests: XCTestCase {

	// MARK: - gbraid extraction

	func testExtractsGbraidFromURL() {
		let gbraid = GoogleDeeplinkHandler.handle(url: URL(string: "https://example.com/open?gbraid=abc123&other=value")!)
		XCTAssertEqual(gbraid, "abc123")
	}

	func testGbraidIsNilWhenNotPresent() {
		let gbraid = GoogleDeeplinkHandler.handle(url: URL(string: "https://example.com/open?other=value&foo=bar")!)
		XCTAssertNil(gbraid)
	}

	func testGbraidIsNilWhenEmpty() {
		let gbraid = GoogleDeeplinkHandler.handle(url: URL(string: "https://example.com/open?gbraid=&other=value")!)
		XCTAssertNil(gbraid)
	}

	func testGbraidIsNilWhenNoQueryParameters() {
		let gbraid = GoogleDeeplinkHandler.handle(url: URL(string: "https://example.com/open")!)
		XCTAssertNil(gbraid)
	}

	func testExtractsGbraidFromCustomSchemeURL() {
		let gbraid = GoogleDeeplinkHandler.handle(url: URL(string: "myapp://deeplink?gbraid=xyz789&campaign=test")!)
		XCTAssertEqual(gbraid, "xyz789")
	}

	func testExtractsFirstGbraidWhenMultiplePresent() {
		let gbraid = GoogleDeeplinkHandler.handle(url: URL(string: "https://example.com/open?gbraid=first&gbraid=second")!)
		XCTAssertEqual(gbraid, "first")
	}

	func testExtractsGbraidWithEncodedValue() {
		let gbraid = GoogleDeeplinkHandler.handle(url: URL(string: "https://example.com/open?gbraid=abc%20123")!)
		XCTAssertEqual(gbraid, "abc 123")
	}

	func testExtractsGbraidWhenOnlyParam() {
		let gbraid = GoogleDeeplinkHandler.handle(url: URL(string: "https://example.com/open?gbraid=singleValue")!)
		XCTAssertEqual(gbraid, "singleValue")
	}

	func testExtractsGbraidFromURLWithFragment() {
		let gbraid = GoogleDeeplinkHandler.handle(url: URL(string: "https://example.com/open?gbraid=test123#section")!)
		XCTAssertEqual(gbraid, "test123")
	}

	func testGbraidIsCaseSensitive() {
		let gbraid = GoogleDeeplinkHandler.handle(url: URL(string: "https://example.com/open?GBRAID=uppercase&Gbraid=mixed")!)
		XCTAssertNil(gbraid)
	}
}
