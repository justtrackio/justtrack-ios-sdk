import Compression
import Foundation
import XCTest

@testable import JustTrackSDK

final class HttpClientTests: XCTestCase {
	private let sdkVersion = currentSdkVersion()
	private let appName = "MyApp"
	private let appVersion = AppVersionImpl(code: "1.2", name: "1.2")
	private let platformTypes = [PlatformType.native, .unity, .reactNative, .flutter]

	private let logger = LoggerImpl()
	private let userData = UserData(
		idfa: nil,
		userId: StringID(),
		installId: StringID()
	)

	private func makeHttpClient(platformType: PlatformType, urlSession: MockUrlSession) -> (HttpClientImpl, RequestFactoryImpl) {
		let httpClient = HttpClientImpl(
			retryConfig: RetryConfig(
				attributionRequestRetries: 1,
				fetchClaimRetries: 1,
				publishEventsRetries: 1
			),
			urlSession: urlSession
		)
		let requestFactory = RequestFactoryImpl(
			platformType: platformType,
			appName: appName,
			appVersion: appVersion.name,
			apiToken: "apiToken"
		)
		return (httpClient, requestFactory)
	}

	func testUserAgentEscapesNonLatinAppNameButKeepsTheStructureReadable() {
		// Regression test: a non-latin app name previously reached the header unescaped. HTTP header
		// values have to be US-ASCII, and the Android SDK rejected the very same input outright with
		// "IllegalArgumentException: Unexpected char 0x80cc ... in User-Agent value".
		let chineseAppName = "背包文明_进化对决"

		let userAgent = HttpClientImpl.getUserAgent(platformType: .native, appName: chineseAppName, appVersion: "1.0")

		XCTAssertTrue(userAgent.allSatisfy(\.isASCII), "user agent must be pure ASCII, was: \(userAgent)")
		// The structure stays readable: only the app name segment carries escapes.
		XCTAssertTrue(userAgent.hasPrefix("JustTrackSDK/"), "unexpected prefix, was: \(userAgent)")
		XCTAssertTrue(
			userAgent.contains(" %E8%83%8C%E5%8C%85%E6%96%87%E6%98%8E_%E8%BF%9B%E5%8C%96%E5%AF%B9%E5%86%B3/1.0 (\(PlatformType.native.description))"),
			"app name must be escaped in place, was: \(userAgent)"
		)
		XCTAssertEqual(userAgent.removingPercentEncoding?.contains("\(chineseAppName)/1.0"), true)
	}

	func testUserAgentLeavesPlainAsciiAppNameUnchanged() {
		let userAgent = HttpClientImpl.getUserAgent(platformType: .native, appName: "My Cool App", appVersion: "1.0")

		// Escaping must be a no-op for plain ASCII, spaces included.
		XCTAssertTrue(userAgent.contains(" My Cool App/1.0 ("), "app name must be verbatim, was: \(userAgent)")
		XCTAssertFalse(userAgent.contains("%"), "no escape may appear, was: \(userAgent)")
	}

	func testUserAgentEscapesDelimitersAndPercentInAppName() {
		let userAgent = HttpClientImpl.getUserAgent(platformType: .native, appName: "Rock/Paper 100% Disney+", appVersion: "1.0")

		XCTAssertTrue(userAgent.allSatisfy(\.isASCII), "user agent must be pure ASCII, was: \(userAgent)")
		// '/' would split name from version and '%' must survive a single decode. '+' is escaped as
		// well, which keeps the value unambiguous for either decoder on the backend.
		XCTAssertTrue(userAgent.contains("Rock%2FPaper"), "slash must be escaped, was: \(userAgent)")
		XCTAssertTrue(userAgent.contains("100%25"), "percent must be escaped, was: \(userAgent)")
		XCTAssertTrue(userAgent.contains("Disney%2B/"), "plus must be escaped, was: \(userAgent)")
		XCTAssertEqual(userAgent.removingPercentEncoding?.contains("Rock/Paper 100% Disney+/1.0"), true)
	}

	func testUserAgentContainsCorrectSdkVersionAndPlatformTypeWhenSendUserEventsIsCalled() {
		for platformType in platformTypes {
			let urlSession = MockUrlSession()
			let (httpClient, requestFactory) = makeHttpClient(platformType: platformType, urlSession: urlSession)
			let eventApi = EventApiImpl(httpClient: httpClient, requestFactory: requestFactory, retryConfig: httpClient.retryConfig, logger: httpClient.logger)
			_ = eventApi.sendUserEvents(
				events: DTOUserEvent(
					appVersion: DTOAppVersion(appVersion),
					sdkVersion: DTOSdkVersion(sdkVersion, platformType: .native),
					user: DTOUserEventUser(
						installInstanceId: StringID().value,
						countryIso: "countryIso",
						localeCode: "localeCode",
						deviceId: "idfa",
						idfv: "idfv",
						userId: StringID().value
					),
					device: DTOUserEventDevice(
						connectionType: "connectionType",
						os: DTOUserEventDeviceOS(name: "iOS", version: "1"),
						date: Date()
					),
					events: [
						DTOUserEventEvent(
							id: StringID().value,
							name: "name",
							dimensions: [:],
							value: 1,
							unit: nil,
							currency: nil,
							sessionId: "sessionId",
							happenedAt: Date(),
							sequenceNumber: 1
						)
					]
				),
				userData: userData
			)
			guard case let .dataTask(request, _) = urlSession.calls.first!, let userAgent = request.allHTTPHeaderFields!["User-Agent"] else {
				XCTAssert(false)
				return
			}

			XCTAssert(userAgent.contains("JustTrackSDK/\(sdkVersion.name)"))
			XCTAssert(userAgent.contains("\(appName)/\(appVersion.name) (\(platformType.description))"))
		}
	}

