import StoreKit
import XCTest

@testable import JustTrackSDK

final class JustTrackSdkTests: XCTestCase {
	static let apiToken = TestCredentials.apiToken
	static let clientId = TestCredentials.clientId
	static let trackingData = ("1-23456notatrackingid", "provider")
	static let idfa = StringID()
	static let idfv = StringID(value: UUID().uuidString.lowercased().dropLast(3) + "6ed")!

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

	func testTestGroupIdReturnsNilWhenIdfvIsEmpty() {
		let logger = LoggerImpl()
		let testHttpClient = TestAttributionHttpClient()
		let connectivityManager = TestConnectivityManager()
		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: testHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in connectivityManager },
			adTrackingProvider: TestAdTrackingProvider(idfa: Self.idfa, idfv: StringID("")),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)"),
			config: .default,
			manualStart: true
		)
		sdk.start()
		XCTAssertNil(sdk!.testGroupId)
	}

	func testTestGroupIdReturnsCorrectGroupId() {
		let test1 = StringID("\(UUID().uuidString.lowercased().dropLast(3))000")
		let test2 = StringID("\(UUID().uuidString.lowercased().dropLast(3))001")
		let test3 = StringID("\(UUID().uuidString.lowercased().dropLast(3))002")
		for (expectedTestGroup, idfv) in [(1, Self.idfv), (1, test1), (2, test2), (3, test3)] {
			let logger = LoggerImpl()
			let testHttpClient = TestAttributionHttpClient()
			let connectivityManager = TestConnectivityManager()
			let sdk = try! JustTrackSdkImpl(
				attributionSettings: AttributionSettings(),
				logger: logger,
				httpClient: testHttpClient,
				sessionManagerBuilder: SessionManagerImpl.init,
				connectivityManagerBuilder: { _ in connectivityManager },
				adTrackingProvider: TestAdTrackingProvider(idfa: Self.idfa, idfv: idfv),
				skAdNetwork: MockSkAdNetwork.self,
				adTrackingEventPublisher: MockAdTrackingEventPublisher(),
				sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)"),
				config: .default,
				manualStart: true
			)
			sdk.start()
			XCTAssertEqual(expectedTestGroup, sdk.testGroupId)
			sdk.shutdown()
		}
	}

	func testGroupIdIsChangedAfterAttribution() {
		let logger = LoggerImpl()
		let testHttpClient = TestAttributionHttpClient(changeInstallId: false, remainingFails: 0, testGroupId: 2, allowAttributionRequest: false)
		let connectivityManager = TestConnectivityManager()
		var testGroupId: Int? { sdk?.testGroupId }
		sdk = try! JustTrackSdkImpl(

			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: testHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in connectivityManager },
			adTrackingProvider: TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)"),
			config: .default,
			manualStart: true
		)
		sdk.start()
		XCTAssertEqual(1, testGroupId)
		testHttpClient.allowAttributionRequests()
		let expectation = self.expectation(description: #function)
		sdk.attribution.observe { response in
			switch response {
			case .failure(let error):
				XCTFail(error.justTrackGetErrorDescription())
			case .success:
				XCTAssertEqual(2, testGroupId)
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 30)
	}

	func testSdkReturnsCorrectErrorAfterReconnect() {
		let logger = LoggerImpl()
		let testHttpClient = TestAttributionHttpClient(changeInstallId: false, remainingFails: 7)
		let connectivityManager = TestConnectivityManager()
		sdk = try! JustTrackSdkImpl(

			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: testHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in connectivityManager },
			adTrackingProvider: TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()
		let expectation = self.expectation(description: #function)
		let listener = sdk.register(attributionListener: { response in
			XCTAssertEqual(response.campaign.id, 42)
			expectation.fulfill()
		})
		sdk.attribution.observe { response in
			switch response {
			case let .failure(error):
				XCTAssertEqual(error.justTrackGetErrorDescription(), NetworkError.networkError(TestError(1)).justTrackGetErrorDescription())
			case let .success(response):
				XCTFail("Unexpected success \(response)")
			}
		}
		let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
			// every second we are reachable again
			connectivityManager.triggerReconnect()
		}
		waitForExpectations(timeout: 30)
		listener.unsubscribe()
		timer.invalidate()
	}

	func testUserIdFromAttributionIsNotEmptyWhenIdfaIsProvided() {
		let sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: HttpClientImpl(
				platformType: .native,
				apiToken: Self.apiToken,
				retryConfig: RetryConfig.defaultConfig,
				urlSession: URLSession.shared,
				clientId: Self.clientId
			),
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv),
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
		let sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: HttpClientImpl(
				platformType: .native,
				apiToken: Self.apiToken,
				retryConfig: RetryConfig.defaultConfig,
				urlSession: URLSession.shared,
				clientId: Self.clientId
			),
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

	func testRefetchAttributionAfterFailure() {
		let testHttpClient = TestAttributionHttpClient(changeInstallId: false, remainingFails: 1)
		var attributionSettings = AttributionSettings()
		attributionSettings.attributionRetryDelaySeconds = 3
		sdk = try! JustTrackSdkImpl(
			attributionSettings: attributionSettings,
			logger: LoggerImpl(),
			httpClient: testHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()
		// try a few times to get the attribution, should stay cached after the first failure
		for _ in 0...3 {
			let expectationFail = self.expectation(description: #function)
			sdk.attribution.observe(using: { response in
				switch response {
				case let .failure(error):
					XCTAssertEqual(
						error.justTrackGetErrorDescription(),
						Locale.current.identifier.hasPrefix("de_")
							? "Error Domain=JustTrackSDK.NetworkError Code=1 Description=NetworkError.networkError(Error Domain=JustTrackSDKTests.TestError Code=1 Description=Der Vorgang konnte nicht abgeschlossen werden. (JustTrackSDKTests.TestError-Fehler 1.) FailureReason=nil RecoveryOptions=[] RecoverySuggestion=nil) FailureReason=nil RecoveryOptions=[] RecoverySuggestion=nil"
							: "Error Domain=JustTrackSDK.NetworkError Code=1 Description=NetworkError.networkError(Error Domain=JustTrackSDKTests.TestError Code=1 Description=The operation couldn’t be completed. (JustTrackSDKTests.TestError error 1.) FailureReason=nil RecoveryOptions=[] RecoverySuggestion=nil) FailureReason=nil RecoveryOptions=[] RecoverySuggestion=nil"
					)
				case .success:
					XCTFail("unexpected success")
				}
				expectationFail.fulfill()
			})
			waitForExpectations(timeout: 30)
		}
		// sleep some time, we should only now fetch a new attribution
		sleep(5)
		let expectationSuccess = self.expectation(description: #function)
		sdk.attribution.observe(using: { response in
			switch response {
			case .failure(let error):
				// the attribution should've been refetched now
				XCTFail(error.justTrackGetErrorDescription())
			case .success(let response):
				XCTAssertNotEqual((response as? CompleteAttributionResponse)?.userId.value, "00000000-0000-0000-000-000000000000")
			}
			expectationSuccess.fulfill()
		})
		waitForExpectations(timeout: 30)
	}

	func testCustomUserIdIsSet() {
		var idsPublished = 0
		let testHttpClient = TestAttributionHttpClient(
			changeInstallId: false,
			onCustomUserIdPublished: { request in
				XCTAssertEqual(request.customUserId, "my custom user id")
				idsPublished += 1
			}
		)
		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: testHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()
		for _ in 0...2 {
			let expectation = self.expectation(description: #function)
			sdk.set(userId: "my custom user id").observe(using: { response in
				switch response {
				case .failure(let error):
					XCTFail(error.justTrackGetErrorDescription())
				case .success:
					XCTAssertEqual(idsPublished, 1)
					expectation.fulfill()
				}
			})
			waitForExpectations(timeout: 30)
		}
	}

	func testRegisterAppForAdNetworkAttributionOrUpdatePostbackConversionValueIsCalledDuringInitWhenConversionValueSetIsFalse() {
		let testSkAdNetwork = MockSkAdNetwork.self
		testSkAdNetwork.reset()

		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: TestAttributionHttpClient(),
			sessionManagerBuilder: { sdk in
				return SessionManagerImpl(sdk)
			},
			connectivityManagerBuilder: { sdk in
				return try! ConnectivityManagerImpl()
			},
			adTrackingProvider: TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv),
			skAdNetwork: testSkAdNetwork,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()

		if #available(iOS 15.4, *) {
			XCTAssertEqual(testSkAdNetwork.calls, [.updatePostbackConversionValue(conversionValue: 0)])
		} else if #available(iOS 11.3, *) {
			XCTAssertEqual(testSkAdNetwork.calls, [.registerAppForAdNetworkAttribution])
		}
	}

	func testNeitherRegisterAppForAdNetworkAttributionNorUpdatePostbackConversionValueIsCalledDuringInitWhenConversionValueSetIsTrue() {
		let testSkAdNetwork = MockSkAdNetwork.self
		testSkAdNetwork.reset()
		UserDefaults.standard.set(true, forKey: Store.postbackConversionValueSetKey)

		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: TestAttributionHttpClient(),
			sessionManagerBuilder: { sdk in
				return SessionManagerImpl(sdk)
			},
			connectivityManagerBuilder: { sdk in
				return try! ConnectivityManagerImpl()
			},
			adTrackingProvider: TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv),
			skAdNetwork: testSkAdNetwork,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()

		XCTAssertEqual(testSkAdNetwork.calls, [])
	}

	func testPendingIdIsSentAfterCustomUserIdChanges() {
		let installId = "43bcee4a-3ac2-4869-ae6f-25ae4f03f7f9"
		let pendingUserId = "pendingUserId_1"
		let userId = StringID()
		Store().set(userId: userId)
		UserDefaults.standard.setValue(
			[
				"version": 1,
				"pendingId": pendingUserId,
				"storedId": "storedId_1",
			],
			forKey: CustomUserIdStore.key
		)
		let logger = LoggerImpl()
		let mockHttpClient = MockHttpClient()
		mockHttpClient.sendAttributionRequestResponseData = """
			{
			    "attribution": {
			        "channel": {
			            "id": 57,
			            "name": "direct",
			            "incent": false
			        },
			        "campaign": {
			            "id": 17913,
			            "name": "default_ios_JustTrack iOS (ios)",
			            "type": "acquisition",
			            "organic": true
			        },
			        "sourceBundleId": null,
			        "sourceId": null,
			        "adsetId": null,
			        "type": "organic",
			        "attributedAt": "2023-11-16T13:38:49Z",
			        "network": {
			            "id": 26,
			            "name": "Organic"
			        },
			        "sourcePlacement": null
			    },
			    "recruiter": null,
			    "retargeting": null,
			    "user": {
			        "testGroup": 3,
			        "installId": "\(installId)",
			        "redownload": false,
			        "type": "acquisition"
			    }
			}
			""".data(using: .utf8)!
		let mockAdTrackingProvider = TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv)

		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: mockHttpClient,
			sessionManagerBuilder: { sdk in
				return SessionManagerImpl(sdk)
			},
			connectivityManagerBuilder: { sdk in
				return try! ConnectivityManagerImpl()
			},
			adTrackingProvider: mockAdTrackingProvider,
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()

		// Wait a bit for the SDK to process the pending custom user ID
		Thread.sleep(forTimeInterval: 1.0)

		// Find the sendCustomUserId call in the list of calls (may not be at index 3 due to timing)
		let expectedCall = MockHttpClient.Call.sendCustomUserId(
			request: DTOPublishCustomUserIdRequest(
				installId: installId,
				customUserId: pendingUserId
			),
			userData: .fixture(
				idfa: mockAdTrackingProvider.provideIDFA(),
				userId: userId,
				installId: StringID(value: installId)!
			)
		)

		let foundCall = mockHttpClient.calls.contains(expectedCall)
		XCTAssertTrue(foundCall, "Expected sendCustomUserId call not found in \(mockHttpClient.calls.count) calls")
	}

	func testFirebaseAppInstanceIdIsSentAfterBeingSet() {
		let logger = LoggerImpl()
		let mockHttpClient = MockHttpClient()
		let mockAdTrackingProvider = TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv)
		let mockFirebaseAppInstanceId = "mock_firebase_app_instance_id_1"
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: mockHttpClient,
			sessionManagerBuilder: { sdk in
				return SessionManagerImpl(sdk)
			},
			connectivityManagerBuilder: { sdk in
				return try! ConnectivityManagerImpl()
			},
			adTrackingProvider: mockAdTrackingProvider,
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()
		mockHttpClient.reset()

		_ = sdk.set(firebaseAppInstanceId: mockFirebaseAppInstanceId)

		XCTAssertEqual(
			mockHttpClient.calls,
			[
				.sendFirebaseAppInstanceId(
					request: DTOPublishFirebaseAppInstanceIdRequest(
						uuid: userId.value,
						firebaseInstanceId: mockFirebaseAppInstanceId
					),
					userData: .fixture(
						idfa: mockAdTrackingProvider.provideIDFA(),
						userId: userId,
						installId: installId
					)
				)
			]
		)
	}

	func testSendAttributionRequestIsCalledAfterWithClaimsIsCalledSecondTime() {
		let logger = LoggerImpl()
		let mockHttpClient = MockHttpClient()
		let mockClaimsProvider = MockClaimsProvider()
		let mockAdTrackingProvider = TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv)
		let deviceInfo = DeviceInfo(idfvProvider: mockAdTrackingProvider)
		let claims = ["claim_1", "claim_2", "claim_3"]
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: mockHttpClient,
			sessionManagerBuilder: { sdk in
				return SessionManagerImpl(sdk)
			},
			connectivityManagerBuilder: { sdk in
				return try! ConnectivityManagerImpl()
			},
			adTrackingProvider: mockAdTrackingProvider,
			skAdNetwork: MockSkAdNetwork.self,
			claimsProvider: mockClaimsProvider,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: JustTrackSdkConfig(
				trackingInfo: try! JustTrackSdkConfig.TrackingInfo(id: Self.trackingData.0, provider: Self.trackingData.1)
			),
			manualStart: true
		)
		sdk.start()
		guard case let .provideClaims(_, withClaims) = mockClaimsProvider.calls[1] else {
			XCTFail()
			return
		}
		withClaims([], true)
		mockHttpClient.reset()

		withClaims(claims, false)

		XCTAssertEqual(
			mockHttpClient.calls,
			[
				.sendAttributionRequest(
					request: DTOAttributionRequest(
						appVersion: DTOAppVersion(readAppVersion()),
						sdkVersion: DTOSdkVersion(currentSdkVersion()),
						user: DTOAttributionRequestUser(
							userId: userId,
							installInstanceId: installId,
							idfv: deviceInfo.idfv,
							idfa: Self.idfa,
							hasLimitedAdTracking: false,
							trackingId: Self.trackingData.0,
							trackingProvider: Self.trackingData.1,
							countryIso: getCurrentCountry()
						),
						device: DTOAttributionRequestDevice(
							name: deviceInfo.name,
							model: deviceInfo.model,
							product: deviceInfo.product,
							type: deviceInfo.type,
							os: DTOAttributionRequestDeviceOS(
								version: deviceInfo.osVersion,
								name: deviceInfo.osName
							),
							display: DTOAttributionRequestDeviceDisplay(
								width: deviceInfo.displayWidth,
								height: deviceInfo.displayHeight
							)
						),
						claims: claims,
						parameters: [:]
					),
					userData: .fixture(
						idfa: mockAdTrackingProvider.provideIDFA(),
						userId: userId,
						installId: installId
					)
				)
			]
		)
	}

	func testSendAttributionRequestIsCalledWhenIdfaIsNotNil() {
		let logger = LoggerImpl()
		let mockHttpClient = MockHttpClient()
		let mockClaimsProvider = MockClaimsProvider()
		mockClaimsProvider.claims = ["claim_1", "claim_2", "claim_3"]
		let mockAdTrackingProvider = TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv)
		let deviceInfo = DeviceInfo(idfvProvider: mockAdTrackingProvider)
		let claims = ["claim_1", "claim_2", "claim_3"]
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: mockHttpClient,
			sessionManagerBuilder: { sdk in
				SessionManagerImpl(sdk)
			},
			connectivityManagerBuilder: { sdk in
				try! ConnectivityManagerImpl()
			},
			adTrackingProvider: mockAdTrackingProvider,
			skAdNetwork: MockSkAdNetwork.self,
			claimsProvider: mockClaimsProvider,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: JustTrackSdkConfig(
				trackingInfo: try! JustTrackSdkConfig.TrackingInfo(id: Self.trackingData.0, provider: Self.trackingData.1)
			),
			manualStart: true
		)
		sdk.start()

		XCTAssertEqual(
			mockHttpClient.calls,
			[
				.sendAttributionRequest(
					request: DTOAttributionRequest(
						appVersion: DTOAppVersion(readAppVersion()),
						sdkVersion: DTOSdkVersion(currentSdkVersion()),
						user: DTOAttributionRequestUser(
							userId: userId,
							installInstanceId: installId,
							idfv: deviceInfo.idfv,
							idfa: Self.idfa,
							hasLimitedAdTracking: false,
							trackingId: Self.trackingData.0,
							trackingProvider: Self.trackingData.1,
							countryIso: getCurrentCountry()
						),
						device: DTOAttributionRequestDevice(
							name: deviceInfo.name,
							model: deviceInfo.model,
							product: deviceInfo.product,
							type: deviceInfo.type,
							os: DTOAttributionRequestDeviceOS(
								version: deviceInfo.osVersion,
								name: deviceInfo.osName
							),
							display: DTOAttributionRequestDeviceDisplay(
								width: deviceInfo.displayWidth,
								height: deviceInfo.displayHeight
							)
						),
						claims: claims,
						parameters: [:]
					),
					userData: .fixture(
						idfa: mockAdTrackingProvider.provideIDFA(),
						userId: userId,
						installId: installId
					)
				)
			]
		)
	}

	func testSendAttributionRequestIsCalledWhenIdfaIsNil() {
		let logger = LoggerImpl()
		let mockHttpClient = MockHttpClient()
		let mockClaimsProvider = MockClaimsProvider()
		mockClaimsProvider.claims = ["claim_1", "claim_2", "claim_3"]
		let mockAdTrackingProvider = TestAdTrackingProvider(idfa: nil, idfv: Self.idfv)
		let deviceInfo = DeviceInfo(idfvProvider: mockAdTrackingProvider)
		let claims = ["claim_1", "claim_2", "claim_3"]
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: mockHttpClient,
			sessionManagerBuilder: { sdk in
				SessionManagerImpl(sdk)
			},
			connectivityManagerBuilder: { sdk in
				try! ConnectivityManagerImpl()
			},
			adTrackingProvider: mockAdTrackingProvider,
			skAdNetwork: MockSkAdNetwork.self,
			claimsProvider: mockClaimsProvider,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: JustTrackSdkConfig(
				trackingInfo: try! JustTrackSdkConfig.TrackingInfo(id: Self.trackingData.0, provider: Self.trackingData.1)
			),
			manualStart: true
		)
		sdk.start()

		XCTAssertEqual(
			mockHttpClient.calls,
			[
				.sendAttributionRequest(
					request: DTOAttributionRequest(
						appVersion: DTOAppVersion(readAppVersion()),
						sdkVersion: DTOSdkVersion(currentSdkVersion()),
						user: DTOAttributionRequestUser(
							userId: userId,
							installInstanceId: installId,
							idfv: deviceInfo.idfv,
							idfa: nil,
							hasLimitedAdTracking: true,
							trackingId: Self.trackingData.0,
							trackingProvider: Self.trackingData.1,
							countryIso: getCurrentCountry()
						),
						device: DTOAttributionRequestDevice(
							name: deviceInfo.name,
							model: deviceInfo.model,
							product: deviceInfo.product,
							type: deviceInfo.type,
							os: DTOAttributionRequestDeviceOS(
								version: deviceInfo.osVersion,
								name: deviceInfo.osName
							),
							display: DTOAttributionRequestDeviceDisplay(
								width: deviceInfo.displayWidth,
								height: deviceInfo.displayHeight
							)
						),
						claims: claims,
						parameters: [:]
					),
					userData: .fixture(
						idfa: mockAdTrackingProvider.provideIDFA(),
						userId: userId,
						installId: installId
					)
				)
			]
		)
	}

	func testSendAttributionRequestIsCalledAfterRequestTrackingWhenIdfaIsNotNil() {
		let adTrackingEventPublisher = MockAdTrackingEventPublisher(immediatelyReportsOnFinish: false)
		let logger = LoggerImpl()
		let mockHttpClient = MockHttpClient()
		let mockClaimsProvider = MockClaimsProvider()
		mockClaimsProvider.claims = ["claim_1", "claim_2", "claim_3"]
		let mockAdTrackingProvider = TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv)
		let deviceInfo = DeviceInfo(idfvProvider: mockAdTrackingProvider)
		let claims = ["claim_1", "claim_2", "claim_3"]
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: mockHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: mockAdTrackingProvider,
			skAdNetwork: MockSkAdNetwork.self,
			claimsProvider: mockClaimsProvider,
			adTrackingEventPublisher: adTrackingEventPublisher,
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: JustTrackSdkConfig(
				trackingInfo: try! JustTrackSdkConfig.TrackingInfo(id: Self.trackingData.0, provider: Self.trackingData.1)
			),
			manualStart: true
		)
		sdk.start()
		mockHttpClient.reset()

		adTrackingEventPublisher.observer?.onFinishAdTrackingAuthorization()

		XCTAssertEqual(
			mockHttpClient.calls,
			[
				.sendAttributionRequest(
					request: DTOAttributionRequest(
						appVersion: DTOAppVersion(readAppVersion()),
						sdkVersion: DTOSdkVersion(currentSdkVersion()),
						user: DTOAttributionRequestUser(
							userId: userId,
							installInstanceId: installId,
							idfv: deviceInfo.idfv,
							idfa: Self.idfa,
							hasLimitedAdTracking: false,
							trackingId: Self.trackingData.0,
							trackingProvider: Self.trackingData.1,
							countryIso: getCurrentCountry()
						),
						device: DTOAttributionRequestDevice(
							name: deviceInfo.name,
							model: deviceInfo.model,
							product: deviceInfo.product,
							type: deviceInfo.type,
							os: DTOAttributionRequestDeviceOS(
								version: deviceInfo.osVersion,
								name: deviceInfo.osName
							),
							display: DTOAttributionRequestDeviceDisplay(
								width: deviceInfo.displayWidth,
								height: deviceInfo.displayHeight
							)
						),
						claims: claims,
						parameters: [:]
					),
					userData: .fixture(
						idfa: mockAdTrackingProvider.provideIDFA(),
						userId: userId,
						installId: installId
					)
				)
			]
		)
	}

	func testSendAttributionRequestIsNotCalledAfterRequestTrackingWhenIdfaIsNil() {
		AdTrackingEventPublisher.shared.setAdTrackingAuthorizationRequestRunning(false)
		let mockHttpClient = MockHttpClient()
		let mockClaimsProvider = MockClaimsProvider()
		mockClaimsProvider.claims = ["claim_1", "claim_2", "claim_3"]
		let mockAdTrackingProvider = TestAdTrackingProvider(idfa: nil, idfv: Self.idfv)
		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: mockHttpClient,
			sessionManagerBuilder: { sdk in
				SessionManagerImpl(sdk)
			},
			connectivityManagerBuilder: { sdk in
				try! ConnectivityManagerImpl()
			},
			adTrackingProvider: mockAdTrackingProvider,
			skAdNetwork: MockSkAdNetwork.self,
			claimsProvider: mockClaimsProvider,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()
		mockHttpClient.reset()

		AdTrackingEventPublisher.shared.setAdTrackingAuthorizationRequestRunning(false)

		XCTAssertEqual(mockHttpClient.calls, [])
	}

	func testCrashReporterSetHandlerIsCalledDuringInit() throws {
		let crashReporter = MockCrashReporter()
		sdk = try JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: MockHttpClient(),
			sessionManagerBuilder: { SessionManagerImpl($0) },
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: TestAdTrackingProvider(idfa: nil, idfv: Self.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			claimsProvider: MockClaimsProvider(),
			crashReporter: crashReporter,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()

		XCTAssertEqual(crashReporter.calls, [.checkJsReport, .checkNativeCrashReport, .startMonitoring])
	}

	func testAnonymizeSendsRequest() {
		let logger = LoggerImpl()
		let mockHttpClient = MockHttpClient()
		let mockAdTrackingProvider = TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv)
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: mockHttpClient,
			sessionManagerBuilder: { sdk in
				return SessionManagerImpl(sdk)
			},
			connectivityManagerBuilder: { sdk in
				return try! ConnectivityManagerImpl()
			},
			adTrackingProvider: mockAdTrackingProvider,
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()
		mockHttpClient.reset()

		let expectation = expectation(description: #function)
		sdk.anonymize().observe { result in
			switch result {
			case let .failure(error):
				XCTFail(error.justTrackGetErrorDescription())
			case .success:
				XCTAssertEqual(mockHttpClient.calls.count, 1)
				if case let .sendAnonymizeRequest(request, _) = mockHttpClient.calls[0] {
					XCTAssertEqual(request.installInstanceId, installId.value)
					XCTAssertEqual(request.deviceId, Self.idfa.value)
					XCTAssertEqual(request.idfv, Self.idfv.value)
				} else {
					XCTFail("Expected sendAnonymizeRequest call")
				}
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 5)
	}

	func testFirebaseAppInstanceIdIsResentAfterInstallIdChange() {
		let mockFirebaseAppInstanceId = "mock_firebase_app_instance_id_resend"
		var firebaseCallCount = 0
		var firstInstallId: StringID?
		var secondInstallId: StringID?
		let logger = LoggerImpl()
		let mockAdTrackingProvider = TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv)
		let testHttpClient = TestAttributionHttpClient(changeInstallId: true, remainingFails: 0)
		testHttpClient.onFirebaseAppInstanceIdPublished = { request, userData in
			firebaseCallCount += 1
			if firebaseCallCount == 1 {
				firstInstallId = userData.installId
			} else if firebaseCallCount == 2 {
				secondInstallId = userData.installId
			}
			XCTAssertEqual(request.firebaseInstanceId, mockFirebaseAppInstanceId)
		}

		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: testHttpClient,
			sessionManagerBuilder: { sdk in
				return SessionManagerImpl(sdk)
			},
			connectivityManagerBuilder: { sdk in
				return try! ConnectivityManagerImpl()
			},
			adTrackingProvider: mockAdTrackingProvider,
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)

		_ = sdk.set(firebaseAppInstanceId: mockFirebaseAppInstanceId)

		sdk.start()

		let expectation1 = expectation(description: "Initial attribution")
		sdk.attribution.observe { _ in
			expectation1.fulfill()
		}
		waitForExpectations(timeout: 5)

		Thread.sleep(forTimeInterval: 0.5)

		XCTAssertGreaterThanOrEqual(firebaseCallCount, 2, "Firebase app instance ID should be sent at least twice")

		XCTAssertNotNil(firstInstallId, "First Firebase call should have an install ID")
		XCTAssertNotNil(secondInstallId, "Second Firebase call should have an install ID")
		if let first = firstInstallId, let second = secondInstallId {
			XCTAssertNotEqual(first, second, "Install ID should have changed between Firebase calls")
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

	func testSetExperimentVariantWithValidParameters() {
		let logger = LoggerImpl()
		let mockHttpClient = MockHttpClient()
		let mockAdTrackingProvider = TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv)
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)

		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: mockHttpClient,
			sessionManagerBuilder: { SessionManagerImpl($0) },
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: mockAdTrackingProvider,
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()
		mockHttpClient.reset()

		let expectation = self.expectation(description: #function)
		let testDate = Date()

		sdk.setExperimentVariant(experiment: "test_experiment_1", variant: "variant_a", tags: [], happenedAt: testDate).observe { result in
			switch result {
			case let .failure(error):
				XCTFail(error.justTrackGetErrorDescription())
			case .success:
				XCTAssertEqual(mockHttpClient.calls.count, 1)
				if case let .sendSetExperimentVariant(request, _) = mockHttpClient.calls[0] {
					XCTAssertEqual(request.experiment, "test_experiment_1")
					XCTAssertEqual(request.variant, "variant_a")
					XCTAssertTrue(request.tags.isEmpty)
					let formatter = ISO8601DateFormatter()
					formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
					XCTAssertEqual(request.happenedAt, formatter.string(from: testDate))
				} else {
					XCTFail("Expected sendSetExperimentVariant call")
				}
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

	func testSetExperimentVariantNetworkFailure() {
		let logger = LoggerImpl()
		let mockHttpClient = MockHttpClient()
		mockHttpClient.sendSetExperimentVariantError = NetworkError.networkError(TestError(500))
		let mockAdTrackingProvider = TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv)
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)

		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: mockHttpClient,
			sessionManagerBuilder: { SessionManagerImpl($0) },
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: mockAdTrackingProvider,
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()

		let expectation = self.expectation(description: #function)

		sdk.setExperimentVariant(experiment: "test_experiment", variant: "variant_a", tags: [], happenedAt: Date()).observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure with network error")
			case let .failure(error):
				XCTAssertTrue(error is NetworkError)
				if case let .networkError(underlyingError) = error as! NetworkError {
					XCTAssertTrue(underlyingError is TestError)
				} else {
					XCTFail("Expected networkError")
				}
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 5)
	}

	func testSetExperimentVariantWithTags() {
		let logger = LoggerImpl()
		let mockHttpClient = MockHttpClient()
		let mockAdTrackingProvider = TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv)
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)

		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: mockHttpClient,
			sessionManagerBuilder: { SessionManagerImpl($0) },
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: mockAdTrackingProvider,
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()
		mockHttpClient.reset()

		let expectation = self.expectation(description: #function)
		let testDate = Date()

		sdk.setExperimentVariant(experiment: "control_test", variant: "control", tags: ["ui", "test"], happenedAt: testDate).observe { result in
			switch result {
			case let .failure(error):
				XCTFail(error.justTrackGetErrorDescription())
			case .success:
				XCTAssertEqual(mockHttpClient.calls.count, 1)
				if case let .sendSetExperimentVariant(request, _) = mockHttpClient.calls[0] {
					XCTAssertEqual(request.experiment, "control_test")
					XCTAssertEqual(request.variant, "control")
					XCTAssertEqual(request.tags, ["ui", "test"])
					let formatter = ISO8601DateFormatter()
					formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
					XCTAssertEqual(request.happenedAt, formatter.string(from: testDate))
				} else {
					XCTFail("Expected sendSetExperimentVariant call")
				}
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 5)
	}

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

	// MARK: - Custom Bundle ID and Application Version Tests

	func testBuilderSetsApplicationVersion() throws {
		let customVersionName = "2.0.0"
		let customVersionCode = "42"
		let customVersion = AppVersionImpl(code: customVersionCode, name: customVersionName)
		let mockHttpClient = MockHttpClient()
		let mockAdTrackingProvider = TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv)

		sdk = try JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: mockHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: mockAdTrackingProvider,
			skAdNetwork: MockSkAdNetwork.self,
			applicationVersion: customVersion,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)

		XCTAssertNotNil(sdk)
		XCTAssertEqual(sdk.appVersionAtInstall.name, customVersionName)
		XCTAssertEqual(sdk.appVersionAtInstall.code, customVersionCode)
	}

	func testBuilderSetsBundleIdAndApplicationVersion() throws {
		let customBundleId = "com.example.custom.app"
		let customVersionName = "3.0.0"
		let customVersionCode = "100"
		let customVersion = AppVersionImpl(code: customVersionCode, name: customVersionName)
		let mockHttpClient = MockHttpClient()
		let mockAdTrackingProvider = TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv)

		sdk = try JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: mockHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: mockAdTrackingProvider,
			skAdNetwork: MockSkAdNetwork.self,
			bundleId: customBundleId,
			applicationVersion: customVersion,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)

		XCTAssertNotNil(sdk)
		XCTAssertEqual(sdk.appVersionAtInstall.name, customVersionName)
		XCTAssertEqual(sdk.appVersionAtInstall.code, customVersionCode)
	}

	func testAttributionRequestUsesCustomApplicationVersion() throws {
		let customVersionName = "5.0.0"
		let customVersionCode = "500"
		let customVersion = AppVersionImpl(code: customVersionCode, name: customVersionName)
		let mockHttpClient = MockHttpClient()
		let mockClaimsProvider = MockClaimsProvider()
		mockClaimsProvider.claims = []
		let mockAdTrackingProvider = TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv)
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)

		sdk = try JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: mockHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: mockAdTrackingProvider,
			skAdNetwork: MockSkAdNetwork.self,
			claimsProvider: mockClaimsProvider,
			applicationVersion: customVersion,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()

		// Wait for attribution request to be sent
		let expectation = expectation(description: #function)
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			// Verify the attribution request contains the custom app version
			for call in mockHttpClient.calls {
				if case let .sendAttributionRequest(request, _) = call {
					XCTAssertEqual(request.appVersion.name, customVersionName)
					XCTAssertEqual(request.appVersion.code, customVersionCode)
					expectation.fulfill()
					return
				}
			}
			XCTFail("No attribution request was sent")
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
	}
}

