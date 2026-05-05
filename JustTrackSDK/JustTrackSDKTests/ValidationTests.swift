import XCTest

@testable import JustTrackSDK

final class ValidationTests: XCTestCase {
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
}