	func testUserAgentContainsCorrectSdkVersionAndPlatformTypeWhenSendAttributionRequestIsCalled() {
		for platformType in platformTypes {
			let urlSession = MockUrlSession()
			let (httpClient, requestFactory) = makeHttpClient(platformType: platformType, urlSession: urlSession)
			let attributionApi = AttributionApiImpl(httpClient: httpClient, requestFactory: requestFactory, retryConfig: httpClient.retryConfig)
			_ = attributionApi.sendAttributionRequest(
				request: DTOAttributionRequest(
					appVersion: DTOAppVersion(appVersion),
					sdkVersion: DTOSdkVersion(sdkVersion, platformType: .native),
					user: DTOAttributionRequestUser(
						userId: StringID(),
						installInstanceId: StringID(),
						idfv: StringID(),
						idfa: StringID(),
						hasLimitedAdTracking: true,
						trackingId: "trackingId",
						trackingProvider: "trackingProvider",
						countryIso: "countryIso"
					),
					device: DTOAttributionRequestDevice(
						name: "name",
						model: "model",
						product: "product",
						type: .phone,
						os: DTOAttributionRequestDeviceOS(version: "1", name: "iOS"),
						display: DTOAttributionRequestDeviceDisplay(width: 100, height: 100)
					),
					claims: ["claim"],
					parameters: ["param1": "value1"]
				),
				userData: userData
			)
			guard case let .dataTask(request, _) = urlSession.calls.first!, let userAgent = request.allHTTPHeaderFields!["User-Agent"] else {
				XCTAssert(false)
				return
			}

			XCTAssert(userAgent.contains("JustTrackSDK/\(sdkVersion.name)"))
			XCTAssert(userAgent.contains("\(appName)/\(appVersion.name) (\(platformType.description))"))
		}
	}

	func testUserAgentContainsCorrectSdkVersionAndPlatformTypeWhenSendCustomUserIdIsCalled() {
		for platformType in platformTypes {
			let urlSession = MockUrlSession()
			let (httpClient, requestFactory) = makeHttpClient(platformType: platformType, urlSession: urlSession)
			let userPropertyApi = UserPropertyApiImpl(httpClient: httpClient, requestFactory: requestFactory)
			_ = userPropertyApi.sendCustomUserId(
				request: DTOPublishCustomUserIdRequest(installId: StringID().value, customUserId: "customUserId"),
				userData: userData
			)
			guard case let .dataTask(request, _) = urlSession.calls.first!, let userAgent = request.allHTTPHeaderFields!["User-Agent"] else {
				XCTAssert(false)
				return
			}

			XCTAssert(userAgent.contains("JustTrackSDK/\(sdkVersion.name)"))
			XCTAssert(userAgent.contains("\(appName)/\(appVersion.name) (\(platformType.description))"))
		}
	}

	func testUserAgentContainsCorrectSdkVersionAndPlatformTypeWhenSendFirebaseAppInstanceIdIsCalled() {
		for platformType in platformTypes {
			let urlSession = MockUrlSession()
			let (httpClient, requestFactory) = makeHttpClient(platformType: platformType, urlSession: urlSession)
			let userPropertyApi = UserPropertyApiImpl(httpClient: httpClient, requestFactory: requestFactory)
			_ = userPropertyApi.sendFirebaseAppInstanceId(
				request: DTOPublishFirebaseAppInstanceIdRequest(
					uuid: StringID().value,
					firebaseInstanceId: "firebaseAppInstanceId"
				),
				userData: userData
			)
			guard case let .dataTask(request, _) = urlSession.calls.first!, let userAgent = request.allHTTPHeaderFields!["User-Agent"] else {
				XCTAssert(false)
				return
			}

			XCTAssert(userAgent.contains("JustTrackSDK/\(sdkVersion.name)"))
			XCTAssert(userAgent.contains("\(appName)/\(appVersion.name) (\(platformType.description))"))
		}
	}

	func testUserAgentContainsCorrectSdkVersionAndPlatformTypeWhenSendLogsIsCalled() {
		for platformType in platformTypes {
			let urlSession = MockUrlSession()
			let (httpClient, requestFactory) = makeHttpClient(platformType: platformType, urlSession: urlSession)
			let logApi = LogApiImpl(httpClient: httpClient, requestFactory: requestFactory)
			_ = logApi.sendLogs(
				input: DTOLogInput(
					messages: [DTOLogMessage("level1", "message1", ["field1": "value1"], Date())],
					metrics: [DTOLogMetric("metric", ["dimension1": "value1"], 1.1, "count", Date())],
					appVersion: DTOAppVersion(appVersion),
					sdkVersion: DTOSdkVersion(sdkVersion, platformType: .native),
					clientDate: Date()
				),
				userData: userData
			)
			guard case let .dataTask(request, _) = urlSession.calls.first!, let userAgent = request.allHTTPHeaderFields!["User-Agent"] else {
				XCTAssert(false)
				return
			}

			XCTAssert(userAgent.contains("JustTrackSDK/\(sdkVersion.name)"))
			XCTAssert(userAgent.contains("\(appName)/\(appVersion.name) (\(platformType.description))"))
		}
	}

	func testUserAgentContainsCorrectSdkVersionAndPlatformTypeWhenGetSignedIpClaimIsCalled() {
		for platformType in platformTypes {
			let urlSession = MockUrlSession()
			let (httpClient, requestFactory) = makeHttpClient(platformType: platformType, urlSession: urlSession)
			let attributionApi = AttributionApiImpl(httpClient: httpClient, requestFactory: requestFactory, retryConfig: httpClient.retryConfig)
			_ = attributionApi.getSignedIpClaim(
				ipProtocol: .ipV6,
				userData: userData
			)
			guard case let .dataTask(request, _) = urlSession.calls.first!, let userAgent = request.allHTTPHeaderFields!["User-Agent"] else {
				XCTAssert(false)
				return
			}

			XCTAssert(userAgent.contains("JustTrackSDK/\(sdkVersion.name)"))
			XCTAssert(userAgent.contains("\(appName)/\(appVersion.name) (\(platformType.description))"))
		}
	}

	func testClientSendsAttributionRequest() {
		let mockUrlSession = MockUrlSession()
		let userData: UserData = .fixture()
		let attributionRequest = DTOAttributionRequest.fixture()
		let platformType: PlatformType = .native
		let environment: Environment = Environment()
		let apiToken = "apiToken"
		let httpClient = HttpClientImpl(
			retryConfig: .fixture(),
			urlSession: mockUrlSession
		)
		let requestFactory = RequestFactoryImpl(
			environment: environment,
			platformType: platformType,
			apiToken: apiToken
		)
		let attributionApi = AttributionApiImpl(httpClient: httpClient, requestFactory: requestFactory, retryConfig: httpClient.retryConfig)

		_ = attributionApi.sendAttributionRequest(request: attributionRequest, userData: userData)

		guard case let .dataTask(request, _) = mockUrlSession.calls.first, mockUrlSession.calls.count == 1 else {
			XCTFail()
			return
		}
		XCTAssert(
			request.equals(
				.fixture(
					url: environment.getUrl(route: .attribution, idfaProvided: false),
					httpHeaders: getExpectedHeadersV2(apiToken: apiToken, platformType: platformType, hasBody: true)
				),
				with: attributionRequest,
				prepareBodyData: { $0.gunziped()! }
			)
		)
	}

