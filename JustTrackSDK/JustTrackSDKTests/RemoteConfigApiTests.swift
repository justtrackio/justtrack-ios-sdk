import XCTest

@testable import JustTrackSDK

final class RemoteConfigApiTests: XCTestCase {
	private let apiToken = "test-api-token"
	private let environment = Environment()
	private let platformType = PlatformType.native
	private let userData: UserData = .fixture()
	private let sdkVersion = currentSdkVersion()
	private let appVersion = AppVersionImpl(code: "42", name: "1.2.3")

	private func makeApi(urlSession: MockUrlSession) -> RemoteConfigApiImpl {
		let httpClient = HttpClientImpl(
			retryConfig: .fixture(),
			urlSession: urlSession
		)
		let requestFactory = RequestFactoryImpl(
			environment: environment,
			platformType: platformType,
			apiToken: apiToken
		)
		return RemoteConfigApiImpl(httpClient: httpClient, requestFactory: requestFactory)
	}

	private func expectedHeadersV2(hasBody: Bool) -> [String: String?] {
		var headers: [String: String?] = [
			"X-APP-BUNDLE-ID": Bundle.main.bundleIdentifier,
			"X-APP-TOKEN": apiToken,
			"X-ADVERTISER-ID": "missing",
			"X-USER-ID": userData.userId.value,
			"X-INSTALL-ID": userData.installId.value,
			"Content-Type": "application/json; charset=utf-8",
			"User-Agent": HttpClientImpl.getUserAgent(platformType: platformType),
		]
		if hasBody {
			headers["Content-Encoding"] = "gzip"
		}
		return headers
	}

	private func makeAssignmentsParameters(
		countryIso2: String? = nil,
		attributionTimestamp: Int? = nil,
		firstSdkInitTimestamp: Int? = nil,
		installTimestamp: Int? = nil
	) -> GetAssignmentsParameters {
		GetAssignmentsParameters(
			sdkVersion: sdkVersion,
			appVersion: appVersion,
			osVersion: "17.0",
			deviceType: .phone,
			deviceModel: "iPhone16,1",
			countryIso2: countryIso2,
			deviceTimestamp: 1_700_000_000,
			attributionTimestamp: attributionTimestamp,
			firstSdkInitTimestamp: firstSdkInitTimestamp,
			installTimestamp: installTimestamp
		)
	}

	// MARK: - sendSetExperimentVariant

	func testSendSetExperimentVariantSendsRequestToCorrectUrl() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let request = DTOSetExperimentVariantRequest(
			installId: userData.installId,
			sdkVersion: sdkVersion,
			appVersion: appVersion,
			osVersion: "17.0",
			experiment: "exp_a",
			variant: "control",
			tags: [],
			happenedAt: nil
		)

		_ = api.sendSetExperimentVariant(request: request, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first, urlSession.calls.count == 1 else {
			XCTFail("Expected exactly one dataTask call")
			return
		}
		let expectedUrl = environment.getUrl(route: .testAssignment, idfaProvided: false)
		XCTAssertEqual(urlRequest.url?.absoluteString.components(separatedBy: "?").first, expectedUrl)
	}

	func testSendSetExperimentVariantUsesV2Headers() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let request = DTOSetExperimentVariantRequest(
			installId: userData.installId,
			sdkVersion: sdkVersion,
			appVersion: appVersion,
			osVersion: "17.0",
			experiment: "exp_a",
			variant: "control",
			tags: [],
			happenedAt: nil
		)

		_ = api.sendSetExperimentVariant(request: request, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let expected = expectedHeadersV2(hasBody: true)
		for (key, value) in expected {
			XCTAssertEqual(urlRequest.allHTTPHeaderFields?[key], value, "Header '\(key)' mismatch")
		}
	}

	func testSendSetExperimentVariantEncodesBodyCorrectly() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let request = DTOSetExperimentVariantRequest(
			installId: userData.installId,
			sdkVersion: sdkVersion,
			appVersion: appVersion,
			osVersion: "17.0",
			experiment: "my_experiment",
			variant: "variant_b",
			tags: ["tag1", "tag2"],
			happenedAt: nil
		)

		_ = api.sendSetExperimentVariant(request: request, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		XCTAssert(
			urlRequest.equals(
				.fixture(
					url: environment.getUrl(route: .testAssignment, idfaProvided: false),
					httpHeaders: expectedHeadersV2(hasBody: true)
				),
				with: request,
				prepareBodyData: { $0.gunziped()! }
			),
			"Request body should encode DTOSetExperimentVariantRequest correctly"
		)
	}