class TestConnectivityManager: ConnectivityManager {
	let subscriptionManager: SubscriptionManager<()>

	init() {
		subscriptionManager = SubscriptionManager()
	}

	func registerOnReconnect(_ callback: @escaping () -> Void) -> Subscription {
		return subscriptionManager.subscribe(listener: { _ in
			callback()
		})
	}

	func shutdown() {
		// nop
	}

	func triggerReconnect() {
		subscriptionManager.call(value: ())
	}
}

class TestAttributionHttpClient: BaseTestHttpClient {
	var remainingFails: Int
	var successfulCalls: Int
	var onEventsPublished: ((DTOUserEvent) -> Void)?
	var onCustomUserIdPublished: ((DTOPublishCustomUserIdRequest) -> Void)?
	var onFirebaseAppInstanceIdPublished: ((DTOPublishFirebaseAppInstanceIdRequest, UserData) -> Void)?

	convenience init() {
		self.init(changeInstallId: false, remainingFails: 0, testGroupId: nil, allowAttributionRequest: true)
	}

	convenience init(changeInstallId: Bool, remainingFails: Int) {
		self.init(changeInstallId: changeInstallId, remainingFails: remainingFails, testGroupId: nil, allowAttributionRequest: true)
	}

	init(changeInstallId: Bool, remainingFails: Int, testGroupId: Int??, allowAttributionRequest: Bool) {
		self.remainingFails = remainingFails
		self.successfulCalls = 0
		self.onEventsPublished = nil
		self.onCustomUserIdPublished = nil
		self.onFirebaseAppInstanceIdPublished = nil
		super.init(changeInstallId: changeInstallId, testGroupId: testGroupId, allowAttributionRequest: allowAttributionRequest)
	}