	func testClientSendsCustomUserId() {
		let mockUrlSession = MockUrlSession()
		let userData: UserData = .fixture()
		let platformType: PlatformType = .native
		let environment: Environment = Environment()
		let apiToken = "apiToken"
		let customUserIdRequest = DTOPublishCustomUserIdRequest(
			installId: userData.installId.value,
			customUserId: userData.userId.value
		)
		let httpClient = HttpClientImpl(
			retryConfig: .fixture(),
			urlSession: mockUrlSession
		)
		let requestFactory = RequestFactoryImpl(
			environment: environment,
			platformType: platformType,
			apiToken: apiToken
		)
		let userPropertyApi = UserPropertyApiImpl(httpClient: httpClient, requestFactory: requestFactory)

		_ = userPropertyApi.sendCustomUserId(request: customUserIdRequest, userData: userData)

		guard case let .dataTask(request, _) = mockUrlSession.calls.first, mockUrlSession.calls.count == 1 else {
			XCTFail()
			return
		}
		XCTAssert(
			request.equals(
				.fixture(
					url: environment.getUrl(route: .publishCustomUserId, idfaProvided: false),
					httpHeaders: getExpectedHeaders(apiToken: apiToken, platformType: platformType, hasBody: true)
				),
				with: customUserIdRequest,
				prepareBodyData: { $0.gunziped()! }
			)
		)
	}

	func testClientSendsFirebaseAppInstanceId() {
		let mockUrlSession = MockUrlSession()
		let userData: UserData = .fixture()
		let platformType: PlatformType = .native
		let environment: Environment = Environment()
		let apiToken = "apiToken"
		let firebaseAppInstanceIdRequest = DTOPublishFirebaseAppInstanceIdRequest(
			uuid: StringID().value,
			firebaseInstanceId: StringID().value
		)
		let httpClient = HttpClientImpl(
			retryConfig: .fixture(),
			urlSession: mockUrlSession
		)
		let requestFactory = RequestFactoryImpl(
			environment: environment,
			platformType: platformType,
			apiToken: apiToken
		)
		let userPropertyApi = UserPropertyApiImpl(httpClient: httpClient, requestFactory: requestFactory)

		_ = userPropertyApi.sendFirebaseAppInstanceId(request: firebaseAppInstanceIdRequest, userData: userData)

		guard case let .dataTask(request, _) = mockUrlSession.calls.first, mockUrlSession.calls.count == 1 else {
			XCTFail()
			return
		}
		XCTAssert(
			request.equals(
				.fixture(
					url: environment.getUrl(route: .publishFirebaseAppInstanceId, idfaProvided: false),
					httpHeaders: getExpectedHeaders(apiToken: apiToken, platformType: platformType, hasBody: true)
				),
				with: firebaseAppInstanceIdRequest,
				prepareBodyData: { $0.gunziped()! }
			)
		)
	}

	func testClientSendsLogs() {
		let mockUrlSession = MockUrlSession()
		let userData: UserData = .fixture()
		let platformType: PlatformType = .native
		let environment: Environment = Environment()
		let apiToken = "apiToken"
		let logInput = DTOLogInput(
			messages: [.fixture()],
			metrics: [.fixture()],
			appVersion: .fixture(),
			sdkVersion: .fixture(),
			clientDate: Date(timeIntervalSince1970: 41)
		)
		let httpClient = HttpClientImpl(
			retryConfig: .fixture(),
			urlSession: mockUrlSession
		)
		let requestFactory = RequestFactoryImpl(
			environment: environment,
			platformType: platformType,
			apiToken: apiToken
		)
		let logApi = LogApiImpl(httpClient: httpClient, requestFactory: requestFactory)

		_ = logApi.sendLogs(input: logInput, userData: userData)

		guard case let .dataTask(request, _) = mockUrlSession.calls.first, mockUrlSession.calls.count == 1 else {
			XCTFail()
			return
		}
		XCTAssert(
			request.equals(
				.fixture(
					url: environment.getUrl(route: .log, idfaProvided: false),
					httpHeaders: getExpectedHeaders(apiToken: apiToken, platformType: platformType, hasBody: true)
				),
				with: logInput,
				prepareBodyData: { $0.gunziped()! }
			)
		)
	}

	func testClientGetsSignedIpClaim() {
		let mockUrlSession = MockUrlSession()
		let userData: UserData = .fixture()
		let platformType: PlatformType = .native
		let environment: Environment = Environment()
		let apiToken = "apiToken"
		let ipProtocol = IPProtocol.ipV4
		let httpClient = HttpClientImpl(
			retryConfig: .fixture(),
			urlSession: mockUrlSession
		)
		let requestFactory = RequestFactoryImpl(
			environment: environment,
			platformType: platformType,
			apiToken: apiToken
		)
		let attributionApi = AttributionApiImpl(httpClient: httpClient, requestFactory: requestFactory, retryConfig: httpClient.retryConfig)

		_ = attributionApi.getSignedIpClaim(ipProtocol: ipProtocol, userData: userData)

		guard case let .dataTask(request, _) = mockUrlSession.calls.first, mockUrlSession.calls.count == 1 else {
			XCTFail()
			return
		}
		XCTAssert(
			request.equals(
				.fixture(
					httpMethod: "GET",
					url: environment.getUrl(route: .signIPv4, idfaProvided: false),
					httpHeaders: getExpectedHeaders(apiToken: apiToken, platformType: platformType, hasBody: false)
				)
			)
		)
	}

	private func getExpectedHeaders(apiToken: String, platformType: PlatformType, hasBody: Bool) -> [String: String?] {
		var headers = [
			"X-CLIENT-ID": Bundle.main.bundleIdentifier,
			"X-CLIENT-TOKEN": apiToken,
			"X-ADVERTISER-ID": "missing",
			"X-USER-ID": "9dc781de-1b7b-4a27-ac86-bd87448c4413",
			"X-INSTALL-ID": "4135a1f0-d826-47e9-b1aa-a3a16aaf6b16",
			"Content-Type": "application/json; charset=utf-8",
			"User-Agent": HttpClientImpl.getUserAgent(platformType: platformType),
		]

		if hasBody {
			headers["Content-Encoding"] = "gzip"
		}

		return headers
	}

