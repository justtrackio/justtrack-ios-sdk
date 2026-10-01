import Foundation
import XCTest

@testable import JustTrackSDK

final class JustTrackErrorTests: XCTestCase {
	func testBadApiTokenMessage() {
		let error = JustTrackError.badApiToken("invalid-token")
		XCTAssertTrue(error.message.contains("invalid-token"))
		XCTAssertTrue(error.message.contains("invalid"))
	}

	func testCustomMessage() {
		let error = JustTrackError.custom("something went wrong")
		XCTAssertTrue(error.message.contains("something went wrong"))
	}

	func testMissingBundleIdentifierMessage() {
		let error = JustTrackError.missingBundleIdentifier
		XCTAssertTrue(error.message.contains("bundle identifier"))
	}

	func testNotOnMainThreadMessage() {
		let error = JustTrackError.notOnMainThread
		XCTAssertTrue(error.message.contains("main thread"))
	}

	func testStoppedMessage() {
		let error = JustTrackError.stopped
		XCTAssertTrue(error.message.contains("not running"))
	}

	func testDescriptionMatchesMessage() {
		let cases: [JustTrackError] = [
			.badApiToken("token"),
			.custom("msg"),
			.missingBundleIdentifier,
			.notOnMainThread,
			.stopped,
		]
		for error in cases {
			XCTAssertEqual(error.description, error.message)
		}
	}

	func testErrorDescriptionIsNotNil() {
		let cases: [JustTrackError] = [
			.badApiToken("token"),
			.custom("msg"),
			.missingBundleIdentifier,
			.notOnMainThread,
			.stopped,
		]
		for error in cases {
			XCTAssertNotNil(error.errorDescription)
		}
	}

	func testCommentForAllCases() {
		XCTAssertEqual(JustTrackError.badApiToken("t").comment, "Invalid Credentials")
		XCTAssertEqual(JustTrackError.custom("msg").comment, "msg")
		XCTAssertEqual(JustTrackError.missingBundleIdentifier.comment, "Wrong App Setup")
		XCTAssertEqual(JustTrackError.notOnMainThread.comment, "Wrong App Implementation")
		XCTAssertTrue(JustTrackError.stopped.comment.contains("start()"))
	}

	func testEquatable() {
		XCTAssertEqual(JustTrackError.stopped, JustTrackError.stopped)
		XCTAssertNotEqual(JustTrackError.stopped, JustTrackError.notOnMainThread)
		XCTAssertEqual(JustTrackError.badApiToken("a"), JustTrackError.badApiToken("a"))
		XCTAssertNotEqual(JustTrackError.badApiToken("a"), JustTrackError.badApiToken("b"))
		XCTAssertEqual(JustTrackError.custom("x"), JustTrackError.custom("x"))
	}
}