	init(changeInstallId: Bool, onEventsPublished: @escaping (DTOUserEvent) -> Void) {
		self.remainingFails = 0
		self.successfulCalls = 0
		self.onEventsPublished = onEventsPublished
		self.onCustomUserIdPublished = nil
		self.onFirebaseAppInstanceIdPublished = nil
		super.init(changeInstallId: changeInstallId, testGroupId: nil, allowAttributionRequest: true)
	}

	init(changeInstallId: Bool, onCustomUserIdPublished: @escaping (DTOPublishCustomUserIdRequest) -> Void) {
		self.remainingFails = 0
		self.successfulCalls = 0
		self.onEventsPublished = nil
		self.onCustomUserIdPublished = onCustomUserIdPublished
		self.onFirebaseAppInstanceIdPublished = nil
		super.init(changeInstallId: changeInstallId, testGroupId: nil, allowAttributionRequest: true)
	}

	override func sendAttributionRequest(request: DTOAttributionRequest, userData: UserData) -> Future<Data> {
		if remainingFails > 0 {
			remainingFails -= 1

			return FutureImpl().reject(NetworkError.networkError(TestError(1)))
		}

		successfulCalls += 1

		return super.sendAttributionRequest(request: request, userData: userData)
	}

	override func sendUserEvents(events: DTOUserEvent, userData: UserData) -> Future<Data> {
		if let onEventsPublished {
			onEventsPublished(events)
		}

		return super.sendUserEvents(events: events, userData: userData)
	}

