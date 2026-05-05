import Foundation
import XCTest

@testable import JustTrackSDK

final class StringTests: XCTestCase {
	func testMatchesRegexPattern() {
		let table: [(input: String, pattern: String, want: Bool)] = [
			("asdfasdf adsf a", "^.*$", true),
			("asdfasdf adsf a", "^.* a$", true),
			("asdfasdf adsf a", "^asd.*$", true),
			("asdfasdf adsf a", "^asdfasdf adsf a$", true),
			("asdfasdf adsf a", "^asdfasdf adsf a asdfasdf adsf a$", false),
			("asdfasdf adsf a", "^$", false),
			("asdfasdf adsf a", "^ase.*$", false),
			("asdfasdf adsf a", "^.* b$", false),
		]

		for test in table {
			XCTAssertEqual(
				test.input.matchesRegexPattern(pattern: test.pattern),
				test.want,
				"\"\(test.input)\" mismatches the \"\(test.pattern)\" pattern"
			)
		}
	}
}
