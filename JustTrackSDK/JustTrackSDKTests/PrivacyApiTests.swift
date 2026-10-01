import XCTest

@testable import JustTrackSDK

final class PrivacyApiTests: XCTestCase {
	private let apiToken = "test-api-token"
	private let environment = Environment()
	private let platformType = PlatformType.native

	private func makeApi(urlSession: MockUrlSession) -> PrivacyApiImpl {
		let httpClient = HttpClientImpl(
			retryConfig: .fixture(),
			urlSession: urlSession
		)
		let requestFactory = RequestFactoryImpl(
			environment: environment,
			platformType: platformType,
			apiToken: apiToken
		)
		return PrivacyApiImpl(httpClient: httpClient, requestFactory: requestFactory)
	}

	func testSendAnonymizeRequestSendsRequestToPrivacyUrl() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let userData: UserData = .fixture()

		_ = api.sendAnonymizeRequest(request: .fixture(), userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first, urlSession.calls.count == 1 else {
			XCTFail("Expected exactly one dataTask call")
			return
		}
		let expectedUrl = environment.getUrl(route: .privacy, idfaProvided: userData.providesIdfa)
		XCTAssertEqual(urlRequest.url?.absoluteString, expectedUrl)
	}

	func testSendAnonymizeRequestUsesProvidesIdfaFlagForUrl() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let userData: UserData = .fixture(idfa: StringID())

		_ = api.sendAnonymizeRequest(request: .fixture(), userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		XCTAssertEqual(
			urlRequest.url?.absoluteString,
			environment.getUrl(route: .privacy, idfaProvided: true)
		)
	}

	func testSendAnonymizeRequestSetsV2HeadersAndJsonBody() throws {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let userData: UserData = .fixture()
		let request = DTOAnonymizeRequest.fixture()

		_ = api.sendAnonymizeRequest(request: request, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		XCTAssertEqual(urlRequest.httpMethod, "POST")
		XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "X-APP-TOKEN"), apiToken)
		XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "X-INSTALL-ID"), userData.installId.value)
		XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/json; charset=utf-8")
	}
}