	func testSendSetExperimentVariantWithTagsSendsAllTagsInBody() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let tags = ["alpha", "beta", "gamma"]
		let request = DTOSetExperimentVariantRequest(
			installId: userData.installId,
			sdkVersion: sdkVersion,
			appVersion: appVersion,
			osVersion: "17.0",
			experiment: "tagged_exp",
			variant: "v1",
			tags: tags,
			happenedAt: nil
		)

		_ = api.sendSetExperimentVariant(request: request, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let decoded = try! JSONDecoder().decode(
			DTOSetExperimentVariantRequest.self,
			from: urlRequest.httpBody!.gunziped()!
		)
		XCTAssertEqual(decoded.tags, tags)
	}

	func testSendSetExperimentVariantWithHappenedAtIncludesTimestampInBody() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let happenedAt = Date(timeIntervalSince1970: 1_700_000_000)
		let request = DTOSetExperimentVariantRequest(
			installId: userData.installId,
			sdkVersion: sdkVersion,
			appVersion: appVersion,
			osVersion: "17.0",
			experiment: "timed_exp",
			variant: "v2",
			tags: [],
			happenedAt: happenedAt
		)

		_ = api.sendSetExperimentVariant(request: request, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let decoded = try! JSONDecoder().decode(
			DTOSetExperimentVariantRequest.self,
			from: urlRequest.httpBody!.gunziped()!
		)
		XCTAssertNotNil(decoded.happenedAt, "happenedAt should be present in the request body")
	}

	// MARK: - getAssignments

	func testGetAssignmentsSendsRequestToCorrectUrl() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let parameters = makeAssignmentsParameters()

		_ = api.getAssignments(parameters: parameters, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first, urlSession.calls.count == 1 else {
			XCTFail("Expected exactly one dataTask call")
			return
		}
		let expectedBaseUrl = environment.getUrl(route: .assignments, idfaProvided: false)
		XCTAssertTrue(
			urlRequest.url?.absoluteString.hasPrefix(expectedBaseUrl) == true,
			"URL should start with the assignments endpoint"
		)
	}