	override func sendCustomUserId(request: DTOPublishCustomUserIdRequest, userData: UserData) -> Future<Data> {
		guard let onCustomUserIdPublished = onCustomUserIdPublished else {
			return super.sendCustomUserId(request: request, userData: userData)
		}

		onCustomUserIdPublished(request)

		return FutureImpl("{}".data(using: .utf8)).toFuture()
	}

	override func sendFirebaseAppInstanceId(request: DTOPublishFirebaseAppInstanceIdRequest, userData: UserData) -> Future<Data> {
		if let onFirebaseAppInstanceIdPublished = onFirebaseAppInstanceIdPublished {
			onFirebaseAppInstanceIdPublished(request, userData)
		}

		return FutureImpl("{}".data(using: .utf8)).toFuture()
	}
}

class BaseTestHttpClient: HttpClient {
	private let testGroupId: Int??
	private let attributionRequestAllowed: FutureImpl<()>
	let installId: StringID?

	init(changeInstallId: Bool, testGroupId: Int??, allowAttributionRequest: Bool) {
		self.testGroupId = testGroupId
		if allowAttributionRequest {
			self.attributionRequestAllowed = FutureImpl(())
		} else {
			self.attributionRequestAllowed = FutureImpl()
		}
		if changeInstallId {
			installId = StringID()
		} else {
			installId = nil
		}
	}

