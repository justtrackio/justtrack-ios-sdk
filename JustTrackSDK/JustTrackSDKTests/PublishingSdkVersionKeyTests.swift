import Foundation
import XCTest

@testable import JustTrackSDK

final class PublishingSdkVersionKeyTests: XCTestCase {
	func testEqualWhenSameName() {
		let v1 = VersionImpl(major: 1, minor: 0, patch: 0, name: "1.0.0")
		let v2 = VersionImpl(major: 2, minor: 0, patch: 0, name: "1.0.0")
		let key1 = PublishingSdkVersionKey(version: v1)
		let key2 = PublishingSdkVersionKey(version: v2)
		XCTAssertEqual(key1, key2)
	}

	func testNotEqualWhenDifferentName() {
		let v1 = VersionImpl(major: 1, minor: 0, patch: 0, name: "1.0.0")
		let v2 = VersionImpl(major: 1, minor: 0, patch: 0, name: "1.0.1")
		let key1 = PublishingSdkVersionKey(version: v1)
		let key2 = PublishingSdkVersionKey(version: v2)
		XCTAssertNotEqual(key1, key2)
	}

	func testHashConsistentWithEquality() {
		let v1 = VersionImpl(major: 1, minor: 0, patch: 0, name: "1.0.0")
		let v2 = VersionImpl(major: 2, minor: 0, patch: 0, name: "1.0.0")
		let key1 = PublishingSdkVersionKey(version: v1)
		let key2 = PublishingSdkVersionKey(version: v2)
		XCTAssertEqual(key1.hashValue, key2.hashValue)
	}

	func testUsableAsDictionaryKey() {
		let v1 = VersionImpl(major: 1, minor: 0, patch: 0, name: "1.0.0")
		let v2 = VersionImpl(major: 1, minor: 1, patch: 0, name: "1.1.0")
		let key1 = PublishingSdkVersionKey(version: v1)
		let key2 = PublishingSdkVersionKey(version: v2)
		var dict: [PublishingSdkVersionKey: String] = [:]
		dict[key1] = "first"
		dict[key2] = "second"
		XCTAssertEqual(dict.count, 2)
		XCTAssertEqual(dict[key1], "first")
		XCTAssertEqual(dict[key2], "second")
	}

	func testHashIntoProducesConsistentResult() {
		let v = VersionImpl(major: 1, minor: 0, patch: 0, name: "1.0.0")
		let key = PublishingSdkVersionKey(version: v)
		var hasher1 = Hasher()
		key.hash(into: &hasher1)
		let hash1 = hasher1.finalize()
		var hasher2 = Hasher()
		key.hash(into: &hasher2)
		let hash2 = hasher2.finalize()
		XCTAssertEqual(hash1, hash2)
	}
}
