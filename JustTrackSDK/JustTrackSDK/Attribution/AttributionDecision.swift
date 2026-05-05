import Foundation

struct AttributionDecision {
	static let fetchFirstAttribution = AttributionDecision(
		claimsTimeout: ClaimsProviderImpl.claimTimeoutFast,
		isRetargetingAttribution: false,
		isRefresh: false,
		shouldFetchAttribution: true
	)
	static let fetchRetargetingAttribution = AttributionDecision(
		claimsTimeout: ClaimsProviderImpl.claimTimeoutFast,
		isRetargetingAttribution: true,
		isRefresh: false,
		shouldFetchAttribution: true
	)
	static let fetchRetargetingAttributionDelayed = AttributionDecision(
		claimsTimeout: ClaimsProviderImpl.claimTimeoutFast,
		isRetargetingAttribution: true,
		isRefresh: true,
		shouldFetchAttribution: true
	)
	static let useStoredAttribution = AttributionDecision(
		claimsTimeout: ClaimsProviderImpl.claimTimeoutFast,
		isRetargetingAttribution: false,
		isRefresh: false,
		shouldFetchAttribution: false
	)
	static let fetchAttributionAfterGettingIdfa = AttributionDecision(
		claimsTimeout: ClaimsProviderImpl.claimTimeoutFast,
		isRetargetingAttribution: false,
		isRefresh: true,
		shouldFetchAttribution: true
	)
	private let claimsTimeout: TimeInterval
	private let isRetargetingAttribution: Bool
	private let isRefresh: Bool
	let shouldFetchAttribution: Bool

	func withSlowClaimsTimeout() -> AttributionDecision {
		return AttributionDecision(
			claimsTimeout: ClaimsProviderImpl.claimTimeoutSlow,
			isRetargetingAttribution: isRetargetingAttribution,
			isRefresh: isRefresh,
			shouldFetchAttribution: shouldFetchAttribution
		)
	}

	func isFetchRetargetingAttribution() -> Bool {
		return isRetargetingAttribution && !isRefresh
	}

	func getClaimsTimeout() -> TimeInterval {
		return claimsTimeout
	}

	func isFastClaimsTimeout() -> Bool {
		return claimsTimeout == ClaimsProviderImpl.claimTimeoutFast
	}

	func merge(_ other: AttributionDecision) -> AttributionDecision {
		let maxClaimsTimeout = claimsTimeout > other.claimsTimeout ? claimsTimeout : other.claimsTimeout

		return AttributionDecision(
			claimsTimeout: maxClaimsTimeout,
			isRetargetingAttribution: shouldFetchAttribution
				? isRetargetingAttribution && (!other.shouldFetchAttribution || other.isRetargetingAttribution)
				: other.isRetargetingAttribution,
			isRefresh: isRefresh && other.isRefresh,
			shouldFetchAttribution: shouldFetchAttribution || other.shouldFetchAttribution
		)
	}
}
