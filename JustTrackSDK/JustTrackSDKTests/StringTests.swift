import CommonCrypto
import Foundation
import XCTest

@testable import JustTrackSDK

final class StringTests: XCTestCase {
	// MARK: - isASCII

	func testIsASCIIReturnsTrueForPureASCII() {
		XCTAssertTrue("Hello, World!".isASCII)
	}

	func testIsASCIIReturnsTrueForEmptyString() {
		XCTAssertTrue("".isASCII)
	}

	func testIsASCIIReturnsFalseForNonASCII() {
		XCTAssertFalse("Héllo".isASCII)
	}

	func testIsASCIIReturnsFalseForEmoji() {
		XCTAssertFalse("Hello 🎉".isASCII)
	}

	// MARK: - sha256

	func testSha256ReturnsCorrectLengthForNonEmptyString() {
		let result = "hello".sha256()
		XCTAssertEqual(result.count, 32, "SHA-256 digest must be 32 bytes")
	}

	func testSha256KnownValue() {
		// Compute expected via CommonCrypto directly so test is runtime-consistent
		var result = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
		let input = Array("abc".utf8)
		_ = input.withUnsafeBytes { CC_SHA256($0.baseAddress, CC_LONG($0.count), &result) }
		XCTAssertEqual("abc".sha256(), result)
	}

	func testSha256IsDeterministic() {
		XCTAssertEqual("justtrack".sha256(), "justtrack".sha256())
	}

	func testSha256DifferentInputsProduceDifferentHashes() {
		XCTAssertNotEqual("foo".sha256(), "bar".sha256())
	}

	func testSha256EmptyStringReturns32Bytes() {
		XCTAssertEqual("".sha256().count, 32)
	}

	// MARK: - sha256Legacy (CommonCrypto fallback used on iOS < 13)

	func testSha256LegacyReturns32Bytes() {
		XCTAssertEqual("hello".sha256Legacy().count, 32)
	}

	func testSha256LegacyMatchesCommonCryptoOutput() {
		var expected = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
		let input = Array("abc".utf8)
		_ = input.withUnsafeBytes { CC_SHA256($0.baseAddress, CC_LONG($0.count), &expected) }
		XCTAssertEqual("abc".sha256Legacy(), expected)
	}

	func testSha256LegacyMatchesSha256OnIOS13Plus() {
		// On the iOS 13+ test runtime, both implementations must agree.
		XCTAssertEqual("justtrack".sha256(), "justtrack".sha256Legacy())
		XCTAssertEqual("".sha256(), "".sha256Legacy())
		XCTAssertEqual("The quick brown fox jumps over the lazy dog".sha256(), "The quick brown fox jumps over the lazy dog".sha256Legacy())
	}

	func testSha256LegacyIsDeterministic() {
		XCTAssertEqual("justtrack".sha256Legacy(), "justtrack".sha256Legacy())
	}

	func testSha256LegacyDifferentInputsProduceDifferentHashes() {
		XCTAssertNotEqual("foo".sha256Legacy(), "bar".sha256Legacy())
	}

	// MARK: - containsSDK

	func testContainsSDKReturnsFalseForEmptyString() {
		XCTAssertFalse("".containsSDK)
	}

	func testContainsSDKReturnsFalseWhenSDKOnlyInFirstTwoLines() {
		// JustTrackSDK appears only in first two lines which are dropped
		let trace = "0 JustTrackSDK signalHandler + 12\n1 JustTrackSDK crashReporter + 4\n2 libsystem_platform.dylib + 8\n3 MyApp myFunction + 0"
		XCTAssertFalse(trace.containsSDK)
	}

	func testContainsSDKReturnsTrueWhenSDKAppearsAfterFirstTwoLines() {
		let trace = "0 SomeFramework foo + 0\n1 SomeFramework bar + 0\n2 JustTrackSDK internalMethod + 0\n3 MyApp main + 0"
		XCTAssertTrue(trace.containsSDK)
	}

	func testContainsSDKReturnsFalseWhenSDKNeverAppears() {
		let trace = "0 MyApp funcA + 0\n1 MyApp funcB + 0\n2 MyApp funcC + 0"
		XCTAssertFalse(trace.containsSDK)
	}

	func testContainsSDKReturnsFalseForOnlyOneLineWithSDK() {
		// Only 1 line total — dropFirst(2) leaves nothing
		let trace = "0 JustTrackSDK signalHandler + 12"
		XCTAssertFalse(trace.containsSDK)
	}

	func testContainsSDKReturnsFalseForTwoLinesWithSDK() {
		let trace = "0 JustTrackSDK foo + 0\n1 JustTrackSDK bar + 0"
		XCTAssertFalse(trace.containsSDK)
	}

	// MARK: - matchesRegexPattern

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

	func testMatchesRegexPatternReturnsFalseForInvalidPattern() {
		// Unbalanced parenthesis triggers NSRegularExpression init failure,
		// exercising the `guard let regex = try? ...` failure branch.
		XCTAssertFalse("anything".matchesRegexPattern(pattern: "("))
		XCTAssertFalse("anything".matchesRegexPattern(pattern: "[unclosed"))
		XCTAssertFalse("anything".matchesRegexPattern(pattern: "*invalid"))
	}

	// MARK: - sdkPackageName

	func testSdkPackageNameConstant() {
		XCTAssertEqual(String.sdkPackageName, "JustTrackSDK")
	}
}
