import XCTest

@testable import JustTrackSDK

final class SdkConfigRuleTests: XCTestCase {
	func testMatchWhenNameIsAny() {
		let name = "name_1"
		let dimensions = [
			"dimension_1": "value_1",
			"dimension_2": "value_2",
		]
		let drop = Bool.random()
		let rule = AttributionOutputSdkConfig.Rule(
			name: "^.*$",
			drop: drop,
			dimensions: [:]
		)

		XCTAssertEqual(
			[rule].match(name: name, dimensions: dimensions),
			MatchResult(drop: drop, matchedRule: true)
		)
	}

	func testMatchWhenDimensionValuesAreAny() {
		let name = "name_1"
		let dimensions = [
			"dimension_1": "value_1",
			"dimension_2": "value_2",
		]
		let drop = Bool.random()
		let rule = AttributionOutputSdkConfig.Rule(
			name: "name_1",
			drop: drop,
			dimensions: [
				"dimension_1": "^.*$",
				"dimension_2": "^.*$",
			]
		)

		XCTAssertEqual(
			[rule].match(name: name, dimensions: dimensions),
			MatchResult(drop: drop, matchedRule: true)
		)
	}

	func testMatchWhenNameAndDimensionValuesAreAny() {
		let name = "name_1"
		let dimensions = [
			"dimension_1": "value_1",
			"dimension_2": "value_2",
		]
		let drop = Bool.random()
		let rule = AttributionOutputSdkConfig.Rule(
			name: "^.*$",
			drop: drop,
			dimensions: [
				"dimension_1": "^.*$",
				"dimension_2": "^.*$",
			]
		)

		XCTAssertEqual(
			[rule].match(name: name, dimensions: dimensions),
			MatchResult(drop: drop, matchedRule: true)
		)
	}

	func testMatchWhenNameMatches() {
		let name = "name_1"
		let dimensions = [
			"dimension_1": "value_1",
			"dimension_2": "value_2",
		]
		let drop = Bool.random()
		let rule = AttributionOutputSdkConfig.Rule(
			name: "name_1",
			drop: drop,
			dimensions: [:]
		)

		XCTAssertEqual(
			[rule].match(name: name, dimensions: dimensions),
			MatchResult(drop: drop, matchedRule: true)
		)
	}

	func testMatchWhenNameAndDimensionMatch() {
		let name = "name_1"
		let dimensions = [
			"dimension_1": "value_1",
			"dimension_2": "value_2",
		]
		let drop = Bool.random()
		let rule = AttributionOutputSdkConfig.Rule(
			name: "name_1",
			drop: drop,
			dimensions: [
				"dimension_1": "value_1",
				"dimension_2": "value_2",
			]
		)

		XCTAssertEqual(
			[rule].match(name: name, dimensions: dimensions),
			MatchResult(drop: drop, matchedRule: true)
		)
	}

	func testDoesNotMatchWhenNameDoesNotMatch() {
		let name = "name_1"
		let dimensions = [
			"dimension_1": "value_1",
			"dimension_2": "value_2",
		]
		let drop = Bool.random()
		let rule = AttributionOutputSdkConfig.Rule(
			name: "name_2",
			drop: drop,
			dimensions: [:]
		)

		XCTAssertEqual(
			[rule].match(name: name, dimensions: dimensions),
			MatchResult(drop: false, matchedRule: false)
		)
	}

	func testDoesNotMatchWhenDimensionsDoesNotMatch() {
		let name = "name_1"
		let dimensions = [
			"dimension_1": "value_1",
			"dimension_2": "value_2",
		]
		let drop = Bool.random()
		let rule = AttributionOutputSdkConfig.Rule(
			name: "name_1",
			drop: drop,
			dimensions: [
				"dimension_1": "value_1",
				"dimension_3": "value_2",
			]
		)

		XCTAssertEqual(
			[rule].match(name: name, dimensions: dimensions),
			MatchResult(drop: false, matchedRule: false)
		)
	}

	func testDoesNotMatchWhenDimensionValuesDoesNotMatch() {
		let name = "name_1"
		let dimensions = [
			"dimension_1": "value_1",
			"dimension_2": "value_2",
		]
		let drop = Bool.random()
		let rule = AttributionOutputSdkConfig.Rule(
			name: "name_1",
			drop: drop,
			dimensions: [
				"dimension_1": "value_2",
				"dimension_2": "value_2",
			]
		)

		XCTAssertEqual(
			[rule].match(name: name, dimensions: dimensions),
			MatchResult(drop: false, matchedRule: false)
		)
	}
}
