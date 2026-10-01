import Foundation
import XCTest

@testable import JustTrackSDK

final class ClaimProviderTests: XCTestCase {
	func testProvideClaimsSuccess() {
		runTest(.answer1, .answer2)
	}

	func testProvideClaimsFailIPv4() {
		runTest(.failure, .answer2)
	}

	func testProvideClaimsFailIPv6() {
		runTest(.answer1, .failure)
	}

	func testProvideClaimsFailBoth() {
		runTest(.failure, .failure)
	}

	func testProvideClaimsTimeoutV4() {
		runTest(.timeout, .answer2)
	}

	func testProvideClaimsTimeoutV6() {
		runTest(.answer1, .timeout)
	}

	func testProvideClaimsTimeoutBoth() {
		runTest(.timeout, .timeout)
	}

	private func runTest(_ signResult1: TokenAnswer, _ signResult2: TokenAnswer) {
		// ensure we fetch a fresh attribution
		JustTrack.resetForTesting(clearStorage: true)
		let logger = LoggerImpl()
		let testHttpClient = TestClaimProviderHttpClient([signResult1, signResult2])
		let sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: StubHttpClient(),
			attributionApi: testHttpClient,
			privacyApi: testHttpClient,
			eventApi: testHttpClient,
			logApi: testHttpClient,
			userPropertyApi: testHttpClient,
			remoteConfigApi: testHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in TestConnectivityManager() },
			adTrackingProvider: TestAdTrackingProvider(idfa: JustTrackSdkTests.idfa, idfv: JustTrackSdkTests.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: DefaultSqliteDriver(databaseName: UUID().uuidString),
			config: .default,
			manualStart: true
		)
		sdk.start()
		let expectation = self.expectation(description: #function)
		sdk.attribution.observe { response in
			switch response {
			case let .failure(error):
				XCTFail(error.justTrackGetErrorDescription())
			case .success:
				expectation.fulfill()
			}
		}
		waitForExpectations(timeout: 30)
		XCTAssertEqual(0, testHttpClient.signResults.count)
		sdk.shutdown()
	}
}

private class TestClaimProviderHttpClient: BaseTestHttpClient {
	let expectedClaims: [String]
	var signResults: [TokenAnswer]

	init(_ signResults: [TokenAnswer]) {
		var expectedClaims: [String] = []
		for signResult in signResults {
			if let claim = signResult.getToken() {
				expectedClaims.append(claim)
			}
		}
		self.expectedClaims = expectedClaims
		self.signResults = signResults.reversed()
		super.init(changeInstallId: false, allowAttributionRequest: true)
	}

	override func sendAttributionRequest(request: DTOAttributionRequest, userData: UserData) -> Future<Data> {
		XCTAssertEqual(expectedClaims, request.claims)

		return super.sendAttributionRequest(request: request, userData: userData)
	}

	override func getSignedIpClaim(ipProtocol: IPProtocol, userData: UserData) -> Future<Data> {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		guard let next = signResults.popLast() else {
			XCTFail("No more answers stored")

			return FutureImpl().toFuture()
		}

		switch next {
		case .answer1, .answer2:
			let token = next.getToken()!

			return FutureImpl(signedIpClaimResponse(ip: "your ip value with token \(token)", type: ipProtocol.name, token: token)).toFuture()
		case .failure:
			return FutureImpl().reject(NetworkError.networkError(TestError(1)))
		case .timeout:
			// return a future which is never fulfilled
			return FutureImpl().toFuture()
		}
	}
}

private enum TokenAnswer {
	case answer1
	case answer2
	case failure
	case timeout

	fileprivate func getToken() -> String? {
		switch self {
		case .answer1:
			return "token 1"
		case .answer2:
			return "token 2"
		case .failure, .timeout:
			return nil
		}
	}
}
