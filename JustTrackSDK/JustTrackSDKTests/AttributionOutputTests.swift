import Foundation
import XCTest

@testable import JustTrackSDK

final class AttributionOutputTests: XCTestCase {
	func testIsValidWithRetargetingParams() {
		let output = AttributionOutput.fixture(
			retargetingParameters: RetargetingParametersImpl.fixture()
		)
		XCTAssertTrue(output.isValid)
		XCTAssertNotNil(output.validParameters)
	}

	func testIsValidWithoutRetargetingParams() {
		let output = AttributionOutput.fixture(
			retargetingParameters: nil
		)
		XCTAssertFalse(output.isValid)
		XCTAssertNil(output.validParameters)
	}

	func testAttributionResponse() {
		let attrResponse = AttributionResponseImpl.fixture(userType: "organic")
		let output = AttributionOutput.fixture(attributionResponse: attrResponse)
		XCTAssertEqual(output.attributionResponse.userType, "organic")
	}

	func testProperties() {
		let output = AttributionOutput.fixture(
			claimsTimedOut: true
		)
		XCTAssertTrue(output.claimsTimedOut)
	}
}
