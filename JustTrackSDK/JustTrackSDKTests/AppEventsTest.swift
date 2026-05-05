import XCTest

@testable import JustTrackSDK

class UserEventTests: XCTestCase {
	func testCallAllPredefinedEvents() {
		var allEvents = UserEventNameList.allEvents
		for appEvent in UserEventList.getEventsList() {
			let name = appEvent.name
			XCTAssertTrue(allEvents.contains(name))
			allEvents.remove(at: allEvents.firstIndex(where: { $0 == name })!)
		}
		for missedEvent in allEvents {
			XCTFail("Event \(missedEvent) was not tested")
		}
		XCTAssertTrue(allEvents.isEmpty)
	}

	func testAllPredefinedEventsContainJTPrefix() {
		for appEvent in UserEventList.getEventsList() {
			let name = appEvent.name
			XCTAssertTrue(name.hasPrefix("jt_"))

			for (dimension, _) in appEvent.getDimensions() {
				XCTAssertTrue(dimension.hasPrefix("jt_"))
			}
		}
	}

	func testIgnoreEmptyDimensionName() {
		let customEvent = AppEvent("custom")
		for i in 0..<10 {
			_ = customEvent.add(dimension: "dim_\(i)", value: "value_\(i)")
		}
		try! customEvent.validate()

		_ = customEvent.add(dimension: "", value: "ignore")
		try! customEvent.validate()

		_ = customEvent.add(dimension: "dim_11", value: "value_11")
		do {
			try customEvent.validate()
			XCTFail("Should not be reached")
		} catch {
			let invalidFieldError = error as? InvalidFieldError
			guard let invalidFieldError else {
				XCTAssertNotNil(invalidFieldError)
				return
			}

			XCTAssertTrue(invalidFieldError.description.hasPrefix("Too many dimensions"))
		}
	}

	func testIgnoreEmptyValue() {
		let customEvent = AppEvent("custom")
		for i in 0..<10 {
			_ = customEvent.add(dimension: "dim_\(i)", value: "value_\(i)")
		}
		try! customEvent.validate()

		_ = customEvent.add(dimension: "dim_11", value: "")
		try! customEvent.validate()

		_ = customEvent.add(dimension: "dim_11", value: "value_11")
		do {
			try customEvent.validate()
			XCTFail("Should not be reached")
		} catch {
			let invalidFieldError = error as? InvalidFieldError
			guard let invalidFieldError else {
				XCTAssertNotNil(invalidFieldError)
				return
			}

			XCTAssertTrue(invalidFieldError.description.hasPrefix("Too many dimensions"))
		}
	}

	func testCustomEventLimitedToTenDimensions() {
		let customEvent = AppEvent("custom")
		for i in 0..<10 {
			_ = customEvent.add(dimension: "dim_\(i)", value: "value_\(i)")
		}
		try! customEvent.validate()

		_ = customEvent.add(dimension: "dim_11", value: "value_11")
		do {
			try customEvent.validate()
			XCTFail("Should not be reached")
		} catch {
			let invalidFieldError = error as? InvalidFieldError
			guard let invalidFieldError else {
				XCTAssertNotNil(invalidFieldError)
				return
			}

			XCTAssertTrue(invalidFieldError.description.hasPrefix("Too many dimensions"))
		}
	}

	func testDimensionsWithoutValueDelete() {
		let customEvent = AppEvent("custom")
		for i in 0...10 {
			_ = customEvent.add(dimension: "dim_\(i)", value: "value_\(i)")
		}

		do {
			try customEvent.validate()
			XCTFail("Should not be reached")
		} catch {
			let invalidFieldError = error as? InvalidFieldError
			guard let invalidFieldError else {
				XCTAssertNotNil(invalidFieldError)
				return
			}

			XCTAssertTrue(invalidFieldError.description.hasPrefix("Too many dimensions"))
		}

		_ = customEvent.add(dimension: "dim_10", value: "")
		try! customEvent.validate()
	}

	func testPredefinedEventLimitedToTenDimensions() {
		let customEvent = JtAdEvent(jtAction: "stop", jtAdNetwork: "ad_network", jtAdPlacement: "ad_placement", jtAdSdk: "sdk_name", jtAdUnit: "adUnit")
		for i in 0..<6 {
			_ = customEvent.add(dimension: "dim_\(i)", value: "value_\(i)")
		}

		do {
			try customEvent.validate()
			XCTFail("Should not be reached")
		} catch {
			let invalidFieldError = error as? InvalidFieldError
			guard let invalidFieldError else {
				XCTAssertNotNil(invalidFieldError)
				return
			}

			XCTAssertTrue(invalidFieldError.description.hasPrefix("Too many dimensions"))
		}

		_ = customEvent.remove(dimension: "dim_0")
		try! customEvent.validate()
	}
}
