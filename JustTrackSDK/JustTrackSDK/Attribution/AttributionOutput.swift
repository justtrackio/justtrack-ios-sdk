import Foundation

struct AttributionOutput: ValidateResult {
	let completeAttributionResponse: CompleteAttributionResponse

	var attributionResponse: AttributionResponse {
		completeAttributionResponse
	}

	let retargetingParameters: RetargetingParameters?
	let claimsTimedOut: Bool

	init(
		completeAttributionResponse: CompleteAttributionResponse,
		retargetingParameters: RetargetingParameters?,
		claimsTimedOut: Bool
	) {
		self.completeAttributionResponse = completeAttributionResponse
		self.retargetingParameters = retargetingParameters
		self.claimsTimedOut = claimsTimedOut
	}

	var isValid: Bool {
		retargetingParameters != nil
	}

	var validParameters: RetargetingParameters? {
		retargetingParameters
	}
}