	func allowAttributionRequests() {
		_ = attributionRequestAllowed.resolve(())
	}

	func sendAttributionRequest(request: DTOAttributionRequest, userData: UserData) -> Future<Data> {
		let f: FutureImpl<Data> = FutureImpl()
		attributionRequestAllowed.observe(using: { _ in
			_ = f.resolve(self.attributionResponseData(installId: request.user.installInstanceId, idfv: request.user.deviceId))
		})

		return f.toFuture()
	}

	func sendUserEvents(events: DTOUserEvent, userData: UserData) -> Future<Data> {
		return FutureImpl("{}".data(using: .utf8)).toFuture()
	}

	func sendCustomUserId(request: DTOPublishCustomUserIdRequest, userData: UserData) -> Future<Data> {
		XCTFail("Unexpected call to publish a Custom user id")

		return FutureImpl("{}".data(using: .utf8)).toFuture()
	}

	func sendFirebaseAppInstanceId(request: DTOPublishFirebaseAppInstanceIdRequest, userData: UserData) -> Future<Data> {
		XCTFail("Unexpected call to publish a Firebase app instance id")

		return FutureImpl("{}".data(using: .utf8)).toFuture()
	}

	func sendLogs(input: DTOLogInput, userData: UserData) -> Future<Data> {
		return FutureImpl("{}".data(using: .utf8)).toFuture()
	}