	private func getExpectedHeadersV2(apiToken: String, platformType: PlatformType, hasBody: Bool) -> [String: String?] {
		var headers = [
			"X-APP-BUNDLE-ID": Bundle.main.bundleIdentifier,
			"X-APP-TOKEN": apiToken,
			"X-ADVERTISER-ID": "missing",
			"X-USER-ID": "9dc781de-1b7b-4a27-ac86-bd87448c4413",
			"X-INSTALL-ID": "4135a1f0-d826-47e9-b1aa-a3a16aaf6b16",
			"Content-Type": "application/json; charset=utf-8",
			"User-Agent": HttpClientImpl.getUserAgent(platformType: platformType),
		]

		if hasBody {
			headers["Content-Encoding"] = "gzip"
		}

		return headers
	}

	// MARK: - Test helpers for new tests

	private func makeClient(
		urlSession: MockUrlSession = MockUrlSession(),
		isConsoleLoggingEnabled: Bool = true
	) -> HttpClientImpl {
		HttpClientImpl(
			retryConfig: .fixture(),
			urlSession: urlSession,
			isConsoleLoggingEnabled: isConsoleLoggingEnabled
		)
	}

	private func extractNetworkError(_ error: Error?) -> NetworkError? {
		guard let wrapper = error as? JustTrackErrorWrapper else { return nil }
		return wrapper.error as? NetworkError
	}

