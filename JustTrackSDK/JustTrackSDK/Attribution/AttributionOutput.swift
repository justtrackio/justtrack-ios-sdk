import Foundation

struct AttributionOutput: ValidateResult {
	let completeAttributionResponse: CompleteAttributionResponse

	var attributionResponse: AttributionResponse {
		completeAttributionResponse
	}

	let retargetingParameters: RetargetingParameters?
	let testGroup: Int?
	let claimsTimedOut: Bool
	let sdkConfig: AttributionOutputSdkConfig?

	init(
		completeAttributionResponse: CompleteAttributionResponse,
		retargetingParameters: RetargetingParameters?,
		testGroup: Int?,
		claimsTimedOut: Bool,
		sdkConfig: AttributionOutputSdkConfig?
	) {
		self.completeAttributionResponse = completeAttributionResponse
		self.retargetingParameters = retargetingParameters
		self.testGroup = testGroup
		self.claimsTimedOut = claimsTimedOut
		self.sdkConfig = sdkConfig
	}

	var isValid: Bool {
		retargetingParameters != nil
	}

	var validParameters: RetargetingParameters? {
		retargetingParameters
	}
}
