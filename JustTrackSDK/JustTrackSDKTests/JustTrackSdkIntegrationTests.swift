import StoreKit
import XCTest

@testable import JustTrackSDK

final class JustTrackSdkIntegrationTests: XCTestCase {
	static let apiToken = TestCredentials.apiToken
	static let clientId = TestCredentials.clientId

	private var sdk: JustTrackSdk!

	override func setUp() {
		super.setUp()
		JustTrack.resetForTesting(clearStorage: true)
	}

	override func tearDown() {
		sdk?.shutdown()
		super.tearDown()
	}

	func testBuilderThrowsErrorWhenSdkIsBuiltNotOnMain() {
		let expectation = self.expectation(description: #function)
		DispatchQueue.global(qos: .background).async {
			do {
				let _ = try JustTrackSdkBuilder(apiToken: Self.apiToken)
					.set(bundleId: Self.clientId)
					.build()
				XCTFail("The builder should have thrown an error because the SDK instance was built not on the main thread.")
			} catch {
				XCTAssertEqual("The called method must be called from the main thread only.", error.localizedDescription)
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 30)
	}

	func testUserIdFromAttributionIsNotEmptyWhenIdfaIsProvided() {
		let idfa = StringID()
		let idfv = StringID(value: UUID().uuidString.lowercased().dropLast(3) + "6ed")!
		let httpClientImpl = HttpClientImpl(
			retryConfig: RetryConfig.defaultConfig,
			urlSession: URLSession.shared
		)
		let requestFactory = RequestFactoryImpl(
			platformType: .native,
			apiToken: Self.apiToken,
			clientId: Self.clientId
		)
		let attributionApiImpl = AttributionApiImpl(httpClient: httpClientImpl, requestFactory: requestFactory, retryConfig: httpClientImpl.retryConfig)
		let sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: httpClientImpl,
			attributionApi: attributionApiImpl,
			privacyApi: PrivacyApiImpl(httpClient: httpClientImpl, requestFactory: requestFactory),
			eventApi: EventApiImpl(httpClient: httpClientImpl, requestFactory: requestFactory, retryConfig: httpClientImpl.retryConfig, logger: LoggerImpl()),
			logApi: LogApiImpl(httpClient: httpClientImpl, requestFactory: requestFactory),
			userPropertyApi: UserPropertyApiImpl(httpClient: httpClientImpl, requestFactory: requestFactory),
			remoteConfigApi: RemoteConfigApiImpl(httpClient: httpClientImpl, requestFactory: requestFactory),
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: TestAdTrackingProvider(idfa: idfa, idfv: idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()
		let expectation = self.expectation(description: #function)
		sdk.attribution.observe { response in
			switch response {
			case let .failure(error):
				XCTFail(error.justTrackGetErrorDescription())
			case let .success(response):
				XCTAssertNotEqual((response as? CompleteAttributionResponse)?.userId.value, "00000000-0000-0000-000-000000000000")
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 30)
	}

	func testUserIdFromAttributionIsNotEmptyWhenIdfvProvided() {
		let httpClientImpl = HttpClientImpl(
			retryConfig: RetryConfig.defaultConfig,
			urlSession: URLSession.shared
		)
		let requestFactory = RequestFactoryImpl(
			platformType: .native,
			apiToken: Self.apiToken,
			clientId: Self.clientId
		)
		let attributionApiImpl2 = AttributionApiImpl(httpClient: httpClientImpl, requestFactory: requestFactory, retryConfig: httpClientImpl.retryConfig)
		let sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: httpClientImpl,
			attributionApi: attributionApiImpl2,
			privacyApi: PrivacyApiImpl(httpClient: httpClientImpl, requestFactory: requestFactory),
			eventApi: EventApiImpl(httpClient: httpClientImpl, requestFactory: requestFactory, retryConfig: httpClientImpl.retryConfig, logger: LoggerImpl()),
			logApi: LogApiImpl(httpClient: httpClientImpl, requestFactory: requestFactory),
			userPropertyApi: UserPropertyApiImpl(httpClient: httpClientImpl, requestFactory: requestFactory),
			remoteConfigApi: RemoteConfigApiImpl(httpClient: httpClientImpl, requestFactory: requestFactory),
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: TestAdTrackingProvider(idfa: nil, idfv: StringID(value: "26811331-7c7a-4873-80b3-6e9c4df6184f")),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()
		let expectation = self.expectation(description: #function)
		sdk.attribution.observe { response in
			switch response {
			case .failure(let error):
				XCTFail(error.justTrackGetErrorDescription())
			case .success(let response):
				XCTAssertNotEqual((response as? CompleteAttributionResponse)?.userId.value, "00000000-0000-0000-000-000000000000")
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 30)
	}

	func testUserIdAndInstallIdFromAttributionAreCorrectWhenRestoredFromStore() {
		let userId = StringID()
		let installId = StringID()
		withFreshStore(userId: userId, installId: installId) {
			let sdk = try! JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId, adTrackingEventPublisher: MockAdTrackingEventPublisher())
				.build()
			sdk.start()
			let expectation = self.expectation(description: #function)
			sdk.attribution.observe(using: { response in
				switch response {
				case .failure(let error):
					XCTFail(error.justTrackGetErrorDescription())
				case .success(let response):
					XCTAssertEqual((response as? CompleteAttributionResponse)?.userId, userId)
				}
				expectation.fulfill()
			})
			waitForExpectations(timeout: 10)
			sdk.shutdown()
		}
	}

	func testPredefinedEventIsPublished() {
		withBothStoreStates {
			let sdk = try! JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId, adTrackingEventPublisher: MockAdTrackingEventPublisher()).build()
			sdk.start()
			let expectation = self.expectation(description: #function)
			sdk.track(event: JtTrackingPermissionEvent(jtAction: "requested", happenedAt: Date())).observe(using: { result in
				switch result {
				case let .failure(error):
					XCTFail(error.justTrackGetErrorDescription())
				case .success:
					XCTAssert(true)
				}
				expectation.fulfill()
			})
			waitForExpectations(timeout: 120)
			sdk.shutdown()
		}
	}

	func testUserEventsArePublished() {
		withBothStoreStates {
			let sdk = try! JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId, adTrackingEventPublisher: MockAdTrackingEventPublisher()).build()
			sdk.start()
			var remainingCalls = 8
			let expectation = self.expectation(description: #function)

			let observer = { (result: Future<Void>.Result) in
				switch result {
				case .failure(let error):
					XCTFail(error.justTrackGetErrorDescription())
				case .success:
					XCTAssert(true)
				}
				remainingCalls -= 1
				if remainingCalls == 0 {
					expectation.fulfill()
				}
			}
			var event = AppEvent("test_event_name")
			sdk.track(event: event).observe(using: observer)
			event = AppEvent("test_event_count").set(count: 2)
			sdk.track(event: event).observe(using: observer)
			event = AppEvent("test_event_seconds").set(seconds: 2)
			sdk.track(event: event).observe(using: observer)
			event = AppEvent("test_event_milliseconds").set(milliseconds: 2)
			sdk.track(event: event).observe(using: observer)
			event = AppEvent("test_event_count").set(value: 3, unit: .count)
			sdk.track(event: event).observe(using: observer)
			event = AppEvent("test_event_dim1").add(dimension: "custom_1", value: "dim1")
			sdk.track(event: event).observe(using: observer)
			event = AppEvent("test_event_dim12").add(dimension: "custom_1", value: "dim1").add(dimension: "custom_2", value: "dim2")
			sdk.track(event: event).observe(using: observer)
			event = AppEvent("test_event_dim123").add(dimension: "custom_1", value: "dim1").add(dimension: "custom_2", value: "dim2").add(dimension: "custom_3", value: "dim3")
			sdk.track(event: event).observe(using: observer)
			waitForExpectations(timeout: 120)
			sdk.shutdown()
		}
	}

	func testisRunningReturnsTrueByDefault() {
		sdk = try! JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId).build()

		XCTAssertTrue(sdk.isRunning())
	}

	func testStopMethodStopsSdk() {
		sdk = try! JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId).build()
		sdk.start()

		XCTAssertTrue(sdk.isRunning())

		sdk.stop()

		XCTAssertFalse(sdk.isRunning())
	}

	func testStartMethodStartsSdk() {
		let sdk = try! JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId).build()

		sdk.start()

		XCTAssertTrue(sdk.isRunning())
	}

	func testPublishEventFailsWhenSdkIsStopped() {
		sdk = try! JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId).build()

		sdk.stop()
		XCTAssertFalse(sdk.isRunning())

		let expectation = self.expectation(description: #function)
		let event = AppEvent("test_event")

		sdk.track(event: event).observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure when SDK is stopped")
			case let .failure(error):
				XCTAssertEqual(error as! JustTrackError, .stopped)
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 5)
	}

	func testSetExperimentVariantWithInvalidExperimentName() {
		sdk = try! JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId).build()
		sdk.start()

		let expectation = self.expectation(description: #function)

		sdk.setExperimentVariant(experiment: "unzulässiger_name", variant: "variant_a", tags: [], happenedAt: Date()).observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure with invalid experiment name")
			case let .failure(error):
				XCTAssertTrue(error is InvalidFieldError)
				let fieldError = error as! InvalidFieldError
				XCTAssertTrue(fieldError.description.contains("experiment"))
				XCTAssertTrue(fieldError.description.contains("unzulässiger_name"))
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 5)
	}

	func testSetExperimentVariantWithInvalidVariant() {
		sdk = try! JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId).build()
		sdk.start()

		let expectation = self.expectation(description: #function)

		sdk.setExperimentVariant(experiment: "valid_test", variant: "unzulässiger_variant_name", tags: [], happenedAt: Date()).observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure with invalid variant")
			case let .failure(error):
				XCTAssertTrue(error is InvalidFieldError)
				let fieldError = error as! InvalidFieldError
				XCTAssertTrue(fieldError.description.contains("unzulässiger_variant_name"))
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 5)
	}

	func testSetExperimentVariantWithEmptyExperimentName() {
		sdk = try! JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId).build()
		sdk.start()

		let expectation = self.expectation(description: #function)

		sdk.setExperimentVariant(experiment: "", variant: "variant_a", tags: [], happenedAt: Date()).observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure with empty experiment name")
			case let .failure(error):
				XCTAssertTrue(error is InvalidFieldError)
				let fieldError = error as! InvalidFieldError
				XCTAssertTrue(fieldError.description.contains("experiment"))
				XCTAssertTrue(fieldError.description.contains("''"))
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 5)
	}

