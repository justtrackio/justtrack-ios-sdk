import Foundation
import XCTest

@testable import JustTrackSDK

final class GlobalDimensionsInjectionTests: XCTestCase {
	private var userDefaults: UserDefaults!
	private var store: GlobalDimensionsStore!

	override func setUp() {
		super.setUp()
		userDefaults = UserDefaults(suiteName: "GlobalDimensionsInjectionTests")!
		userDefaults.removePersistentDomain(forName: "GlobalDimensionsInjectionTests")
		store = GlobalDimensionsStore(userDefaults: userDefaults)
	}

	override func tearDown() {
		userDefaults.removePersistentDomain(forName: "GlobalDimensionsInjectionTests")
		super.tearDown()
	}

	func testGlobalDimensionsAttachedToEvent() {
		store.set(dimension: .jtGlobal0, value: "warrior")
		store.set(dimension: .jtGlobal1, value: "experiment_a")

		let event = AppEvent("test_event")
		let globalDimensions = store.getAll()
		for (key, value) in globalDimensions {
			if event.getDimensions()[key] == nil {
				_ = event.add(dimension: key, value: value)
			}
		}

		let dimensions = event.getDimensions()
		XCTAssertEqual(dimensions["jt_global_0"], "warrior")
		XCTAssertEqual(dimensions["jt_global_1"], "experiment_a")
		XCTAssertNil(dimensions["jt_global_2"])
	}

	func testEventLevelDimensionOverridesGlobal() {
		store.set(dimension: .jtGlobal0, value: "global_value")

		let event = AppEvent("test_event")
		_ = event.add(dimension: .jtGlobal0, value: "user_value")

		// Simulate injection: only add if not already set
		let globalDimensions = store.getAll()
		for (key, value) in globalDimensions {
			if event.getDimensions()[key] == nil {
				_ = event.add(dimension: key, value: value)
			}
		}

		let dimensions = event.getDimensions()
		XCTAssertEqual(dimensions["jt_global_0"], "user_value")
	}

	func testClearedGlobalDimensionNotAttached() {
		store.set(dimension: .jtGlobal0, value: "warrior")
		store.set(dimension: .jtGlobal0, value: nil)

		let event = AppEvent("test_event")
		let globalDimensions = store.getAll()
		for (key, value) in globalDimensions {
			if event.getDimensions()[key] == nil {
				_ = event.add(dimension: key, value: value)
			}
		}

		let dimensions = event.getDimensions()
		XCTAssertNil(dimensions["jt_global_0"])
	}

	func testValidationPassesWithMaxDimensionsPlusGlobals() throws {
		// Create an event with exactly 10 user-set dimensions (the max)
		let event = AppEvent("test_event")
		_ = event.add(dimension: .jtAction, value: "click")
		_ = event.add(dimension: .jtCategory, value: "category")
		_ = event.add(dimension: .jtContext, value: "context")
		_ = event.add(dimension: .jtDetail, value: "detail")
		_ = event.add(dimension: .jtItemId, value: "item_id")
		_ = event.add(dimension: .jtItemName, value: "item_name")
		_ = event.add(dimension: .jtItemType, value: "item_type")
		_ = event.add(dimension: .jtLocation, value: "location")
		_ = event.add(dimension: .jtMethod, value: "method")
		_ = event.add(dimension: .jtState, value: "state")

		// Validation should pass with exactly 10 dimensions
		try event.validate()

		// Now inject global dimensions (simulating what track() does AFTER validate())
		store.set(dimension: .jtGlobal0, value: "warrior")
		store.set(dimension: .jtGlobal1, value: "experiment_a")
		store.set(dimension: .jtGlobal2, value: "level_5")

		let globalDimensions = store.getAll()
		for (key, value) in globalDimensions {
			if event.getDimensions()[key] == nil {
				_ = event.add(dimension: key, value: value)
			}
		}

		// Event now has 13 dimensions total, which is fine because globals were added after validation
		let dimensions = event.getDimensions()
		XCTAssertEqual(dimensions.count, 13)
		XCTAssertEqual(dimensions["jt_global_0"], "warrior")
		XCTAssertEqual(dimensions["jt_global_1"], "experiment_a")
		XCTAssertEqual(dimensions["jt_global_2"], "level_5")
	}

	func testEmptyGlobalStoreDoesNotModifyEvent() {
		let event = AppEvent("test_event")
		_ = event.add(dimension: .jtAction, value: "click")

		let globalDimensions = store.getAll()
		for (key, value) in globalDimensions {
			if event.getDimensions()[key] == nil {
				_ = event.add(dimension: key, value: value)
			}
		}

		let dimensions = event.getDimensions()
		XCTAssertEqual(dimensions.count, 1)
		XCTAssertEqual(dimensions["jt_action"], "click")
	}
}
