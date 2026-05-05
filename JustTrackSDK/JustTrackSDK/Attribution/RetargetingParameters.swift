import Foundation

/// Protocol that defines retargeting parameters for attribution tracking.
public protocol RetargetingParameters {
	/// Indicates whether the app was already installed before this retargeting event.
	var wasAlreadyInstalled: Bool { get }
	/// The URL associated with the retargeting event.
	var url: URL? { get }
	/// Dictionary of parameters extracted from the retargeting URL.
	var parameters: [String: String] { get }
	/// The promotion code parameter if present.
	var promotionParameter: String? { get }
}

/// Protocol for preliminary retargeting parameters that require validation.
public protocol PreliminaryRetargetingParameters: RetargetingParameters {
	/// Validates the preliminary retargeting parameters.
	/// - Returns: A future that resolves to the validation result.
	func validate() -> Future<ValidateResult>
}

/// Protocol representing the result of retargeting parameters validation.
public protocol ValidateResult {
	/// Indicates whether the validation was successful.
	var isValid: Bool { get }
	/// The validated retargeting parameters if validation succeeded.
	var validParameters: RetargetingParameters? { get }
	/// The attribution response received during validation.
	var attributionResponse: AttributionResponse { get }
}

class RetargetingParametersImpl: RetargetingParameters {
	public let wasAlreadyInstalled: Bool
	public let url: URL?
	public let parameters: [String: String]

	init(wasAlreadyInstalled: Bool, url: URL?, parameters: [String: String]) {
		self.wasAlreadyInstalled = wasAlreadyInstalled
		self.url = url
		self.parameters = parameters
	}

	public var promotionParameter: String? {
		if let promoCode = parameters["promo_code"], !promoCode.isEmpty {
			return promoCode
		}

		return nil
	}
}

class PreliminaryRetargetingParametersImpl: RetargetingParametersImpl, PreliminaryRetargetingParameters, Promise {
	private let validateResult = FutureImpl<ValidateResult>()

	public func validate() -> Future<ValidateResult> {
		return validateResult.toFuture()
	}

	func resolve(_ value: ValidateResult) -> Future<ValidateResult> {
		return validateResult.resolve(value)
	}

	func reject(_ error: Error) -> Future<ValidateResult> {
		return validateResult.reject(error)
	}
}