	func testSetExperimentVariantWhenSdkStopped() {
		sdk = try! JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId).build()
		sdk.start()
		sdk.stop()

		XCTAssertFalse(sdk.isRunning())

		let expectation = self.expectation(description: #function)

		sdk.setExperimentVariant(experiment: "test_experiment", variant: "variant_a", tags: [], happenedAt: Date()).observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure when SDK is stopped")
			case let .failure(error):
				XCTAssertEqual(error as! JustTrackError, .stopped)
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 5)
	}

	// MARK: - Helpers

	func withBothStoreStates(_ f: () -> Void) {
		// ensure we first fetch a fresh attribution
		JustTrack.resetForTesting(clearStorage: true)
		// execute on an empty store
		f()
		// reset the sdk reference
		JustTrack.resetForTesting(clearStorage: false)
		// execute with the store with the result from the first call, i.e., a filled store
		f()
	}

	func withFreshStore(userId: StringID, installId: StringID, _ f: () -> Void) {
		// ensure we first fetch a fresh attribution
		JustTrack.resetForTesting(clearStorage: true)
		Store().set(userId: userId)
		Store().set(installId: installId)
		// execute on the store
		f()
		// reset the sdk reference
		JustTrack.resetForTesting(clearStorage: false)
		// execute with the store with the result from the first call, i.e., a filled store
		f()
	}
}