	func testGetAssignmentsUsesGetMethod() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)

		_ = api.getAssignments(parameters: makeAssignmentsParameters(), userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		XCTAssertEqual(urlRequest.httpMethod, "GET")
	}

	func testGetAssignmentsUsesV2Headers() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)

		_ = api.getAssignments(parameters: makeAssignmentsParameters(), userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let expected = expectedHeadersV2(hasBody: false)
		for (key, value) in expected {
			XCTAssertEqual(urlRequest.allHTTPHeaderFields?[key], value, "Header '\(key)' mismatch")
		}
	}

	func testGetAssignmentsIncludesRequiredQueryParameters() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let parameters = makeAssignmentsParameters()

		_ = api.getAssignments(parameters: parameters, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let queryItems = URLComponents(string: urlRequest.url!.absoluteString)?.queryItems ?? []
		let queryDict = Dictionary(queryItems.map { ($0.name, $0.value ?? "") }) { _, last in last }

		XCTAssertEqual(queryDict["installInstanceId"], userData.installId.value)
		XCTAssertEqual(queryDict["deviceTimestamp"], "1700000000")
		XCTAssertEqual(queryDict["osVersion"], "17.0")
		XCTAssertEqual(queryDict["deviceType"], DeviceType.phone.stringValue)
		XCTAssertEqual(queryDict["deviceModel"], "iPhone16,1")
		XCTAssertEqual(queryDict["appVersionCode"], appVersion.code)
		XCTAssertEqual(queryDict["appVersionName"], appVersion.name)
		XCTAssertEqual(queryDict["sdkVersionName"], sdkVersion.name)
		XCTAssertEqual(queryDict["sdkVersionPlatform"], "ios")
	}

	func testGetAssignmentsIncludesOptionalCountryIso2WhenProvided() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let parameters = makeAssignmentsParameters(countryIso2: "DE")

		_ = api.getAssignments(parameters: parameters, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let queryItems = URLComponents(string: urlRequest.url!.absoluteString)?.queryItems ?? []
		let queryDict = Dictionary(queryItems.map { ($0.name, $0.value ?? "") }) { _, last in last }
		XCTAssertEqual(queryDict["countryIso2"], "DE")
	}

	func testGetAssignmentsOmitsCountryIso2WhenNil() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let parameters = makeAssignmentsParameters(countryIso2: nil)

		_ = api.getAssignments(parameters: parameters, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let queryItems = URLComponents(string: urlRequest.url!.absoluteString)?.queryItems ?? []
		XCTAssertFalse(queryItems.contains(where: { $0.name == "countryIso2" }))
	}

	func testGetAssignmentsIncludesAttributionTimestampWhenProvided() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let parameters = makeAssignmentsParameters(attributionTimestamp: 1_699_000_000)

		_ = api.getAssignments(parameters: parameters, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let queryItems = URLComponents(string: urlRequest.url!.absoluteString)?.queryItems ?? []
		let queryDict = Dictionary(queryItems.map { ($0.name, $0.value ?? "") }) { _, last in last }
		XCTAssertEqual(queryDict["attributionTimestamp"], "1699000000")
	}

	func testGetAssignmentsOmitsAttributionTimestampWhenNil() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let parameters = makeAssignmentsParameters(attributionTimestamp: nil)

		_ = api.getAssignments(parameters: parameters, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let queryItems = URLComponents(string: urlRequest.url!.absoluteString)?.queryItems ?? []
		XCTAssertFalse(queryItems.contains(where: { $0.name == "attributionTimestamp" }))
	}

	func testGetAssignmentsIncludesFirstSdkInitTimestampWhenProvided() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let parameters = makeAssignmentsParameters(firstSdkInitTimestamp: 1_680_000_000)

		_ = api.getAssignments(parameters: parameters, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let queryItems = URLComponents(string: urlRequest.url!.absoluteString)?.queryItems ?? []
		let queryDict = Dictionary(queryItems.map { ($0.name, $0.value ?? "") }) { _, last in last }
		XCTAssertEqual(queryDict["firstSdkInitTimestamp"], "1680000000")
	}

	func testGetAssignmentsOmitsFirstSdkInitTimestampWhenNil() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let parameters = makeAssignmentsParameters(firstSdkInitTimestamp: nil)

		_ = api.getAssignments(parameters: parameters, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let queryItems = URLComponents(string: urlRequest.url!.absoluteString)?.queryItems ?? []
		XCTAssertFalse(queryItems.contains(where: { $0.name == "firstSdkInitTimestamp" }))
	}

	func testGetAssignmentsIncludesInstallTimestampWhenProvided() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let parameters = makeAssignmentsParameters(installTimestamp: 1_670_000_000)

		_ = api.getAssignments(parameters: parameters, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let queryItems = URLComponents(string: urlRequest.url!.absoluteString)?.queryItems ?? []
		let queryDict = Dictionary(queryItems.map { ($0.name, $0.value ?? "") }) { _, last in last }
		XCTAssertEqual(queryDict["installTimestamp"], "1670000000")
	}

	func testGetAssignmentsOmitsInstallTimestampWhenNil() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let parameters = makeAssignmentsParameters(installTimestamp: nil)

		_ = api.getAssignments(parameters: parameters, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let queryItems = URLComponents(string: urlRequest.url!.absoluteString)?.queryItems ?? []
		XCTAssertFalse(queryItems.contains(where: { $0.name == "installTimestamp" }))
	}

	func testGetAssignmentsIncludesAllOptionalParametersWhenAllProvided() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let parameters = makeAssignmentsParameters(
			countryIso2: "US",
			attributionTimestamp: 1_699_000_000,
			firstSdkInitTimestamp: 1_680_000_000,
			installTimestamp: 1_670_000_000
		)

		_ = api.getAssignments(parameters: parameters, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let queryItems = URLComponents(string: urlRequest.url!.absoluteString)?.queryItems ?? []
		let queryDict = Dictionary(queryItems.map { ($0.name, $0.value ?? "") }) { _, last in last }

		XCTAssertEqual(queryDict["countryIso2"], "US")
		XCTAssertEqual(queryDict["attributionTimestamp"], "1699000000")
		XCTAssertEqual(queryDict["firstSdkInitTimestamp"], "1680000000")
		XCTAssertEqual(queryDict["installTimestamp"], "1670000000")
	}

	func testGetAssignmentsResponseIncludesRetryAfterWhenHeaderPresent() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		var receivedResponse: AssignmentsResponse?

		_ = api.getAssignments(parameters: makeAssignmentsParameters(), userData: userData)
			.observe { result in
				if case let .success(response) = result {
					receivedResponse = response
				}
			}

		guard case let .dataTask(_, completionHandler) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let responseData = Data("{}".utf8)
		let httpResponse = HTTPURLResponse(
			url: URL(string: "https://example.com")!,
			statusCode: 200,
			httpVersion: nil,
			headerFields: ["Retry-After": "30"]
		)!
		completionHandler(responseData, httpResponse, nil)

		XCTAssertEqual(receivedResponse?.retryAfterSeconds, 30)
	}

	func testGetAssignmentsResponseHasNilRetryAfterWhenHeaderAbsent() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		var receivedResponse: AssignmentsResponse?

		_ = api.getAssignments(parameters: makeAssignmentsParameters(), userData: userData)
			.observe { result in
				if case let .success(response) = result {
					receivedResponse = response
				}
			}

		guard case let .dataTask(_, completionHandler) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let responseData = Data("{}".utf8)
		let httpResponse = HTTPURLResponse(
			url: URL(string: "https://example.com")!,
			statusCode: 200,
			httpVersion: nil,
			headerFields: [:]
		)!
		completionHandler(responseData, httpResponse, nil)

		XCTAssertNil(receivedResponse?.retryAfterSeconds)
	}

	func testGetAssignmentsResponseDataIsPassedThrough() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let expectedData = Data("{\"key\":\"value\"}".utf8)
		var receivedResponse: AssignmentsResponse?

		_ = api.getAssignments(parameters: makeAssignmentsParameters(), userData: userData)
			.observe { result in
				if case let .success(response) = result {
					receivedResponse = response
				}
			}

		guard case let .dataTask(_, completionHandler) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let httpResponse = HTTPURLResponse(
			url: URL(string: "https://example.com")!,
			statusCode: 200,
			httpVersion: nil,
			headerFields: [:]
		)!
		completionHandler(expectedData, httpResponse, nil)

		XCTAssertEqual(receivedResponse?.data, expectedData)
	}

	// MARK: - postEnrollments

	func testPostEnrollmentsSendsRequestToCorrectUrl() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let request = DTOPostEnrollmentRequest(
			installId: userData.installId,
			experimentIds: ["exp_1"]
		)

		_ = api.postEnrollments(request: request, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first, urlSession.calls.count == 1 else {
			XCTFail("Expected exactly one dataTask call")
			return
		}
		let expectedUrl = environment.getUrl(route: .assignments, idfaProvided: false)
		XCTAssertEqual(urlRequest.url?.absoluteString.components(separatedBy: "?").first, expectedUrl)
	}

	func testPostEnrollmentsUsesV2Headers() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let request = DTOPostEnrollmentRequest(
			installId: userData.installId,
			experimentIds: ["exp_1"]
		)

		_ = api.postEnrollments(request: request, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let expected = expectedHeadersV2(hasBody: true)
		for (key, value) in expected {
			XCTAssertEqual(urlRequest.allHTTPHeaderFields?[key], value, "Header '\(key)' mismatch")
		}
	}

	func testPostEnrollmentsEncodesBodyCorrectly() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let request = DTOPostEnrollmentRequest(
			installId: userData.installId,
			experimentIds: ["exp_a", "exp_b"]
		)

		_ = api.postEnrollments(request: request, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		XCTAssert(
			urlRequest.equals(
				.fixture(
					url: environment.getUrl(route: .assignments, idfaProvided: false),
					httpHeaders: expectedHeadersV2(hasBody: true)
				),
				with: request,
				prepareBodyData: { $0.gunziped()! }
			),
			"Request body should encode DTOPostEnrollmentRequest correctly"
		)
	}

	func testPostEnrollmentsWithMultipleExperimentsEncodesAllIds() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let experimentIds = ["exp_1", "exp_2", "exp_3"]
		let request = DTOPostEnrollmentRequest(
			installId: userData.installId,
			experimentIds: experimentIds
		)

		_ = api.postEnrollments(request: request, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let decoded = try! JSONDecoder().decode(
			DTOPostEnrollmentRequest.self,
			from: urlRequest.httpBody!.gunziped()!
		)
		XCTAssertEqual(decoded.experimentIds, experimentIds)
	}

	func testPostEnrollmentsWithEmptyExperimentIdsEncodesEmptyArray() {
		let urlSession = MockUrlSession()
		let api = makeApi(urlSession: urlSession)
		let request = DTOPostEnrollmentRequest(
			installId: userData.installId,
			experimentIds: []
		)

		_ = api.postEnrollments(request: request, userData: userData)

		guard case let .dataTask(urlRequest, _) = urlSession.calls.first else {
			XCTFail("Expected a dataTask call")
			return
		}
		let decoded = try! JSONDecoder().decode(
			DTOPostEnrollmentRequest.self,
			from: urlRequest.httpBody!.gunziped()!
		)
		XCTAssertTrue(decoded.experimentIds.isEmpty)
	}
}