	private func makeHttpResponse(statusCode: Int, url: String = "https://example.com") -> HTTPURLResponse {
		HTTPURLResponse(url: URL(string: url)!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
	}

	private struct ImmediatelyUnrecoverableClassifier: ErrorClassifier {
		func classify(error: NetworkError) -> ErrorClassification? { .unrecoverable }
	}

	// MARK: - NetworkError.errorDescription

	func testNetworkErrorDescriptionBadUrl() {
		let error = NetworkError.badUrl("http://bad")
		XCTAssertEqual(error.errorDescription, "NetworkError.badUrl(http://bad)")
	}

	func testNetworkErrorDescriptionNetworkError() {
		let underlying = NSError(domain: "TestDomain", code: 42, userInfo: nil)
		let error = NetworkError.networkError(underlying)
		XCTAssertNotNil(error.errorDescription)
		XCTAssertTrue(error.errorDescription!.hasPrefix("NetworkError.networkError("))
	}

	func testNetworkErrorDescriptionBadResponseTypeWithResponse() {
		let response = URLResponse(url: URL(string: "https://x")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
		let error = NetworkError.badResponseType(response)
		XCTAssertNotNil(error.errorDescription)
		XCTAssertTrue(error.errorDescription!.hasPrefix("NetworkError.badResponseType("))
	}

	func testNetworkErrorDescriptionBadResponseTypeWithNil() {
		let error = NetworkError.badResponseType(nil)
		XCTAssertEqual(error.errorDescription, "NetworkError.badResponseType(nil response)")
	}

	func testNetworkErrorDescriptionUnexpectedResponseNon401() {
		let error = NetworkError.unexpectedResponse(500, "server error")
		XCTAssertEqual(error.errorDescription, "NetworkError.unexpectedResponse(500)")
	}

	func testNetworkErrorDescriptionUnexpectedResponse401WithBody() {
		let error = NetworkError.unexpectedResponse(401, "bad token")
		let description = error.errorDescription
		XCTAssertNotNil(description)
		XCTAssertTrue(description!.contains("NetworkError.unexpectedResponse(401)"))
		XCTAssertTrue(description!.contains("Is the API token correct?"))
		XCTAssertTrue(description!.contains("Response Body: bad token"))
	}

	func testNetworkErrorDescriptionUnexpectedResponse401WithNilBody() {
		let error = NetworkError.unexpectedResponse(401, nil)
		let description = error.errorDescription
		XCTAssertNotNil(description)
		XCTAssertTrue(description!.contains("NetworkError.unexpectedResponse(401)"))
		XCTAssertTrue(description!.contains("Is the API token correct?"))
		XCTAssertFalse(description!.contains("Response Body:"))
	}

	func testNetworkErrorDescriptionUnexpectedResponse401WithLongBodyIsTruncated() {
		let longBody = String(repeating: "a", count: 200)
		let error = NetworkError.unexpectedResponse(401, longBody)
		let description = error.errorDescription
		XCTAssertNotNil(description)
		// Truncated body: first 64 chars + "..."
		let expectedSnippet = String(repeating: "a", count: 64) + "..."
		XCTAssertTrue(description!.contains("Response Body: \(expectedSnippet)"))
		XCTAssertFalse(description!.contains(longBody))
	}

	func testNetworkErrorDescriptionMissingResponseData() {
		let error = NetworkError.missingResponseData
		XCTAssertEqual(error.errorDescription, "NetworkError.missingResponseData")
	}

	// MARK: - formatBoxed (exercised via formatInvalidToken)

	func testFormatBoxedProducesAlignedRectangle() {
		let error = NetworkError.unexpectedResponse(401, "x")
		let description = error.errorDescription!
		let lines = description.split(separator: "\n").map(String.init)
		// First and last "box" lines are rows of stars and must be equal length.
		// Locate the box (first line starting with "*").
		guard let firstStarIdx = lines.firstIndex(where: { $0.hasPrefix("*") && $0.allSatisfy({ $0 == "*" }) }) else {
			return XCTFail("Expected a top border of stars")
		}
		let topBorder = lines[firstStarIdx]
		// Find matching bottom border (same string after topBorder).
		let bottomIdx = lines[(firstStarIdx + 1)...].firstIndex(of: topBorder)
		XCTAssertNotNil(bottomIdx)
		// All middle lines must have same total length as the borders.
		let borderLength = topBorder.count
		for line in lines[(firstStarIdx + 1)..<bottomIdx!] {
			XCTAssertEqual(line.count, borderLength, "Boxed line \"\(line)\" should be padded to border length")
			XCTAssertTrue(line.hasPrefix("* "))
			XCTAssertTrue(line.hasSuffix(" *"))
		}
	}

	// MARK: - CompositeErrorClassifier

	func testCompositeErrorClassifierReturnsFirstNonNilClassification() {
		let composite = CompositeErrorClassifier(classifiers: [PaymentLimitErrorClassifier(), TrackingEventErrorClassifier()])
		// 402 -> PaymentLimitErrorClassifier returns .unrecoverable
		guard case .unrecoverable = composite.classify(error: .unexpectedResponse(402, nil)) else {
			return XCTFail("Expected .unrecoverable for 402")
		}
	}

	func testCompositeErrorClassifierFallsThroughToNextClassifier() {
		let composite = CompositeErrorClassifier(classifiers: [PaymentLimitErrorClassifier(), TrackingEventErrorClassifier()])
		// 500 -> PaymentLimit returns nil, TrackingEvent returns .unrecoverable
		guard case .unrecoverable = composite.classify(error: .unexpectedResponse(500, nil)) else {
			return XCTFail("Expected .unrecoverable for 500 via TrackingEvent fallback")
		}
	}

	func testCompositeErrorClassifierReturnsDefaultClassificationWhenAllReturnNil() {
		struct AlwaysNil: ErrorClassifier {
			func classify(error: NetworkError) -> ErrorClassification? { nil }
		}
		let composite = CompositeErrorClassifier(classifiers: [AlwaysNil(), AlwaysNil()], defaultClassification: .unrecoverable)
		guard case .unrecoverable = composite.classify(error: .missingResponseData) else {
			return XCTFail("Expected default .unrecoverable")
		}
	}

	func testCompositeErrorClassifierDefaultParameterIsRetryDefault() {
		struct AlwaysNil: ErrorClassifier {
			func classify(error: NetworkError) -> ErrorClassification? { nil }
		}
		let composite = CompositeErrorClassifier(classifiers: [AlwaysNil()])
		guard case .retryDefault = composite.classify(error: .missingResponseData) else {
			return XCTFail("Expected default .retryDefault")
		}
	}

	// MARK: - AttributionErrorClassifier

	func testAttributionErrorClassifier4xxIsUnrecoverable() {
		let classifier = AttributionErrorClassifier()
		for code in [400, 401, 403, 404, 422, 499] {
			guard case .unrecoverable = classifier.classify(error: .unexpectedResponse(code, nil)) else {
				return XCTFail("Expected .unrecoverable for \(code)")
			}
		}
	}

	func testAttributionErrorClassifier5xxIsRecoverableWithinFiveMinutes() {
		let classifier = AttributionErrorClassifier()
		for code in [500, 502, 503, 504] {
			guard case let .recoverable(delay) = classifier.classify(error: .unexpectedResponse(code, nil)) else {
				return XCTFail("Expected .recoverable for \(code)")
			}
			XCTAssertGreaterThanOrEqual(delay, 0)
			XCTAssertLessThanOrEqual(delay, 300)  // 5 minutes
		}
	}

	func testAttributionErrorClassifier3xxIsRetryDefault() {
		// Codes < 400 fall through to .retryDefault inside the .unexpectedResponse branch.
		let classifier = AttributionErrorClassifier()
		guard case .retryDefault = classifier.classify(error: .unexpectedResponse(302, nil)) else {
			return XCTFail("Expected .retryDefault for 302")
		}
	}

	func testAttributionErrorClassifierBadUrlIsUnrecoverable() {
		let classifier = AttributionErrorClassifier()
		guard case .unrecoverable = classifier.classify(error: .badUrl("http://")) else {
			return XCTFail("Expected .unrecoverable for badUrl")
		}
	}

	func testAttributionErrorClassifierOtherCasesAreRetryDefault() {
		let classifier = AttributionErrorClassifier()
		let cases: [NetworkError] = [
			.missingResponseData,
			.badResponseType(nil),
			.networkError(NSError(domain: "x", code: 1)),
		]
		for error in cases {
			guard case .retryDefault = classifier.classify(error: error) else {
				return XCTFail("Expected .retryDefault for \(error)")
			}
		}
	}

	// MARK: - PaymentLimitErrorClassifier

	func testPaymentLimitErrorClassifier402IsUnrecoverable() {
		let classifier = PaymentLimitErrorClassifier()
		guard case .unrecoverable = classifier.classify(error: .unexpectedResponse(402, nil)) else {
			return XCTFail("Expected .unrecoverable for 402")
		}
	}

	func testPaymentLimitErrorClassifierOtherStatusReturnsNil() {
		let classifier = PaymentLimitErrorClassifier()
		XCTAssertNil(classifier.classify(error: .unexpectedResponse(500, nil)))
		XCTAssertNil(classifier.classify(error: .unexpectedResponse(400, nil)))
	}

	func testPaymentLimitErrorClassifierNonUnexpectedResponseReturnsNil() {
		let classifier = PaymentLimitErrorClassifier()
		XCTAssertNil(classifier.classify(error: .badUrl("x")))
		XCTAssertNil(classifier.classify(error: .missingResponseData))
		XCTAssertNil(classifier.classify(error: .badResponseType(nil)))
		XCTAssertNil(classifier.classify(error: .networkError(NSError(domain: "x", code: 1))))
	}

	// MARK: - TrackingEventErrorClassifier

	func testTrackingEventErrorClassifierUnexpectedResponseIsUnrecoverable() {
		let classifier = TrackingEventErrorClassifier()
		guard case .unrecoverable = classifier.classify(error: .unexpectedResponse(500, nil)) else {
			return XCTFail("Expected .unrecoverable for unexpectedResponse")
		}
	}

	func testTrackingEventErrorClassifierBadUrlIsUnrecoverable() {
		let classifier = TrackingEventErrorClassifier()
		guard case .unrecoverable = classifier.classify(error: .badUrl("x")) else {
			return XCTFail("Expected .unrecoverable for badUrl")
		}
	}

	func testTrackingEventErrorClassifierRetryableCases() {
		let classifier = TrackingEventErrorClassifier()
		for error in [NetworkError.missingResponseData, .badResponseType(nil), .networkError(NSError(domain: "x", code: 1))] {
			guard case .retryDefault = classifier.classify(error: error) else {
				return XCTFail("Expected .retryDefault for \(error)")
			}
		}
	}

	// MARK: - LogErrorClassifier typealias

	func testLogErrorClassifierIsAliasForAttributionErrorClassifier() {
		// Mainly exercises the typealias declaration.
		let classifier: LogErrorClassifier = AttributionErrorClassifier()
		guard case .unrecoverable = classifier.classify(error: .badUrl("x")) else {
			return XCTFail("Expected .unrecoverable for badUrl")
		}
	}

	// MARK: - FetchClaimErrorClassifier

	func testFetchClaimErrorClassifierCannotFindHostIsUnrecoverable() {
		let classifier = FetchClaimErrorClassifier()
		let underlying = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost)
		guard case .unrecoverable = classifier.classify(error: .networkError(underlying)) else {
			return XCTFail("Expected .unrecoverable for NSURLErrorCannotFindHost")
		}
	}

	func testFetchClaimErrorClassifierOtherNetworkErrorDelegatesToTrackingEventClassifier() {
		let classifier = FetchClaimErrorClassifier()
		let underlying = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
		// Not the "cannot find host" case → delegates → TrackingEventErrorClassifier returns .retryDefault for .networkError
		guard case .retryDefault = classifier.classify(error: .networkError(underlying)) else {
			return XCTFail("Expected .retryDefault delegated from TrackingEventErrorClassifier")
		}
	}

	func testFetchClaimErrorClassifierUnexpectedResponseDelegatesToTrackingEventClassifier() {
		let classifier = FetchClaimErrorClassifier()
		guard case .unrecoverable = classifier.classify(error: .unexpectedResponse(500, nil)) else {
			return XCTFail("Expected .unrecoverable delegated from TrackingEventErrorClassifier")
		}
	}

	func testFetchClaimIsUnreachableErrorReturnsTrueForCannotFindHost() {
		let underlying = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost)
		XCTAssertTrue(FetchClaimErrorClassifier.isUnreachableError(NetworkError.networkError(underlying)))
	}

