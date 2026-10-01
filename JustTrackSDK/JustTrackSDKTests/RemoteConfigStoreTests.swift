import Foundation
import XCTest

@testable import JustTrackSDK

final class RemoteConfigStoreTests: XCTestCase {
	private var userDefaults: UserDefaults!
	private var store: RemoteConfigStore!

	override func setUpWithError() throws {
		userDefaults = UserDefaults(suiteName: "io.justtrack.test.remoteconfig")!
		userDefaults.dictionaryRepresentation().keys.forEach { key in
			userDefaults.removeObject(forKey: key)
		}
		store = RemoteConfigStore(userDefaults: userDefaults)
	}

	override func tearDownWithError() throws {
		store.clearAssignments()
		userDefaults = nil
		store = nil
	}

	// MARK: storeAssignments

	func testStoreAssignmentsStoresInUserDefaults() {
		let assignments = [DTOAssignment.fixture()]
		let fetchedAt = Date()

		store.storeAssignments(assignments, fetchedAt: fetchedAt)

		let dict = userDefaults.dictionary(forKey: RemoteConfigStore.assignmentsKey)
		XCTAssertNotNil(dict)
		XCTAssertEqual(dict?["version"] as? Int, 1)
		XCTAssertNotNil(dict?["fetchedAt"])
		XCTAssertNotNil(dict?["assignments"])
	}

	func testStoreAssignmentsOverwritesPreviousData() {
		let assignment1 = DTOAssignment.fixture(experimentId: "exp-1")
		let assignment2 = DTOAssignment.fixture(experimentId: "exp-2")

		store.storeAssignments([assignment1], fetchedAt: Date())
		store.storeAssignments([assignment2], fetchedAt: Date())

		let stored = store.getStoredAssignments()
		XCTAssertEqual(stored?.assignments.count, 1)
		XCTAssertEqual(stored?.assignments.first?.experimentId, "exp-2")
	}

	// MARK: getStoredAssignments

	func testGetStoredAssignmentsReturnsNilWhenEmpty() {
		let stored = store.getStoredAssignments()
		XCTAssertNil(stored)
	}

	func testGetStoredAssignmentsReturnsStoredData() {
		let assignments = [
			DTOAssignment.fixture(experimentId: "exp-1", configKey: "key1", configValue: "value1"),
			DTOAssignment.fixture(experimentId: "exp-2", configKey: "key2", configValue: "value2"),
		]
		let fetchedAt = Date()

		store.storeAssignments(assignments, fetchedAt: fetchedAt)
		let stored = store.getStoredAssignments()

		XCTAssertNotNil(stored)
		XCTAssertEqual(stored?.assignments.count, 2)
		XCTAssertEqual(stored?.assignments[0].experimentId, "exp-1")
		XCTAssertEqual(stored?.assignments[0].configKey, "key1")
		XCTAssertEqual(stored?.assignments[0].configValue, "value1")
		XCTAssertEqual(stored?.assignments[1].experimentId, "exp-2")
	}

	func testGetStoredAssignmentsReturnsNilForInvalidVersion() {
		var dict = [String: Any]()
		dict["version"] = 999
		dict["fetchedAt"] = formatDateSeconds(Date())
		dict["assignments"] = try? JSONEncoder().encode([DTOAssignment.fixture()])
		userDefaults.setValue(dict, forKey: RemoteConfigStore.assignmentsKey)

		let stored = store.getStoredAssignments()

		XCTAssertNil(stored)
	}

	func testGetStoredAssignmentsReturnsNilForMissingFetchedAt() {
		var dict = [String: Any]()
		dict["version"] = 1
		dict["assignments"] = try? JSONEncoder().encode([DTOAssignment.fixture()])
		userDefaults.setValue(dict, forKey: RemoteConfigStore.assignmentsKey)

		let stored = store.getStoredAssignments()

		XCTAssertNil(stored)
	}

	// MARK: shouldFetch

	func testShouldFetchReturnsTrueWhenNoStoredData() {
		let shouldFetch = store.shouldFetch(minFetchIntervalInSec: 3600)
		XCTAssertTrue(shouldFetch)
	}

	func testShouldFetchReturnsFalseWhenWithinInterval() {
		let assignments = [DTOAssignment.fixture()]
		store.storeAssignments(assignments, fetchedAt: Date())

		let shouldFetch = store.shouldFetch(minFetchIntervalInSec: 3600)

		XCTAssertFalse(shouldFetch)
	}

