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

	func testUserAgentContainsCorrectSdkVersionAndPlatformTypeWhenSendUserEventsIsCalled() {
		for platformType in platformTypes {
			let urlSession = MockUrlSession()
			let httpClient = HttpClientImpl(
				platformType: platformType,
				appName: appName,
				appVersion: appVersion.name,
				apiToken: "apiToken",
				retryConfig: RetryConfig(
					attributionRequestRetries: 1,
					fetchClaimRetries: 1,
					publishEventsRetries: 1
				),
				urlSession: urlSession
			)
			_ = httpClient.sendUserEvents(
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
			let httpClient = HttpClientImpl(
				platformType: platformType,
				appName: appName,
				appVersion: appVersion.name,
				apiToken: "apiToken",
				retryConfig: RetryConfig(
					attributionRequestRetries: 1,
					fetchClaimRetries: 1,
					publishEventsRetries: 1
				),
				urlSession: urlSession
			)
			_ = httpClient.sendAttributionRequest(
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
			let httpClient = HttpClientImpl(
				platformType: platformType,
				appName: appName,
				appVersion: appVersion.name,
				apiToken: "apiToken",
				retryConfig: RetryConfig(
					attributionRequestRetries: 1,
					fetchClaimRetries: 1,
					publishEventsRetries: 1
				),
				urlSession: urlSession
			)
			_ = httpClient.sendCustomUserId(
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
			let httpClient = HttpClientImpl(
				platformType: platformType,
				appName: appName,
				appVersion: appVersion.name,
				apiToken: "apiToken",
				retryConfig: RetryConfig(
					attributionRequestRetries: 1,
					fetchClaimRetries: 1,
					publishEventsRetries: 1
				),
				urlSession: urlSession
			)
			_ = httpClient.sendFirebaseAppInstanceId(
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
			let httpClient = HttpClientImpl(
				platformType: platformType,
				appName: appName,
				appVersion: appVersion.name,
				apiToken: "apiToken",
				retryConfig: RetryConfig(
					attributionRequestRetries: 1,
					fetchClaimRetries: 1,
					publishEventsRetries: 1
				),
				urlSession: urlSession
			)
			_ = httpClient.sendLogs(
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
			let httpClient = HttpClientImpl(
				platformType: platformType,
				appName: appName,
				appVersion: appVersion.name,
				apiToken: "apiToken",
				retryConfig: RetryConfig(
					attributionRequestRetries: 1,
					fetchClaimRetries: 1,
					publishEventsRetries: 1
				),
				urlSession: urlSession
			)
			_ = httpClient.getSignedIpClaim(
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

	func testClientSendsUserEventsWithoutFilteringWhenEventConfigIsNotSet() {
		let urlSession = MockUrlSession()
		let httpClient = HttpClientImpl(
			platformType: .native,
			apiToken: "apiToken",
			retryConfig: .fixture(),
			urlSession: urlSession
		)
		let appEvent = DTOUserEvent.fixture(
			events: [
				.fixture(
					id: "id_1",
					name: "name_1",
					dimensions: [
						"custom_1": "value_1",
						"custom_2": "value_2",
						"custom_3": "value_3",
					]
				),
				.fixture(
					id: "id_2",
					name: "name_2",
					dimensions: [
						"jt_item_id": "item_id_1",
						"jt_item_name": "item_name_1",
						"jt_item_type": "item_type_1",
					]
				),
				.fixture(
					id: "id_3",
					name: "name_3"
				),
			]
		)

		_ = httpClient.sendUserEvents(events: appEvent, userData: .fixture())

		XCTAssertEqual(urlSession.calls.count, 1)
		switch urlSession.calls.first! {
		case let .dataTask(request, _):
			let userEventFromRequest = try! JSONDecoder().decode(DTOUserEvent.self, from: request.httpBody!.gunziped()!)
			XCTAssertEqual(appEvent, userEventFromRequest)
		}
	}

	func testClientSendsUserEventsWithFilteringWhenEventConfigIsSet() {
		let urlSession = MockUrlSession()
		let httpClient = HttpClientImpl(
			platformType: .native,
			apiToken: "apiToken",
			retryConfig: .fixture(),
			urlSession: urlSession
		)
		httpClient.setRules(
			eventConfig: AttributionOutputSdkConfig.Event(
				rules: [
					AttributionOutputSdkConfig.Rule(
						name: "^.*me_1$",
						drop: true,
						dimensions: [
							"custom_1": "^val.*$",
							"custom_2": "^valu.*$",
							"custom_3": "^value_x$",
						]
					),
					AttributionOutputSdkConfig.Rule(
						name: "^.*me_2$",
						drop: true,
						dimensions: [
							Dimension.jtItemId.stringValue: "^ite.*$",
							Dimension.jtItemName.stringValue: "^item_name_1$",
							Dimension.jtItemType.stringValue: "^.*ype_1$",
						]
					),
					AttributionOutputSdkConfig.Rule(
						name: "^na.*$",
						drop: false,
						dimensions: [:]
					),
				]
			)
		)
		let appEvent = DTOUserEvent.fixture(
			events: [
				.fixture(
					id: "id_1",
					name: "name_1",
					dimensions: [
						"custom_1": "value_1",
						"custom_2": "value_2",
						"custom_3": "value_3",
					]
				),
				.fixture(
					id: "id_2",
					name: "name_2",
					dimensions: [
						"jt_item_id": "item_id_1",
						"jt_item_name": "item_name_1",
						"jt_item_type": "item_type_1",
					]
				),
				.fixture(
					id: "id_3",
					name: "name_3"
				),
			]
		)

		_ = httpClient.sendUserEvents(events: appEvent, userData: .fixture())

		XCTAssertEqual(urlSession.calls.count, 1)
		switch urlSession.calls.first! {
		case let .dataTask(request, _):
			let userEventFromRequest = try! JSONDecoder().decode(DTOUserEvent.self, from: request.httpBody!.gunziped()!)
			XCTAssertEqual(
				DTOUserEvent.fixture(
					events: [appEvent.events[0], appEvent.events[2]]
				),
				userEventFromRequest
			)
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
			environment: environment,
			platformType: platformType,
			apiToken: apiToken,
			retryConfig: .fixture(),
			urlSession: mockUrlSession
		)

		_ = httpClient.sendAttributionRequest(request: attributionRequest, userData: userData)

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
			environment: environment,
			platformType: platformType,
			apiToken: apiToken,
			retryConfig: .fixture(),
			urlSession: mockUrlSession
		)

		_ = httpClient.sendCustomUserId(request: customUserIdRequest, userData: userData)

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
			environment: environment,
			platformType: platformType,
			apiToken: apiToken,
			retryConfig: .fixture(),
			urlSession: mockUrlSession
		)

		_ = httpClient.sendFirebaseAppInstanceId(request: firebaseAppInstanceIdRequest, userData: userData)

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
			environment: environment,
			platformType: platformType,
			apiToken: apiToken,
			retryConfig: .fixture(),
			urlSession: mockUrlSession
		)

		_ = httpClient.sendLogs(input: logInput, userData: userData)

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
			environment: environment,
			platformType: platformType,
			apiToken: apiToken,
			retryConfig: .fixture(),
			urlSession: mockUrlSession
		)

		_ = httpClient.getSignedIpClaim(ipProtocol: ipProtocol, userData: userData)

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
}
