import Foundation

protocol ClaimsProvider {
	func refreshClaims(sdk: JustTrackSdkImpl)
	func provideClaims(timeout: TimeInterval, withClaims: @escaping (_ claims: [String], _ claimsDidTimeOut: Bool) -> Void)
}

final class ClaimsProviderImpl: ClaimsProvider {
	static let claimTimeoutFast: TimeInterval = 0.75
	static let claimTimeoutSlow: TimeInterval = 60
	private static let claimExpireDuration: TimeInterval = 10 * 60

	private let logger: Logger
	private var ipv4Claim: Future<String>?
	private var ipv4ClaimExpiresAt: Date
	private var ipv6Claim: Future<String>?
	private var ipv6ClaimExpiresAt: Date

	init(logger: Logger) {
		self.logger = logger
		self.ipv4Claim = nil
		self.ipv4ClaimExpiresAt = Date(timeIntervalSince1970: 0)
		self.ipv6Claim = nil
		self.ipv6ClaimExpiresAt = Date(timeIntervalSince1970: 0)
	}

	func refreshClaims(sdk: JustTrackSdkImpl) {
		// Deadlock-Safety: This only updates some fields and spawns new tasks which don't take any additional locks
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		let now = Date()
		if ipv4ClaimExpiresAt < now {
			ipv4Claim = nil
		}
		if ipv6ClaimExpiresAt < now {
			ipv6Claim = nil
		}

		if ipv4Claim == nil {
			ipv4Claim = sdk.spawnFetchClaimTask(ipProtocol: .ipV4)
			ipv4ClaimExpiresAt = now.addingTimeInterval(ClaimsProviderImpl.claimExpireDuration)
		}
		if ipv6Claim == nil {
			ipv6Claim = sdk.spawnFetchClaimTask(ipProtocol: .ipV6)
			ipv6ClaimExpiresAt = now.addingTimeInterval(ClaimsProviderImpl.claimExpireDuration)
		}
	}

	func provideClaims(timeout: TimeInterval, withClaims: @escaping ([String], Bool) -> Void) {
		var workList: [(String, Future<String>)] = []
		// add them in reverse order as the test wants to have the
		if let ipv6Claim {
			workList.append(("IPv6", ipv6Claim))
		}
		if let ipv4Claim {
			workList.append(("IPv4", ipv4Claim))
		}
		iterateWorklist([], workList, timeout, false, withClaims)
	}

	private func iterateWorklist(
		_ claims: [String],
		_ workList: [(String, Future<String>)],
		_ remainingTimeout: TimeInterval,
		_ didTimeOut: Bool,
		_ withClaims: @escaping ([String], Bool) -> Void
	) {
		var workList = workList
		guard let (type, item) = workList.popLast() else {
			withClaims(claims, didTimeOut)
			return
		}
		let start = Date()
		item.observeWithTimeout(
			timeout: remainingTimeout,
			using: { result in
				var newClaims = claims
				var newDidTimeOut = didTimeOut
				switch result {
				case .success(let token):
					newClaims.append(token)
				case .failure(let error):
					if FetchClaimErrorClassifier.isUnreachableError(error) {
						self.logger.debug("Getting \(type) claim failed, protocol is not supported", LoggerFieldsImpl().with("exception", error))
					} else {
						self.logger.warn("Getting \(type) claim failed", LoggerFieldsImpl().with("exception", error))
					}
				case .timeout:
					self.logger.debug("Getting \(type) claim timed out")
					newDidTimeOut = true
				}
				let timeTaken = Date().timeIntervalSince(start)
				self.iterateWorklist(newClaims, workList, remainingTimeout - timeTaken, newDidTimeOut, withClaims)
			}
		)
	}
}
