@testable import JustTrackSDK

final class MockClaimsProvider: ClaimsProvider {
	enum Call {
		case refreshClaims(sdk: JustTrackSDK.JustTrackSdkImpl)
		case provideClaims(timeout: TimeInterval, withClaims: (_ claims: [String], _ claimsDidTimeOut: Bool) -> Void)
	}

	var calls = [Call]()

	var claims = [String]()
	var claimsDidTimeOut = false

	func reset() {
		calls = []
		claims = []
		claimsDidTimeOut = false
	}

	func refreshClaims(sdk: JustTrackSDK.JustTrackSdkImpl) {
		calls.append(.refreshClaims(sdk: sdk))
	}

	func provideClaims(timeout: TimeInterval, withClaims: @escaping (_ claims: [String], _ claimsDidTimeOut: Bool) -> Void) {
		calls.append(.provideClaims(timeout: timeout, withClaims: withClaims))
		withClaims(claims, claimsDidTimeOut)
	}
}

extension MockClaimsProvider.Call: Equatable {
	static func == (lhs: MockClaimsProvider.Call, rhs: MockClaimsProvider.Call) -> Bool {
		switch (lhs, rhs) {
		case let (.refreshClaims(lhsSdk), .refreshClaims(rhsSdk)):
			return lhsSdk === rhsSdk
		case let (.provideClaims(lhsTimeout, _), .provideClaims(rhsTimeout, _)):
			return lhsTimeout == rhsTimeout
		default:
			return false
		}
	}
}
