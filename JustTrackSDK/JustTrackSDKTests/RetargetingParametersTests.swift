import Foundation
import XCTest

@testable import JustTrackSDK

final class RetargetingParametersTests: XCTestCase {
	func testImplInit() {
		let params = RetargetingParametersImpl(
			wasAlreadyInstalled: true,
			url: URL(string: "https://example.com")!,
			parameters: ["key": "value"]
		)
		XCTAssertTrue(params.wasAlreadyInstalled)
		XCTAssertEqual(params.url, URL(string: "https://example.com")!)
		XCTAssertEqual(params.parameters["key"], "value")
	}

	func testPromotionParameterWithPromoCode() {
		let params = RetargetingParametersImpl(
			wasAlreadyInstalled: false,
			url: nil,
			parameters: ["promo_code": "SAVE20"]
		)
		XCTAssertEqual(params.promotionParameter, "SAVE20")
	}

	func testPromotionParameterWithEmptyPromoCode() {
		let params = RetargetingParametersImpl(
			wasAlreadyInstalled: false,
			url: nil,
			parameters: ["promo_code": ""]
		)
		XCTAssertNil(params.promotionParameter)
	}

	func testPromotionParameterWithoutPromoCode() {
		let params = RetargetingParametersImpl(
			wasAlreadyInstalled: false,
			url: nil,
			parameters: ["other": "value"]
		)
		XCTAssertNil(params.promotionParameter)
	}

	func testPromotionParameterEmptyParameters() {
		let params = RetargetingParametersImpl(
			wasAlreadyInstalled: false,
			url: nil,
			parameters: [:]
		)
		XCTAssertNil(params.promotionParameter)
	}

	func testPreliminaryValidateReturnsFuture() {
		let params = PreliminaryRetargetingParametersImpl(
			wasAlreadyInstalled: false,
			url: nil,
			parameters: [:]
		)
		let future = params.validate()
		XCTAssertFalse(future.isFulfilled)
	}

	func testPreliminaryResolve() {
		let params = PreliminaryRetargetingParametersImpl(
			wasAlreadyInstalled: false,
			url: nil,
			parameters: [:]
		)
		let mockResult = MockValidateResult(isValid: true, validParameters: params, attributionResponse: createMockAttributionResponse())
		let future = params.resolve(mockResult)
		XCTAssertTrue(future.isFulfilled)
	}

	func testPreliminaryReject() {
		let params = PreliminaryRetargetingParametersImpl(
			wasAlreadyInstalled: false,
			url: nil,
			parameters: [:]
		)
		let future = params.reject(NSError(domain: "test", code: 1))
		XCTAssertTrue(future.isFulfilled)
	}

	private struct MockValidateResult: ValidateResult {
		let isValid: Bool
		let validParameters: RetargetingParameters?
		let attributionResponse: AttributionResponse
	}

	private func createMockAttributionResponse() -> AttributionResponse {
		return AttributionResponseImpl(
			userId: StringID(),
			installId: StringID(),
			userType: "organic",
			redownload: false,
			campaign: Campaign(id: "1", name: "test", type: "test", organic: true),
			channel: Channel(id: 1, name: "test", incent: false),
			partner: Partner(id: 1, name: "test"),
			sourceId: nil,
			sourceBundleId: nil,
			sourcePlacement: nil,
			adsetId: nil,
			createdAt: Date()
		)
	}
}