	func testShouldFetchReturnsTrueWhenIntervalElapsed() {
		let assignments = [DTOAssignment.fixture()]
		let pastDate = Date().addingTimeInterval(-3601)
		store.storeAssignments(assignments, fetchedAt: pastDate)

		let shouldFetch = store.shouldFetch(minFetchIntervalInSec: 3600)

		XCTAssertTrue(shouldFetch)
	}

	func testShouldFetchReturnsTrueWhenIntervalIsZero() {
		let assignments = [DTOAssignment.fixture()]
		store.storeAssignments(assignments, fetchedAt: Date())

		let shouldFetch = store.shouldFetch(minFetchIntervalInSec: 0)

		XCTAssertTrue(shouldFetch)
	}

	// MARK: clearAssignments

	func testClearAssignmentsRemovesData() {
		let assignments = [DTOAssignment.fixture()]
		store.storeAssignments(assignments, fetchedAt: Date())

		store.clearAssignments()

		let stored = store.getStoredAssignments()
		XCTAssertNil(stored)
	}

	// MARK: getStoredAssignments — additional failure branches

	func testGetStoredAssignmentsReturnsNilForMissingVersionKey() {
		// Write a dict that has fetchedAt and assignments but no "version" key
		var dict = [String: Any]()
		dict["fetchedAt"] = formatDateSeconds(Date())
		dict["assignments"] = try? JSONEncoder().encode([DTOAssignment.fixture()])
		userDefaults.setValue(dict, forKey: RemoteConfigStore.assignmentsKey)

		XCTAssertNil(store.getStoredAssignments())
	}

	func testGetStoredAssignmentsReturnsNilForInvalidFetchedAtDate() {
		var dict = [String: Any]()
		dict["version"] = 1
		dict["fetchedAt"] = "not-a-date"
		dict["assignments"] = try? JSONEncoder().encode([DTOAssignment.fixture()])
		userDefaults.setValue(dict, forKey: RemoteConfigStore.assignmentsKey)

		XCTAssertNil(store.getStoredAssignments())
	}

	func testGetStoredAssignmentsReturnsNilForCorruptAssignmentsData() {
		var dict = [String: Any]()
		dict["version"] = 1
		dict["fetchedAt"] = formatDateSeconds(Date())
		dict["assignments"] = Data([0xDE, 0xAD, 0xBE, 0xEF])  // invalid JSON
		userDefaults.setValue(dict, forKey: RemoteConfigStore.assignmentsKey)

		XCTAssertNil(store.getStoredAssignments())
	}

	// MARK: storeAssignments — empty array

	func testStoreAssignmentsWithEmptyArray() {
		store.storeAssignments([], fetchedAt: Date())

		let stored = store.getStoredAssignments()
		XCTAssertNotNil(stored)
		XCTAssertEqual(stored?.assignments.count, 0)
	}

	// MARK: setRetryAfterSeconds

	func testSetRetryAfterSecondsCanBeCleared() {
		store.setRetryAfterSeconds(60)
		XCTAssertEqual(store.retryAfterSeconds, 60)

		store.setRetryAfterSeconds(nil)
		XCTAssertNil(store.retryAfterSeconds)
	}

	// MARK: shouldFetch — retryAfterSeconds interaction

	func testShouldFetchUsesRetryAfterSecondsWhenSmallerThanInterval() {
		// Fetch was 30 seconds ago; min interval is 3600; retryAfter is 10 → should fetch
		let assignments = [DTOAssignment.fixture()]
		store.storeAssignments(assignments, fetchedAt: Date().addingTimeInterval(-30))
		store.setRetryAfterSeconds(10)

		XCTAssertTrue(store.shouldFetch(minFetchIntervalInSec: 3600))
	}

	func testShouldFetchIgnoresRetryAfterSecondsWhenLargerThanInterval() {
		// Fetch was 100 seconds ago; min interval is 60; retryAfter is 9999 → min(9999,60)=60 → 100≥60 → should fetch
		let assignments = [DTOAssignment.fixture()]
		store.storeAssignments(assignments, fetchedAt: Date().addingTimeInterval(-100))
		store.setRetryAfterSeconds(9999)

		XCTAssertTrue(store.shouldFetch(minFetchIntervalInSec: 60))
	}

	func testShouldFetchReturnsFalseWhenRetryAfterSecondsNotElapsed() {
		// Fetch was 5 seconds ago; retryAfter is 30 → 5 < 30 → should NOT fetch
		let assignments = [DTOAssignment.fixture()]
		store.storeAssignments(assignments, fetchedAt: Date().addingTimeInterval(-5))
		store.setRetryAfterSeconds(30)

		XCTAssertFalse(store.shouldFetch(minFetchIntervalInSec: 3600))
	}
}
