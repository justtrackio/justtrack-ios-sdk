import Foundation
import XCTest

@testable import JustTrackSDK

final class GlobalDimensionsStoreTests: XCTestCase {
	private var userDefaults: UserDefaults!
	private var store: GlobalDimensionsStore!

	override func setUp() {
		super.setUp()
		userDefaults = UserDefaults(suiteName: "GlobalDimensionsStoreTests")!
		userDefaults.removePersistentDomain(forName: "GlobalDimensionsStoreTests")
		store = GlobalDimensionsStore(userDefaults: userDefaults)
	}

	override func tearDown() {
		userDefaults.removePersistentDomain(forName: "GlobalDimensionsStoreTests")
		super.tearDown()
	}

	func testSetAndGetDimension() {
		store.set(dimension: .jtGlobal0, value: "warrior")

		let all = store.getAll()
		XCTAssertEqual(all["jt_global_0"], "warrior")
	}

	func testSetMultipleDimensions() {
		store.set(dimension: .jtGlobal0, value: "warrior")
		store.set(dimension: .jtGlobal1, value: "experiment_a")
		store.set(dimension: .jtGlobal2, value: "level_5")

		let all = store.getAll()
		XCTAssertEqual(all.count, 3)
		XCTAssertEqual(all["jt_global_0"], "warrior")
		XCTAssertEqual(all["jt_global_1"], "experiment_a")
		XCTAssertEqual(all["jt_global_2"], "level_5")
	}

	func testClearDimensionWithNil() {
		store.set(dimension: .jtGlobal0, value: "warrior")
		XCTAssertEqual(store.getAll()["jt_global_0"], "warrior")

		store.set(dimension: .jtGlobal0, value: nil)
		XCTAssertNil(store.getAll()["jt_global_0"])
	}

	func testUpdateDimension() {
		store.set(dimension: .jtGlobal1, value: "old_value")
		store.set(dimension: .jtGlobal1, value: "new_value")

		let all = store.getAll()
		XCTAssertEqual(all["jt_global_1"], "new_value")
	}

	func testPersistenceAcrossInstances() {
		store.set(dimension: .jtGlobal0, value: "persisted")
		store.set(dimension: .jtGlobal2, value: "also_persisted")

		// Create a new store instance with the same UserDefaults
		let newStore = GlobalDimensionsStore(userDefaults: userDefaults)
		let all = newStore.getAll()
		XCTAssertEqual(all["jt_global_0"], "persisted")
		XCTAssertEqual(all["jt_global_2"], "also_persisted")
	}

	func testGetAllReturnsEmptyWhenNothingSet() {
		let all = store.getAll()
		XCTAssertTrue(all.isEmpty)
	}

	func testSetReturnsTrueForValidValue() {
		XCTAssertTrue(store.set(dimension: .jtGlobal0, value: "valid_value"))
		XCTAssertEqual(store.getAll()["jt_global_0"], "valid_value")
	}

	func testSetReturnsTrueWhenClearingWithNil() {
		store.set(dimension: .jtGlobal0, value: "warrior")
		XCTAssertTrue(store.set(dimension: .jtGlobal0, value: nil))
		XCTAssertNil(store.getAll()["jt_global_0"])
	}

	func testSetRejectsTooLongValue() {
		let tooLong = String(repeating: "a", count: 4096)
		XCTAssertFalse(store.set(dimension: .jtGlobal0, value: tooLong))
		XCTAssertNil(store.getAll()["jt_global_0"])
	}

	func testSetAcceptsValueJustUnderMaxLength() {
		let maxValid = String(repeating: "a", count: 4095)
		XCTAssertTrue(store.set(dimension: .jtGlobal0, value: maxValid))
		XCTAssertEqual(store.getAll()["jt_global_0"], maxValid)
	}

	func testSetRejectsNonIso88591Value() {
		XCTAssertFalse(store.set(dimension: .jtGlobal1, value: "invalid \u{1F3AE}"))
		XCTAssertNil(store.getAll()["jt_global_1"])
	}

	func testSetRejectsControlCharacterValue() {
		XCTAssertFalse(store.set(dimension: .jtGlobal2, value: "bad\u{07}value"))
		XCTAssertNil(store.getAll()["jt_global_2"])
	}

	func testRejectedValueDoesNotOverwriteExistingValue() {
		store.set(dimension: .jtGlobal0, value: "valid")
		let tooLong = String(repeating: "a", count: 4096)
		XCTAssertFalse(store.set(dimension: .jtGlobal0, value: tooLong))
		XCTAssertEqual(store.getAll()["jt_global_0"], "valid")
	}

	func testThreadSafety() {
		let expectation = XCTestExpectation(description: "Concurrent access completes without crash")
		let iterations = 100
		let group = DispatchGroup()

		for i in 0..<iterations {
			group.enter()
			DispatchQueue.global().async { [self] in
				let dimensions: [JustTrackSDK.Dimension] = [.jtGlobal0, .jtGlobal1, .jtGlobal2]
				let dimension = dimensions[i % 3]
				self.store.set(dimension: dimension, value: "value_\(i)")
				_ = self.store.getAll()
				group.leave()
			}
		}

		group.notify(queue: .main) {
			// If we get here without a crash, thread safety is working
			let all = self.store.getAll()
			XCTAssertTrue(all.count <= 3)
			expectation.fulfill()
		}

		wait(for: [expectation], timeout: 10)
	}
}