	func testFetchClaimIsUnreachableErrorUnwrapsJustTrackErrorWrapper() {
		let underlying = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost)
		let wrapped = JustTrackErrorWrapper(NetworkError.networkError(underlying))
		XCTAssertTrue(FetchClaimErrorClassifier.isUnreachableError(wrapped))
	}

	func testFetchClaimIsUnreachableErrorReturnsFalseForNonNetworkError() {
		XCTAssertFalse(FetchClaimErrorClassifier.isUnreachableError(NetworkError.badUrl("x")))
		XCTAssertFalse(FetchClaimErrorClassifier.isUnreachableError(NetworkError.missingResponseData))
		// Non-NetworkError type entirely
		XCTAssertFalse(FetchClaimErrorClassifier.isUnreachableError(NSError(domain: "Other", code: 99)))
	}

	func testFetchClaimIsUnreachableErrorReturnsFalseForOtherNetworkErrorCode() {
		let underlying = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
		XCTAssertFalse(FetchClaimErrorClassifier.isUnreachableError(NetworkError.networkError(underlying)))
	}

	func testFetchClaimIsUnreachableErrorReturnsFalseForWrongDomain() {
		let underlying = NSError(domain: "SomeOtherDomain", code: NSURLErrorCannotFindHost)
		XCTAssertFalse(FetchClaimErrorClassifier.isUnreachableError(NetworkError.networkError(underlying)))
	}

	// MARK: - UserData.providesIdfa

	func testUserDataProvidesIdfaReturnsTrueWhenIdfaIsSet() {
		let userData = UserData(idfa: StringID(), userId: StringID(), installId: StringID())
		XCTAssertTrue(userData.providesIdfa)
	}

	func testUserDataProvidesIdfaReturnsFalseWhenIdfaIsNil() {
		let userData = UserData(idfa: nil, userId: StringID(), installId: StringID())
		XCTAssertFalse(userData.providesIdfa)
	}

	// MARK: - HttpClientImpl.getUserAgent

	func testGetUserAgentWithNilAppNameOmitsAppSegment() {
		let userAgent = HttpClientImpl.getUserAgent(platformType: .native, appName: nil, appVersion: "1.0")
		XCTAssertTrue(userAgent.hasPrefix("JustTrackSDK/"))
		// The " <appName>/<version> (...)" segment must be absent.
		XCTAssertFalse(userAgent.contains(" /1.0"))
		XCTAssertFalse(userAgent.contains("/1.0 (\(PlatformType.native.description))"))
	}

	func testGetUserAgentWithAppNameIncludesAppSegment() {
		let userAgent = HttpClientImpl.getUserAgent(platformType: .unity, appName: "MyApp", appVersion: "2.3.4")
		XCTAssertTrue(
			userAgent.contains(" MyApp/2.3.4 (\(PlatformType.unity.description))"),
			"User-Agent missing app segment: \(userAgent)"
		)
	}

	// MARK: - HttpClientImpl.execute error paths

	func testExecuteRejectsWithBadUrlForInvalidUrlString() {
		let urlSession = MockUrlSession()
		let client = makeClient(urlSession: urlSession)

		var receivedError: Error?
		_ = client.execute(
			requestName: "test",
			urlString: "",
			headers: [:],
			body: nil,
			retries: 0,
			classifier: TrackingEventErrorClassifier()
		).observe { result in
			if case let .failure(error) = result {
				receivedError = error
			}
		}

		XCTAssertTrue(urlSession.calls.isEmpty, "No dataTask should be created for an invalid URL")
		guard case .badUrl(let urlString) = extractNetworkError(receivedError) else {
			return XCTFail("Expected NetworkError.badUrl, got \(String(describing: receivedError))")
		}
		XCTAssertEqual(urlString, "")
	}

	func testExecuteRejectsWithNetworkErrorWhenUnderlyingErrorPresent() {
		let urlSession = MockUrlSession()
		let client = makeClient(urlSession: urlSession)

		var receivedError: Error?
		_ = client.execute(
			requestName: "test",
			urlString: "https://example.com/path",
			headers: ["X-Test": "value"],
			body: nil,
			retries: 0,
			classifier: TrackingEventErrorClassifier()
		).observe { result in
			if case let .failure(error) = result {
				receivedError = error
			}
		}

		guard case let .dataTask(_, completionHandler) = urlSession.calls.first else {
			return XCTFail("Expected a dataTask call")
		}
		let underlying = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
		completionHandler(nil, nil, underlying)

		guard case .networkError = extractNetworkError(receivedError) else {
			return XCTFail("Expected NetworkError.networkError, got \(String(describing: receivedError))")
		}
	}

	func testExecuteRejectsWithBadResponseTypeForNonHTTPResponse() {
		let urlSession = MockUrlSession()
		let client = makeClient(urlSession: urlSession)

		var receivedError: Error?
		_ = client.execute(
			requestName: "test",
			urlString: "https://example.com",
			headers: [:],
			body: nil,
			retries: 0,
			classifier: TrackingEventErrorClassifier()
		).observe { result in
			if case let .failure(error) = result {
				receivedError = error
			}
		}

		guard case let .dataTask(_, completionHandler) = urlSession.calls.first else {
			return XCTFail("Expected a dataTask call")
		}
		let nonHttpResponse = URLResponse(url: URL(string: "https://example.com")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
		completionHandler(Data(), nonHttpResponse, nil)

		guard case .badResponseType = extractNetworkError(receivedError) else {
			return XCTFail("Expected NetworkError.badResponseType, got \(String(describing: receivedError))")
		}
	}

	func testExecuteRejectsWithUnexpectedResponseForStatusCodeOutsideSuccessRange() {
		let urlSession = MockUrlSession()
		let client = makeClient(urlSession: urlSession)

		var receivedError: Error?
		_ = client.execute(
			requestName: "test",
			urlString: "https://example.com",
			headers: [:],
			body: nil,
			retries: 0,
			classifier: ImmediatelyUnrecoverableClassifier()
		).observe { result in
			if case let .failure(error) = result {
				receivedError = error
			}
		}

		guard case let .dataTask(_, completionHandler) = urlSession.calls.first else {
			return XCTFail("Expected a dataTask call")
		}
		let body = Data("error body".utf8)
		completionHandler(body, makeHttpResponse(statusCode: 500), nil)

		guard case let .unexpectedResponse(code, responseBody) = extractNetworkError(receivedError) else {
			return XCTFail("Expected NetworkError.unexpectedResponse, got \(String(describing: receivedError))")
		}
		XCTAssertEqual(code, 500)
		XCTAssertEqual(responseBody, "error body")
	}

	func testExecuteUnexpectedResponseWithNilDataYieldsNilResponseBody() {
		let urlSession = MockUrlSession()
		let client = makeClient(urlSession: urlSession)

		var receivedError: Error?
		_ = client.execute(
			requestName: "test",
			urlString: "https://example.com",
			headers: [:],
			body: nil,
			retries: 0,
			classifier: ImmediatelyUnrecoverableClassifier()
		).observe { result in
			if case let .failure(error) = result {
				receivedError = error
			}
		}

		guard case let .dataTask(_, completionHandler) = urlSession.calls.first else {
			return XCTFail("Expected a dataTask call")
		}
		completionHandler(nil, makeHttpResponse(statusCode: 400), nil)

		guard case let .unexpectedResponse(code, responseBody) = extractNetworkError(receivedError) else {
			return XCTFail("Expected NetworkError.unexpectedResponse, got \(String(describing: receivedError))")
		}
		XCTAssertEqual(code, 400)
		XCTAssertNil(responseBody)
	}

	func testExecuteRejectsWithMissingResponseDataFor200WithNilData() {
		let urlSession = MockUrlSession()
		let client = makeClient(urlSession: urlSession)

		var receivedError: Error?
		_ = client.execute(
			requestName: "test",
			urlString: "https://example.com",
			headers: [:],
			body: nil,
			retries: 0,
			classifier: TrackingEventErrorClassifier()
		).observe { result in
			if case let .failure(error) = result {
				receivedError = error
			}
		}

		guard case let .dataTask(_, completionHandler) = urlSession.calls.first else {
			return XCTFail("Expected a dataTask call")
		}
		completionHandler(nil, makeHttpResponse(statusCode: 200), nil)

		guard case .missingResponseData = extractNetworkError(receivedError) else {
			return XCTFail("Expected NetworkError.missingResponseData, got \(String(describing: receivedError))")
		}
	}

	// MARK: - HttpClientImpl.execute success path

	func testExecuteSucceedsWithDataFor200() {
		let urlSession = MockUrlSession()
		let client = makeClient(urlSession: urlSession)

		var receivedData: Data?
		_ = client.execute(
			requestName: "test",
			urlString: "https://example.com",
			headers: [:],
			body: nil,
			retries: 0,
			classifier: TrackingEventErrorClassifier()
		).observe { result in
			if case let .success(data) = result {
				receivedData = data
			}
		}

		guard case let .dataTask(request, completionHandler) = urlSession.calls.first else {
			return XCTFail("Expected a dataTask call")
		}
		XCTAssertEqual(request.httpMethod, "GET")
		let payload = Data("hello".utf8)
		completionHandler(payload, makeHttpResponse(statusCode: 200), nil)

		XCTAssertEqual(receivedData, payload)
	}

	// MARK: - HttpClientImpl.execute<T> with transform

	func testExecuteWithTransformAppliesTransformOnSuccess() {
		let urlSession = MockUrlSession()
		let client = makeClient(urlSession: urlSession)

		var receivedValue: String?
		_ = client.execute(
			requestName: "test",
			urlString: "https://example.com",
			headers: [:],
			body: nil,
			retries: 0,
			classifier: TrackingEventErrorClassifier(),
			transform: { (data, response) -> String in
				"status=\(response.statusCode) body=\(String(data: data, encoding: .utf8) ?? "")"
			}
		).observe { result in
			if case let .success(value) = result {
				receivedValue = value
			}
		}

		guard case let .dataTask(_, completionHandler) = urlSession.calls.first else {
			return XCTFail("Expected a dataTask call")
		}
		completionHandler(Data("ok".utf8), makeHttpResponse(statusCode: 201), nil)

		XCTAssertEqual(receivedValue, "status=201 body=ok")
	}

	func testExecuteWithTransformRejectsWithBadUrlForInvalidUrl() {
		let urlSession = MockUrlSession()
		let client = makeClient(urlSession: urlSession)

		var receivedError: Error?
		_ = client.execute(
			requestName: "test",
			urlString: "",
			headers: [:],
			body: nil,
			retries: 0,
			classifier: TrackingEventErrorClassifier(),
			transform: { (_, _) -> String in "unused" }
		).observe { result in
			if case let .failure(error) = result {
				receivedError = error
			}
		}

		XCTAssertTrue(urlSession.calls.isEmpty)
		guard case .badUrl = extractNetworkError(receivedError) else {
			return XCTFail("Expected NetworkError.badUrl, got \(String(describing: receivedError))")
		}
	}

	// MARK: - HttpClientImpl.execute(retryDelaySeconds:) overload

	func testExecuteWithRetryDelaySecondsSendsRequest() {
		let urlSession = MockUrlSession()
		let client = makeClient(urlSession: urlSession)

		var receivedData: Data?
		_ = client.execute(
			requestName: "test",
			urlString: "https://example.com",
			headers: ["X-Header": "v"],
			body: Data("payload".utf8),
			retryDelaySeconds: [],
			classifier: TrackingEventErrorClassifier()
		).observe { result in
			if case let .success(data) = result {
				receivedData = data
			}
		}

		guard case let .dataTask(request, completionHandler) = urlSession.calls.first else {
			return XCTFail("Expected a dataTask call")
		}
		XCTAssertEqual(request.httpMethod, "POST")
		XCTAssertNotNil(request.httpBody)
		let payload = Data("response".utf8)
		completionHandler(payload, makeHttpResponse(statusCode: 200), nil)

		XCTAssertEqual(receivedData, payload)
	}

	func testExecuteWithRetryDelaySecondsRejectsImmediatelyWhenListIsEmpty() {
		let urlSession = MockUrlSession()
		let client = makeClient(urlSession: urlSession)

		var receivedError: Error?
		_ = client.execute(
			requestName: "test",
			urlString: "https://example.com",
			headers: [:],
			body: Data("body".utf8),
			retryDelaySeconds: [],
			classifier: TrackingEventErrorClassifier()
		).observe { result in
			if case let .failure(error) = result {
				receivedError = error
			}
		}

		guard case let .dataTask(_, completionHandler) = urlSession.calls.first else {
			return XCTFail("Expected a dataTask call")
		}
		completionHandler(nil, makeHttpResponse(statusCode: 200), nil)

		guard case .missingResponseData = extractNetworkError(receivedError) else {
			return XCTFail("Expected NetworkError.missingResponseData, got \(String(describing: receivedError))")
		}
	}

	// MARK: - Request building (body / headers / task.resume)

	func testExecuteSetsPostMethodAndGzipsBodyWhenBodyIsProvided() {
		let urlSession = MockUrlSession()
		let client = makeClient(urlSession: urlSession)

		let body = Data(repeating: 0x41, count: 256)  // highly compressible
		_ = client.execute(
			requestName: "test",
			urlString: "https://example.com",
			headers: ["X-Custom": "abc"],
			body: body,
			retries: 0,
			classifier: TrackingEventErrorClassifier()
		)

		guard case let .dataTask(request, _) = urlSession.calls.first else {
			return XCTFail("Expected a dataTask call")
		}
		XCTAssertEqual(request.httpMethod, "POST")
		XCTAssertEqual(request.value(forHTTPHeaderField: "X-Custom"), "abc")
		XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Encoding"), "gzip")
		XCTAssertEqual(request.httpBody, body.gziped())
		XCTAssertEqual(request.timeoutInterval, 30.0)
		// task.resume() was called
		XCTAssertTrue(urlSession.dataTaskWithRequest.resumeWasCalled)
	}

	func testExecuteSetsGetMethodAndNoBodyWhenBodyIsNil() {
		let urlSession = MockUrlSession()
		let client = makeClient(urlSession: urlSession)

		_ = client.execute(
			requestName: "test",
			urlString: "https://example.com",
			headers: [:],
			body: nil,
			retries: 0,
			classifier: TrackingEventErrorClassifier()
		)

		guard case let .dataTask(request, _) = urlSession.calls.first else {
			return XCTFail("Expected a dataTask call")
		}
		XCTAssertEqual(request.httpMethod, "GET")
		XCTAssertNil(request.httpBody)
		XCTAssertNil(request.value(forHTTPHeaderField: "Content-Encoding"))
	}

	// MARK: - isConsoleLoggingEnabled flag

	func testHttpClientWithConsoleLoggingDisabledStillExecutesRequest() {
		let urlSession = MockUrlSession()
		let client = makeClient(urlSession: urlSession, isConsoleLoggingEnabled: false)

		var receivedData: Data?
		_ = client.execute(
			requestName: "test",
			urlString: "https://example.com",
			headers: [:],
			body: Data("x".utf8),
			retries: 0,
			classifier: TrackingEventErrorClassifier()
		).observe { result in
			if case let .success(data) = result {
				receivedData = data
			}
		}

		guard case let .dataTask(_, completionHandler) = urlSession.calls.first else {
			return XCTFail("Expected a dataTask call")
		}
		let payload = Data("ok".utf8)
		completionHandler(payload, makeHttpResponse(statusCode: 200), nil)

		XCTAssertEqual(receivedData, payload)
	}

	func testHttpClientWithConsoleLoggingDisabledHandlesAllErrorPaths() {
		// Cover the `guard isConsoleLoggingEnabled else { return }` branches in DEBUG log helpers,
		// plus exercise IdleLogger across each error branch.
		let cases: [(statusCode: Int?, data: Data?, error: Error?, label: String)] = [
			(nil, nil, NSError(domain: NSURLErrorDomain, code: -1), "network error"),
			(500, nil, nil, "unexpected response no body"),
			(200, nil, nil, "missing data"),
		]
		for testCase in cases {
			let urlSession = MockUrlSession()
			let client = makeClient(urlSession: urlSession, isConsoleLoggingEnabled: false)

			var receivedError: Error?
			_ = client.execute(
				requestName: "test",
				urlString: "https://example.com",
				headers: [:],
				body: nil,
				retries: 0,
				classifier: ImmediatelyUnrecoverableClassifier()
			).observe { result in
				if case let .failure(error) = result {
					receivedError = error
				}
			}

			guard case let .dataTask(_, completionHandler) = urlSession.calls.first else {
				XCTFail("Expected dataTask for \(testCase.label)")
				continue
			}
			let response: URLResponse? = testCase.statusCode.map { makeHttpResponse(statusCode: $0) }
			completionHandler(testCase.data, response, testCase.error)

			XCTAssertNotNil(receivedError, "Expected error for \(testCase.label)")
		}
	}

	// Cover the bad-response-type branch separately so that we can pass a non-HTTPURLResponse.
	func testHttpClientWithConsoleLoggingDisabledBadResponseType() {
		let urlSession = MockUrlSession()
		let client = makeClient(urlSession: urlSession, isConsoleLoggingEnabled: false)

		var receivedError: Error?
		_ = client.execute(
			requestName: "test",
			urlString: "https://example.com",
			headers: [:],
			body: nil,
			retries: 0,
			classifier: TrackingEventErrorClassifier()
		).observe { result in
			if case let .failure(error) = result {
				receivedError = error
			}
		}

		guard case let .dataTask(_, completionHandler) = urlSession.calls.first else {
			return XCTFail("Expected a dataTask call")
		}
		let nonHttpResponse = URLResponse(url: URL(string: "https://example.com")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
		completionHandler(Data(), nonHttpResponse, nil)

		guard case .badResponseType = extractNetworkError(receivedError) else {
			return XCTFail("Expected NetworkError.badResponseType, got \(String(describing: receivedError))")
		}
	}
}