	func getSignedIpClaim(ipProtocol: IPProtocol, userData: UserData) -> Future<Data> {
		return FutureImpl(signedIpClaimResponse(ip: "127.0.0.1", type: "IPv4", token: "some random token")).toFuture()
	}

	func sendAnonymizeRequest(request: DTOAnonymizeRequest, userData: UserData) -> Future<Data> {
		return FutureImpl("{}".data(using: .utf8)).toFuture()
	}

	func sendTestAssignment(request: DTOSetExperimentVariantRequest, userData: UserData) -> Future<Data> {
		return FutureImpl("{}".data(using: .utf8)).toFuture()
	}

	func sendSetExperimentVariant(request: DTOSetExperimentVariantRequest, userData: UserData) -> Future<Data> {
		return FutureImpl("{}".data(using: .utf8)).toFuture()
	}

	func setRules(eventConfig: JustTrackSDK.AttributionOutputSdkConfig.Event) {
	}

	func getAssignments(parameters: GetAssignmentsParameters, userData: UserData) -> Future<AssignmentsResponse> {
		let data = "{\"assignments\":[]}".data(using: .utf8)!
		return FutureImpl(AssignmentsResponse(data: data, retryAfterSeconds: nil)).toFuture()
	}

	func postEnrollments(request: DTOPostEnrollmentRequest, userData: UserData) -> Future<Data> {
		return FutureImpl("{\"enrolledAssignments\":[]}".data(using: .utf8)).toFuture()
	}

