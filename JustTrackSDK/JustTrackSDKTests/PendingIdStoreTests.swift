import XCTest

@testable import JustTrackSDK

final class PendingIdStoreTests: XCTestCase {
	// Use a unique key per test class to avoid cross-test UserDefaults pollution.
	private let key = "io.justtrack.test.pendingIdStore.\(UUID().uuidString)"

	private func makeStore(version: Int = 1) -> PendingIdStore {
		PendingIdStore(key: key, version: version)
	}

	override func tearDown() {
		super.tearDown()
		UserDefaults.standard.removeObject(forKey: key)
	}

	// MARK: - storeNewId

	func testStoreNewIdReturnsTrueWhenNoPreviousData() {
		let store = makeStore()
		let result = store.storeNewId(installId: nil, newId: "user-1")
		XCTAssertTrue(result)
	}

	func testStoreNewIdReturnsTrueWhenInstallIdIsNil() {
		let store = makeStore()
		// Even when already stored with the same id, nil installId always stores
		store.storeNewId(installId: nil, newId: "user-1")
		let result = store.storeNewId(installId: nil, newId: "user-1")
		XCTAssertTrue(result)
	}

	func testStoreNewIdReturnsFalseWhenAlreadyStoredWithSameInstallId() {
		let store = makeStore()
		let installId = StringID()
		// Store and confirm at backend so storedId == newId
		store.storeNewId(installId: installId, newId: "user-1")
		store.setStoredAtBackend(installId: installId, storedId: "user-1")
		// Now attempting to store same id with same installId should return false
		let result = store.storeNewId(installId: installId, newId: "user-1")
		XCTAssertFalse(result)
	}

	func testStoreNewIdReturnsTrueWhenIdChanges() {
		let store = makeStore()
		let installId = StringID()
		store.storeNewId(installId: installId, newId: "user-1")
		store.setStoredAtBackend(installId: installId, storedId: "user-1")
		// New id — must return true
		let result = store.storeNewId(installId: installId, newId: "user-2")
		XCTAssertTrue(result)
	}

	// MARK: - getPendingId

	func testGetPendingIdReturnsNilWhenNothingStored() {
		let store = makeStore()
		XCTAssertNil(store.getPendingId())
	}

	func testGetPendingIdReturnsPendingIdWhenNotYetConfirmed() {
		let store = makeStore()
		store.storeNewId(installId: nil, newId: "user-abc")
		XCTAssertEqual(store.getPendingId(), "user-abc")
	}

	func testGetPendingIdReturnsNilWhenPendingEqualsStored() {
		let store = makeStore()
		let installId = StringID()
		store.storeNewId(installId: installId, newId: "user-1")
		store.setStoredAtBackend(installId: installId, storedId: "user-1")
		// pendingId == storedId → getPendingId returns nil
		XCTAssertNil(store.getPendingId())
	}

	func testGetPendingIdReturnsNewIdWhenDifferentFromStored() {
		let store = makeStore()
		let installId = StringID()
		// Confirm user-1 at backend, then pend user-2
		store.storeNewId(installId: installId, newId: "user-1")
		store.setStoredAtBackend(installId: installId, storedId: "user-1")
		store.storeNewId(installId: installId, newId: "user-2")
		XCTAssertEqual(store.getPendingId(), "user-2")
	}

	// MARK: - setStoredAtBackend

	func testSetStoredAtBackendClearsGetPendingId() {
		let store = makeStore()
		let installId = StringID()
		store.storeNewId(installId: installId, newId: "user-x")
		XCTAssertEqual(store.getPendingId(), "user-x")
		store.setStoredAtBackend(installId: installId, storedId: "user-x")
		XCTAssertNil(store.getPendingId())
	}

	// MARK: - getPendingWithNewInstallId

	func testGetPendingWithNewInstallIdReturnsNilWhenNothingStored() {
		let store = makeStore()
		XCTAssertNil(store.getPendingWithNewInstallId(installId: StringID()))
	}

	func testGetPendingWithNewInstallIdReturnsNilWhenInstallIdMatches() {
		let store = makeStore()
		let installId = StringID()
		store.storeNewId(installId: installId, newId: "user-1")
		// Same installId → no migration needed
		XCTAssertNil(store.getPendingWithNewInstallId(installId: installId))
	}

	func testGetPendingWithNewInstallIdReturnsPendingIdAndClearsInstallId() {
		let store = makeStore()
		let oldInstallId = StringID()
		store.storeNewId(installId: oldInstallId, newId: "user-1")

		let newInstallId = StringID()
		let result = store.getPendingWithNewInstallId(installId: newInstallId)
		XCTAssertEqual(result, "user-1")
		// After clearing, installId is nil; a different installId will still trigger migration
		// The second call with yet another new installId returns again (pendingId preserved)
		let anotherInstallId = StringID()
		let result2 = store.getPendingWithNewInstallId(installId: anotherInstallId)
		XCTAssertEqual(result2, "user-1")
	}

	func testGetPendingWithNewInstallIdFallsBackToStoredId() {
		let store = makeStore()
		let oldInstallId = StringID()
		// Confirm at backend (sets storedId), but don't write a new pendingId
		store.storeNewId(installId: oldInstallId, newId: "user-1")
		store.setStoredAtBackend(installId: oldInstallId, storedId: "user-1")

		let newInstallId = StringID()
		// pendingId is nil but storedId is "user-1"; ?? falls back to storedId
		let result = store.getPendingWithNewInstallId(installId: newInstallId)
		XCTAssertEqual(result, "user-1")
	}

	// MARK: - Version mismatch resets state

	func testVersionMismatchResetsState() {
		// Write data with version 1
		let storeV1 = makeStore(version: 1)
		storeV1.storeNewId(installId: nil, newId: "user-old")
		XCTAssertEqual(storeV1.getPendingId(), "user-old")

		// Re-open with version 2 — should reset
		let storeV2 = makeStore(version: 2)
		XCTAssertNil(storeV2.getPendingId())
	}

	// MARK: - Persistence across instances

	func testDataPersistsAcrossInstances() {
		let installId = StringID()
		let store1 = makeStore()
		store1.storeNewId(installId: installId, newId: "persistent-user")

		let store2 = makeStore()
		XCTAssertEqual(store2.getPendingId(), "persistent-user")
	}
}