	func signedIpClaimResponse(ip: String, type: String, token: String) -> Data {
		let response: [String: Any] = [
			"ip": ip,
			"type": type,
			"token": token,
		]

		return try! JSONSerialization.data(withJSONObject: response, options: [])
	}

	func attributionResponseData(installId newInstallId: String, idfv: String) -> Data {
		let testGroupIdValue: Int? = testGroupId ?? JustTrackSdkImpl.computeTestGroupId(idfv: idfv)
		let response: [String: Any] = [
			"user": [
				"installId": installId?.value ?? newInstallId,
				"type": "acquisition",
				"testGroup": testGroupIdValue as Any,
				"redownload": false,
			],
			"attribution": [
				"campaign": [
					"id": 42,
					"name": "Test Campaign",
					"type": "acquisition",
					"organic": false,
				] as [String: Any],
				"type": "mcoins",
				"channel": [
					"id": 43,
					"name": "Test Channel",
					"incent": true,
				] as [String: Any],
				"network": [
					"id": 44,
					"name": "Test Network",
				] as [String: Any],
				"attributedAt": formatDateSeconds(Date()),
				"createdAt": formatDateSeconds(Date()),
			] as [String: Any],
		]

		return try! JSONSerialization.data(withJSONObject: response, options: [])
	}
}

struct TestAdTrackingProvider: AdTrackingProvider {
	private let idfa: StringID?
	private let idfv: StringID?

	init(idfa: StringID?, idfv: StringID?) {
		self.idfa = idfa
		self.idfv = idfv
	}

	func provideIDFA() -> StringID? {
		return idfa
	}

	func provideIDFV() -> StringID? {
		return idfv
	}

	func requestTrackingAuthorization(requester: JustTrackSDK.AdTrackingPermissionRequester, _ onAuthorized: @escaping (Bool) -> Void) {
		onAuthorized(idfa != nil)
	}

	func setLogger(_ logger: any Logger) {
		// nop
	}
}
