import StoreKit
import XCTest

@testable import JustTrackSDK

final class JustTrackSdkTests: XCTestCase {
	static let trackingData = ("1-23456notatrackingid", "appsflyer")
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

	func testSdkReturnsCorrectErrorAfterReconnect() {
		let logger = LoggerImpl()
		let testHttpClient = TestAttributionHttpClient(changeInstallId: false, remainingFails: 7)
		let connectivityManager = TestConnectivityManager()
		sdk = try! JustTrackSdkImpl(

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
			XCTAssertEqual(response.campaign.id, "42")
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

	func testRefetchAttributionAfterFailure() {
		let testHttpClient = TestAttributionHttpClient(changeInstallId: false, remainingFails: 1)
		var attributionSettings = AttributionSettings()
		attributionSettings.attributionRetryDelaySeconds = 3
		sdk = try! JustTrackSdkImpl(
			attributionSettings: attributionSettings,
			logger: LoggerImpl(),
			httpClient: StubHttpClient(),
			attributionApi: testHttpClient,
			privacyApi: testHttpClient,
			eventApi: testHttpClient,
			logApi: testHttpClient,
			userPropertyApi: testHttpClient,
			remoteConfigApi: testHttpClient,
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
			httpClient: StubHttpClient(),
			attributionApi: testHttpClient,
			privacyApi: testHttpClient,
			eventApi: testHttpClient,
			logApi: testHttpClient,
			userPropertyApi: testHttpClient,
			remoteConfigApi: testHttpClient,
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
		let testApis = TestAttributionHttpClient()

		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: StubHttpClient(),
			attributionApi: testApis,
			privacyApi: testApis,
			eventApi: testApis,
			logApi: testApis,
			userPropertyApi: testApis,
			remoteConfigApi: testApis,
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
		let testApis = TestAttributionHttpClient()

		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: StubHttpClient(),
			attributionApi: testApis,
			privacyApi: testApis,
			eventApi: testApis,
			logApi: testApis,
			userPropertyApi: testApis,
			remoteConfigApi: testApis,
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
			forKey: "io.justtrack.attribution.customUserId"
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
			            "externalId": "17913",
			            "name": "default_ios_JustTrack iOS (ios)",
			            "type": "acquisition",
			            "organic": true
			        },
			        "sourceBundleId": null,
			        "sourceId": null,
			        "adsetId": null,
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
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
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
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
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
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
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
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
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
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
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
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
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
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
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
		let mockApis = MockHttpClient()
		sdk = try JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: StubHttpClient(),
			attributionApi: mockApis,
			privacyApi: mockApis,
			eventApi: mockApis,
			logApi: mockApis,
			userPropertyApi: mockApis,
			remoteConfigApi: mockApis,
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
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
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
			httpClient: StubHttpClient(),
			attributionApi: testHttpClient,
			privacyApi: testHttpClient,
			eventApi: testHttpClient,
			logApi: testHttpClient,
			userPropertyApi: testHttpClient,
			remoteConfigApi: testHttpClient,
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

	func testFirebaseAppInstanceIdIsNotSentTwiceWithSameValue() {
		var idsPublished = 0
		let mockFirebaseAppInstanceId = "mock_firebase_app_instance_id_dedup"
		let testHttpClient = TestAttributionHttpClient(
			changeInstallId: false,
			remainingFails: 0
		)
		testHttpClient.onFirebaseAppInstanceIdPublished = { request, _ in
			XCTAssertEqual(request.firebaseInstanceId, mockFirebaseAppInstanceId)
			idsPublished += 1
		}
		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: StubHttpClient(),
			attributionApi: testHttpClient,
			privacyApi: testHttpClient,
			eventApi: testHttpClient,
			logApi: testHttpClient,
			userPropertyApi: testHttpClient,
			remoteConfigApi: testHttpClient,
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
			sdk.set(firebaseAppInstanceId: mockFirebaseAppInstanceId).observe(using: { response in
				switch response {
				case .failure(let error):
					XCTFail(error.justTrackGetErrorDescription())
				case .success:
					XCTAssertEqual(idsPublished, 1, "Firebase app instance ID should only be sent once despite multiple calls with the same value")
					expectation.fulfill()
				}
			})
			waitForExpectations(timeout: 30)
		}
	}

	func testFirebaseAppInstanceIdIsSentAgainWithDifferentValue() {
		var idsPublished = 0
		var lastPublishedId: String?
		let firstId = "mock_firebase_app_instance_id_first"
		let secondId = "mock_firebase_app_instance_id_second"
		let testHttpClient = TestAttributionHttpClient(
			changeInstallId: false,
			remainingFails: 0
		)
		testHttpClient.onFirebaseAppInstanceIdPublished = { request, _ in
			idsPublished += 1
			lastPublishedId = request.firebaseInstanceId
		}
		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: StubHttpClient(),
			attributionApi: testHttpClient,
			privacyApi: testHttpClient,
			eventApi: testHttpClient,
			logApi: testHttpClient,
			userPropertyApi: testHttpClient,
			remoteConfigApi: testHttpClient,
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

		let expectation1 = self.expectation(description: "first set")
		sdk.set(firebaseAppInstanceId: firstId).observe(using: { response in
			switch response {
			case .failure(let error):
				XCTFail(error.justTrackGetErrorDescription())
			case .success:
				XCTAssertEqual(idsPublished, 1)
				XCTAssertEqual(lastPublishedId, firstId)
				expectation1.fulfill()
			}
		})
		waitForExpectations(timeout: 30)

		let expectation2 = self.expectation(description: "second set")
		sdk.set(firebaseAppInstanceId: secondId).observe(using: { response in
			switch response {
			case .failure(let error):
				XCTFail(error.justTrackGetErrorDescription())
			case .success:
				XCTAssertEqual(idsPublished, 2, "Firebase app instance ID should be sent again when the value changes")
				XCTAssertEqual(lastPublishedId, secondId)
				expectation2.fulfill()
			}
		})
		waitForExpectations(timeout: 30)
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
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
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
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
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
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
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
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
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
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
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
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
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

	// MARK: - handle(deeplink:) re-attribution tests

	func testHandleDeeplinkTriggersReAttributionWhenGbraidIsPresent() {
		let logger = LoggerImpl()
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		mockHttpClient.sendAttributionRequestResponseData = """
			{
			    "attribution": {
			        "channel": { "id": 57, "name": "direct", "incent": false },
			        "campaign": { "externalId": "17913", "name": "test", "type": "acquisition", "organic": true },
			        "attributedAt": "\(formatDateSeconds(Date()))",
			        "network": { "id": 26, "name": "Organic" }
			    },
			    "retargeting": null,
			    "user": {
			        "testGroup": 1,
			        "installId": "\(installId.value)",
			        "redownload": false,
			        "type": "acquisition"
			    }
			}
			""".data(using: .utf8)!
		let mockClaimsProvider = MockClaimsProvider()
		let mockAdTrackingProvider = TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv)
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: mockHttpClient,
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
			sessionManagerBuilder: { sdk in SessionManagerImpl(sdk) },
			connectivityManagerBuilder: { sdk in try! ConnectivityManagerImpl() },
			adTrackingProvider: mockAdTrackingProvider,
			skAdNetwork: MockSkAdNetwork.self,
			claimsProvider: mockClaimsProvider,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()

		let attributionCallsBeforeDeeplink = mockHttpClient.calls.filter {
			if case .sendAttributionRequest = $0 { return true }
			return false
		}.count
		XCTAssertEqual(attributionCallsBeforeDeeplink, 1, "Expected exactly 1 attribution request from start()")

		sdk.handle(deeplink: URL(string: "https://example.com/open?gbraid=abc123")!)

		let attributionCallsAfterDeeplink = mockHttpClient.calls.filter {
			if case .sendAttributionRequest = $0 { return true }
			return false
		}.count
		XCTAssertEqual(attributionCallsAfterDeeplink, 2, "Expected a second attribution request after receiving gbraid")
	}

	func testHandleDeeplinkDoesNotTriggerReAttributionWhenGbraidIsIdentical() {
		let logger = LoggerImpl()
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		mockHttpClient.sendAttributionRequestResponseData = """
			{
			    "attribution": {
			        "channel": { "id": 57, "name": "direct", "incent": false },
			        "campaign": { "externalId": "17913", "name": "test", "type": "acquisition", "organic": true },
			        "attributedAt": "\(formatDateSeconds(Date()))",
			        "network": { "id": 26, "name": "Organic" }
			    },
			    "retargeting": null,
			    "user": {
			        "testGroup": 1,
			        "installId": "\(installId.value)",
			        "redownload": false,
			        "type": "acquisition"
			    }
			}
			""".data(using: .utf8)!
		let mockClaimsProvider = MockClaimsProvider()
		let mockAdTrackingProvider = TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv)
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: logger,
			httpClient: mockHttpClient,
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
			sessionManagerBuilder: { sdk in SessionManagerImpl(sdk) },
			connectivityManagerBuilder: { sdk in try! ConnectivityManagerImpl() },
			adTrackingProvider: mockAdTrackingProvider,
			skAdNetwork: MockSkAdNetwork.self,
			claimsProvider: mockClaimsProvider,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()

		sdk.handle(deeplink: URL(string: "https://example.com/open?gbraid=abc123")!)

		let attributionCallsAfterFirstDeeplink = mockHttpClient.calls.filter {
			if case .sendAttributionRequest = $0 { return true }
			return false
		}.count
		XCTAssertEqual(attributionCallsAfterFirstDeeplink, 2, "Expected 2 attribution requests (start + first gbraid)")

		sdk.handle(deeplink: URL(string: "https://example.com/open?gbraid=abc123")!)

		let attributionCallsAfterSecondDeeplink = mockHttpClient.calls.filter {
			if case .sendAttributionRequest = $0 { return true }
			return false
		}.count
		XCTAssertEqual(attributionCallsAfterSecondDeeplink, 2, "Expected still 2 attribution requests (identical gbraid should not trigger re-attribution)")
	}

	// MARK: - Group A: Validation Tests

	func testSetUserIdFailsWithEmptyString() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		mockHttpClient.reset()

		let expectation = self.expectation(description: #function)
		sdk.set(userId: "").observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure for empty userId")
			case let .failure(error):
				XCTAssertTrue(error is InvalidFieldError)
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
		XCTAssertTrue(mockHttpClient.calls.isEmpty, "No API call should be made for invalid userId")
	}

	func testSetUserIdFailsWhenTooLong() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		mockHttpClient.reset()

		let expectation = self.expectation(description: #function)
		sdk.set(userId: String(repeating: "a", count: 4096)).observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure for userId that is too long")
			case let .failure(error):
				XCTAssertTrue(error is InvalidFieldError)
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
		XCTAssertTrue(mockHttpClient.calls.isEmpty, "No API call should be made for invalid userId")
	}

	func testSetUserIdFailsWithNonAsciiCharacter() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		mockHttpClient.reset()

		let expectation = self.expectation(description: #function)
		sdk.set(userId: "müller").observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure for non-ASCII userId")
			case let .failure(error):
				XCTAssertTrue(error is InvalidFieldError)
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
		XCTAssertTrue(mockHttpClient.calls.isEmpty, "No API call should be made for invalid userId")
	}

	func testSetUserIdSucceedsAtMaxLength() {
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		Store().set(installId: installId)
		mockHttpClient.sendAttributionRequestResponseData = makeAttributionResponseData(installId: installId.value)
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		mockHttpClient.reset()
		mockHttpClient.sendAttributionRequestResponseData = makeAttributionResponseData(installId: installId.value)

		let expectation = self.expectation(description: #function)
		sdk.set(userId: String(repeating: "a", count: 4095)).observe { result in
			switch result {
			case let .failure(error):
				XCTFail("Expected success at max length userId, got: \(error)")
			case .success:
				break
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
	}

	func testSetFirebaseAppInstanceIdFailsWhenTooShort() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		mockHttpClient.reset()

		let expectation = self.expectation(description: #function)
		sdk.set(firebaseAppInstanceId: "short!!").observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure for too-short firebaseAppInstanceId")
			case let .failure(error):
				XCTAssertTrue(error is InvalidFieldError)
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
		XCTAssertTrue(mockHttpClient.calls.isEmpty, "No API call should be made for invalid firebaseAppInstanceId")
	}

	func testSetFirebaseAppInstanceIdFailsWhenTooLong() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		mockHttpClient.reset()

		let expectation = self.expectation(description: #function)
		sdk.set(firebaseAppInstanceId: String(repeating: "a", count: 256)).observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure for too-long firebaseAppInstanceId")
			case let .failure(error):
				XCTAssertTrue(error is InvalidFieldError)
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
		XCTAssertTrue(mockHttpClient.calls.isEmpty, "No API call should be made for invalid firebaseAppInstanceId")
	}

	func testSetFirebaseAppInstanceIdFailsWithNonAscii() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		mockHttpClient.reset()

		let expectation = self.expectation(description: #function)
		sdk.set(firebaseAppInstanceId: "firebase\u{1F525}id!!").observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure for non-ASCII firebaseAppInstanceId")
			case let .failure(error):
				XCTAssertTrue(error is InvalidFieldError)
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
		XCTAssertTrue(mockHttpClient.calls.isEmpty, "No API call should be made for invalid firebaseAppInstanceId")
	}

	func testSetFirebaseAppInstanceIdSucceedsAtMinLength() {
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		mockHttpClient.reset()

		let expectation = self.expectation(description: #function)
		sdk.set(firebaseAppInstanceId: "12345678").observe { result in
			switch result {
			case let .failure(error):
				XCTFail("Expected success at min length firebaseAppInstanceId, got: \(error)")
			case .success:
				break
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
	}

	func testSetExperimentVariantFailsWithEmptyExperimentName() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		mockHttpClient.reset()

		let expectation = self.expectation(description: #function)
		sdk.setExperimentVariant(experiment: "", variant: "variant_a", tags: [], happenedAt: Date()).observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure for empty experiment name")
			case let .failure(error):
				XCTAssertTrue(error is InvalidFieldError)
				let fieldError = error as! InvalidFieldError
				XCTAssertTrue(fieldError.description.contains("experiment"))
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
		XCTAssertTrue(mockHttpClient.calls.isEmpty, "No API call should be made for invalid experiment name")
	}

	func testSetExperimentVariantFailsWithEmptyVariant() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		mockHttpClient.reset()

		let expectation = self.expectation(description: #function)
		sdk.setExperimentVariant(experiment: "valid_experiment", variant: "", tags: [], happenedAt: Date()).observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure for empty variant")
			case let .failure(error):
				XCTAssertTrue(error is InvalidFieldError)
				let fieldError = error as! InvalidFieldError
				XCTAssertTrue(fieldError.description.contains("variant"))
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
		XCTAssertTrue(mockHttpClient.calls.isEmpty, "No API call should be made for invalid variant")
	}

	func testSetExperimentVariantFailsWithNonAsciiExperimentName() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		mockHttpClient.reset()

		let expectation = self.expectation(description: #function)
		sdk.setExperimentVariant(experiment: "tëst_experiment", variant: "variant_a", tags: [], happenedAt: Date()).observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure for non-ASCII experiment name")
			case let .failure(error):
				XCTAssertTrue(error is InvalidFieldError)
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
		XCTAssertTrue(mockHttpClient.calls.isEmpty, "No API call should be made for invalid experiment name")
	}

	func testSetExperimentVariantFailsWithTooManyTags() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		mockHttpClient.reset()

		let expectation = self.expectation(description: #function)
		let tooManyTags = ["tag1", "tag2", "tag3", "tag4", "tag5", "tag6"]
		sdk.setExperimentVariant(experiment: "valid_experiment", variant: "variant_a", tags: tooManyTags, happenedAt: Date()).observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure for too many tags")
			case let .failure(error):
				XCTAssertFalse(error is InvalidFieldError, "Too-many-tags error should not be InvalidFieldError but JustTrackError")
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
		XCTAssertTrue(mockHttpClient.calls.isEmpty, "No API call should be made when tags exceed limit")
	}

	func testSetExperimentVariantFailsWithEmptyTag() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		mockHttpClient.reset()

		let expectation = self.expectation(description: #function)
		sdk.setExperimentVariant(experiment: "valid_experiment", variant: "variant_a", tags: ["valid", ""], happenedAt: Date()).observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure for empty tag")
			case let .failure(error):
				XCTAssertTrue(error is InvalidFieldError)
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
		XCTAssertTrue(mockHttpClient.calls.isEmpty, "No API call should be made for invalid tag")
	}

	func testSetExperimentVariantWithNilHappenedAtSucceeds() {
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		mockHttpClient.reset()

		let expectation = self.expectation(description: #function)
		sdk.setExperimentVariant(experiment: "valid_experiment", variant: "variant_a", tags: [], happenedAt: nil).observe { result in
			switch result {
			case let .failure(error):
				XCTFail("Expected success with nil happenedAt, got: \(error)")
			case .success:
				XCTAssertEqual(mockHttpClient.calls.count, 1)
				if case let .sendSetExperimentVariant(request, _) = mockHttpClient.calls[0] {
					XCTAssertNil(request.happenedAt, "happenedAt should be nil in request when not provided")
				} else {
					XCTFail("Expected sendSetExperimentVariant call")
				}
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
	}

	// MARK: - Group B: Stopped SDK Tests

	func testTrackEventFailsWhenSdkIsStopped() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		sdk.stop()

		let expectation = self.expectation(description: #function)
		sdk.track(event: AppEvent("test_event")).observe { result in
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

	func testAnonymizeFailsWhenSdkIsStopped() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		sdk.stop()

		let expectation = self.expectation(description: #function)
		sdk.anonymize().observe { result in
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

	func testForwardAdImpressionFailsWhenSdkIsStopped() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		sdk.stop()

		let expectation = self.expectation(description: #function)
		sdk.forward(adImpression: AdImpression(unit: .banner, sdkName: "test")).observe { result in
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

	func testGetInstallInstanceIdFailsWhenSdkIsStopped() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		sdk.stop()

		let expectation = self.expectation(description: #function)
		sdk.getInstallInstanceId().observe { result in
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

	func testGetAdvertiserIdInfoFailsWhenSdkIsStopped() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		sdk.stop()

		let expectation = self.expectation(description: #function)
		sdk.getAdvertiserIdInfo().observe { result in
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

	func testSetExperimentVariantFailsWhenSdkIsStoppedWithMocks() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		sdk.stop()

		let expectation = self.expectation(description: #function)
		sdk.setExperimentVariant(experiment: "valid_experiment", variant: "variant_a", tags: [], happenedAt: Date()).observe { result in
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

	func testStopSetsIsRunningToFalse() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()
		XCTAssertTrue(sdk.isRunning())

		sdk.stop()

		XCTAssertFalse(sdk.isRunning())
	}

	func testStartTwiceDoesNotSendExtraAttributionRequest() {
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()

		let attributionCallCountAfterFirst = attributionRequestCount(in: mockHttpClient.calls)

		// second start() call should be a no-op
		sdk.start()

		XCTAssertEqual(
			attributionRequestCount(in: mockHttpClient.calls),
			attributionCallCountAfterFirst,
			"Second start() call should not trigger a second attribution request"
		)
	}

	// MARK: - Group C: handle(deeplink:) and ODM Info Tests

	func testHandleDeeplinkWithNoGbraidDoesNotTriggerReAttribution() {
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		mockHttpClient.sendAttributionRequestResponseData = makeAttributionResponseData(installId: installId.value)
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()

		let attributionCallsBefore = attributionRequestCount(in: mockHttpClient.calls)

		sdk.handle(deeplink: URL(string: "https://example.com/open?utm_source=google")!)

		XCTAssertEqual(
			attributionRequestCount(in: mockHttpClient.calls),
			attributionCallsBefore,
			"URL without gbraid should not trigger re-attribution"
		)
	}

	func testHandleDeeplinkGbraidValueAppearsInAttributionRequest() {
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		mockHttpClient.sendAttributionRequestResponseData = makeAttributionResponseData(installId: installId.value)
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()

		let countBeforeDeeplink = attributionRequestCount(in: mockHttpClient.calls)

		sdk.handle(deeplink: URL(string: "https://example.com/open?gbraid=abc123")!)

		XCTAssertGreaterThan(
			attributionRequestCount(in: mockHttpClient.calls),
			countBeforeDeeplink,
			"gbraid deeplink should trigger a re-attribution request"
		)
		let attributionRequests = mockHttpClient.calls.compactMap { call -> DTOAttributionRequest? in
			if case let .sendAttributionRequest(request, _) = call { return request }
			return nil
		}
		let requestWithGbraid = attributionRequests.first { $0.parameters["gbraid"] == "abc123" }
		XCTAssertNotNil(requestWithGbraid, "gbraid value should be included in attribution request parameters")
	}

	func testHandleDeeplinkNewGbraidAfterIdenticalTriggersReAttribution() {
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		mockHttpClient.sendAttributionRequestResponseData = makeAttributionResponseData(installId: installId.value)
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()

		let countAfterStart = attributionRequestCount(in: mockHttpClient.calls)

		// First gbraid → re-attribution
		sdk.handle(deeplink: URL(string: "https://example.com/open?gbraid=abc123")!)
		let countAfterFirstGbraid = attributionRequestCount(in: mockHttpClient.calls)
		XCTAssertGreaterThan(countAfterFirstGbraid, countAfterStart, "First gbraid should trigger re-attribution")

		// Same gbraid again → no additional request
		sdk.handle(deeplink: URL(string: "https://example.com/open?gbraid=abc123")!)
		XCTAssertEqual(
			attributionRequestCount(in: mockHttpClient.calls),
			countAfterFirstGbraid,
			"Identical gbraid should not trigger re-attribution"
		)

		// Different gbraid → re-attribution again
		sdk.handle(deeplink: URL(string: "https://example.com/open?gbraid=xyz789")!)
		XCTAssertGreaterThan(
			attributionRequestCount(in: mockHttpClient.calls),
			countAfterFirstGbraid,
			"New gbraid should trigger re-attribution again"
		)
	}

	func testSetOdmInfoTriggersReAttribution() {
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		mockHttpClient.sendAttributionRequestResponseData = makeAttributionResponseData(installId: installId.value)
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()

		let attributionCallsBefore = attributionRequestCount(in: mockHttpClient.calls)

		let expectation = self.expectation(description: #function)
		sdk.set(odmInfo: "some_odm_value").observe { _ in
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)

		let allAttributionRequests = mockHttpClient.calls.compactMap { call -> DTOAttributionRequest? in
			if case let .sendAttributionRequest(request, _) = call { return request }
			return nil
		}
		XCTAssertGreaterThan(
			attributionRequestCount(in: mockHttpClient.calls),
			attributionCallsBefore,
			"set(odmInfo:) should trigger a re-attribution"
		)
		let lastRequest = allAttributionRequests.last
		XCTAssertEqual(lastRequest?.parameters["odmInfo"], "some_odm_value", "odmInfo should appear in attribution request parameters")
	}

	func testSetOdmInfoDeduplication() {
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		mockHttpClient.sendAttributionRequestResponseData = makeAttributionResponseData(installId: installId.value)
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()

		// First odmInfo call triggers re-attribution
		let expectation1 = self.expectation(description: "first odmInfo")
		sdk.set(odmInfo: "same_value").observe { _ in expectation1.fulfill() }
		waitForExpectations(timeout: 5)
		let countAfterFirst = attributionRequestCount(in: mockHttpClient.calls)

		// Same odmInfo again should NOT trigger another attribution request
		let expectation2 = self.expectation(description: "second odmInfo")
		sdk.set(odmInfo: "same_value").observe { _ in expectation2.fulfill() }
		waitForExpectations(timeout: 5)

		XCTAssertEqual(
			attributionRequestCount(in: mockHttpClient.calls),
			countAfterFirst,
			"Setting the same odmInfo twice should not trigger a second re-attribution"
		)
	}

	// MARK: - Group D: getInstallInstanceId & getAdvertiserIdInfo Tests

	func testGetInstallInstanceIdReturnsStoredId() {
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		mockHttpClient.sendAttributionRequestResponseData = makeAttributionResponseData(installId: installId.value)
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()

		// Wait for attribution to complete so installId is resolved
		let attributionExpectation = self.expectation(description: "attribution")
		sdk.attribution.observe { _ in attributionExpectation.fulfill() }
		waitForExpectations(timeout: 5)

		let expectation = self.expectation(description: #function)
		sdk.getInstallInstanceId().observe { result in
			switch result {
			case let .failure(error):
				XCTFail("Expected success, got: \(error)")
			case let .success(id):
				XCTAssertFalse(id.isEmpty, "installInstanceId should not be empty")
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
	}

	func testGetAdvertiserIdInfoReturnsIdfaWhenPresent() {
		let mockHttpClient = MockHttpClient()
		let idfa = StringID()
		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: TestAdTrackingProvider(idfa: idfa, idfv: Self.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()

		let expectation = self.expectation(description: #function)
		sdk.getAdvertiserIdInfo().observe { result in
			switch result {
			case let .failure(error):
				XCTFail("Expected success, got: \(error)")
			case let .success(info):
				XCTAssertFalse(info.isLimitedAdTracking, "Should not be limited when IDFA is present")
				XCTAssertEqual(info.advertiserId, idfa.value, "advertiserId should match the provided IDFA")
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
	}

	func testGetAdvertiserIdInfoReturnsNilIdfaWhenLimitedTracking() {
		let mockHttpClient = MockHttpClient()
		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: TestAdTrackingProvider(idfa: nil, idfv: Self.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()

		let expectation = self.expectation(description: #function)
		sdk.getAdvertiserIdInfo().observe { result in
			switch result {
			case let .failure(error):
				XCTFail("Expected success, got: \(error)")
			case let .success(info):
				XCTAssertTrue(info.isLimitedAdTracking, "Should be limited when IDFA is nil")
				XCTAssertNil(info.advertiserId, "advertiserId should be nil when IDFA is not available")
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
	}

	// MARK: - Group E: forward(adImpression:) Tests

	func testForwardAdImpressionWithNegativeRevenueReturnsError() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()

		let impression = AdImpression(unit: .banner, sdkName: "test_network")
			.set(revenue: try! Money(value: -1.0, currency: "USD"))

		let expectation = self.expectation(description: #function)
		sdk.forward(adImpression: impression).observe { result in
			switch result {
			case .success:
				XCTFail("Expected failure for negative revenue")
			case let .failure(error):
				XCTAssertEqual(error as! JustTrackError, .custom("Negative revenue for AdFormat"))
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 5)
	}

	func testForwardAdImpressionEmitsJtAdEvent() {
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		mockHttpClient.sendAttributionRequestResponseData = makeAttributionResponseData(installId: installId.value)
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()

		// Wait for attribution so the SDK is fully initialized
		let attributionExpectation = self.expectation(description: "attribution")
		sdk.attribution.observe { _ in attributionExpectation.fulfill() }
		waitForExpectations(timeout: 10)

		let impression = AdImpression(unit: .banner, sdkName: "test_network")

		let expectation = self.expectation(description: #function)
		sdk.forward(adImpression: impression).observe { result in
			switch result {
			case let .failure(error):
				XCTFail("Expected success, got: \(error)")
			case .success:
				break
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 10)

		// Allow the event queue to flush
		Thread.sleep(forTimeInterval: 0.5)

		let sentEvents = mockHttpClient.calls.compactMap { call -> DTOUserEvent? in
			if case let .sendUserEvents(events, _) = call { return events }
			return nil
		}
		let hasJtAdEvent = sentEvents.flatMap { $0.events }.contains { $0.name == "jt_ad" }
		XCTAssertTrue(hasJtAdEvent, "Expected a jt_ad event to be sent via sendUserEvents")
	}

	// MARK: - Group F: integrate(with:) Adapter Tests

	func testIntegrateAdapterAfterStartCallsIntegrateImmediately() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()

		let adapter = MockJustTrackSDKAdapter()
		_ = sdk.integrate(with: adapter)

		XCTAssertEqual(adapter.integrateCallCount, 1, "integrate(with:) called after start() should integrate immediately")
	}

	func testIntegrateAdapterBeforeStartCallsIntegrateOnStart() {
		let mockHttpClient = MockHttpClient()
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)

		let adapter = MockJustTrackSDKAdapter()
		_ = sdk.integrate(with: adapter)

		XCTAssertEqual(adapter.integrateCallCount, 0, "integrate(with:) before start() should not call integrate yet")

		sdk.start()

		XCTAssertEqual(adapter.integrateCallCount, 1, "integrate(with:) should be called after start()")
	}

	// MARK: - Group G: Attribution Caching Test

	func testAttributionCacheUsedOnReInitWithoutNetworkCall() {
		// After a successful start, attribution should be persisted to the store.
		// Verify that the store contains attribution data after a network response.
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		mockHttpClient.sendAttributionRequestResponseData = makeAttributionResponseData(installId: installId.value)
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()

		// Wait for attribution to complete
		let expectation = self.expectation(description: #function)
		sdk.attribution.observe { _ in expectation.fulfill() }
		waitForExpectations(timeout: 5)

		// Verify the attribution was cached in the Store
		let storedOutput = Store().getStoredOutput()
		XCTAssertNotNil(storedOutput, "Attribution should be cached in the Store after a successful start")
		let cachedInstallId = (storedOutput?.attributionResponse as? CompleteAttributionResponse)?.installId
		XCTAssertEqual(
			cachedInstallId,
			installId,
			"Cached attribution should contain the correct installId"
		)
	}

	// MARK: - Group H: register(retargetingParametersListener:) Tests

	func testRetargetingListenerIsCalledWhenAttributionContainsRetargeting() {
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		mockHttpClient.sendAttributionRequestResponseData = makeAttributionResponseDataWithRetargeting(
			installId: installId.value,
			retargetingUrl: "https://example.com/retarget",
			retargetingAttributes: ["source": "push"]
		)
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)

		var receivedRetargeting: RetargetingParameters?
		let expectation = self.expectation(description: #function)
		let subscription = sdk.register(retargetingParametersListener: { params in
			receivedRetargeting = params
			expectation.fulfill()
		})

		sdk.start()
		waitForExpectations(timeout: 5)
		subscription.unsubscribe()

		XCTAssertNotNil(receivedRetargeting, "Retargeting listener should have been called")
	}

	func testRetargetingListenerIsNotCalledWhenAttributionHasNoRetargeting() {
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		mockHttpClient.sendAttributionRequestResponseData = makeAttributionResponseData(installId: installId.value)
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()

		var retargetingListenerCalled = false
		let subscription = sdk.register(retargetingParametersListener: { _ in
			retargetingListenerCalled = true
		})

		// Wait for attribution to resolve
		let attributionExpectation = self.expectation(description: "attribution")
		sdk.attribution.observe { _ in attributionExpectation.fulfill() }
		waitForExpectations(timeout: 5)

		// Give any async callbacks time to fire
		Thread.sleep(forTimeInterval: 0.3)
		subscription.unsubscribe()

		XCTAssertFalse(retargetingListenerCalled, "Retargeting listener should NOT be called when retargeting is absent")
	}

	// MARK: - Group I: set(firebaseAppInstanceId:) Before Start

	func testFirebaseAppInstanceIdSetBeforeStartIsSentOnStart() {
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		let userId = StringID()
		Store().set(userId: userId)
		Store().set(installId: installId)
		mockHttpClient.sendAttributionRequestResponseData = makeAttributionResponseData(installId: installId.value)
		sdk = try! makeSdk(mockHttpClient: mockHttpClient)

		// Set firebase ID before starting the SDK
		_ = sdk.set(firebaseAppInstanceId: "firebase_before_start_id")

		XCTAssertTrue(
			mockHttpClient.calls.filter {
				if case .sendFirebaseAppInstanceId = $0 { return true }
				return false
			}.isEmpty,
			"Firebase ID should not be sent before start()"
		)

		sdk.start()

		// Wait for attribution + firebase send
		let expectation = self.expectation(description: #function)
		sdk.attribution.observe { _ in expectation.fulfill() }
		waitForExpectations(timeout: 5)
		Thread.sleep(forTimeInterval: 0.5)

		let firebaseCalls = mockHttpClient.calls.filter {
			if case .sendFirebaseAppInstanceId = $0 { return true }
			return false
		}
		XCTAssertFalse(firebaseCalls.isEmpty, "Firebase app instance ID set before start() should be sent after start()")
	}

	// MARK: - Group J: checkNativeCrashReport closure tests

	func testNativeCrashReportExceptionPublishesMetricAndLogsError() throws {
		let mockLogger = MockLogger()
		let crashReporter = MockCrashReporter()
		crashReporter.nativeCrashReportStub = .success(
			NativeCrashReport(
				timestamp: 1_000_000,
				reportType: .exception,
				name: "NSException",
				reason: "Something went wrong",
				callStack: "frame 0\nframe 1",
				signalInfo: nil
			)
		)
		sdk = try JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: mockLogger,
			httpClient: StubHttpClient(),
			attributionApi: MockHttpClient(),
			privacyApi: MockHttpClient(),
			eventApi: MockHttpClient(),
			logApi: MockHttpClient(),
			userPropertyApi: MockHttpClient(),
			remoteConfigApi: MockHttpClient(),
			sessionManagerBuilder: { SessionManagerImpl($0) },
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: TestAdTrackingProvider(idfa: nil, idfv: Self.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			claimsProvider: MockClaimsProvider(),
			crashReporter: crashReporter,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()

		let metrics = mockLogger.entries.filter { $0.level == .metric && $0.message == "crash" }
		XCTAssertEqual(metrics.count, 1, "Expected one 'crash' metric to be published for exception report")

		let errors = mockLogger.entries.filter {
			$0.level == .error && $0.message.contains("Application shutdown due to crash")
		}
		XCTAssertEqual(errors.count, 1, "Expected one error log for exception crash report")
	}

	func testNativeCrashReportSignalPublishesMetricAndLogsError() throws {
		let mockLogger = MockLogger()
		let crashReporter = MockCrashReporter()
		crashReporter.nativeCrashReportStub = .success(
			NativeCrashReport(
				timestamp: 2_000_000,
				reportType: .signal,
				name: "SIGSEGV",
				reason: nil,
				callStack: "frame 0\nframe 1",
				signalInfo: NativeCrashReport.SignalInfo(
					errorNumber: "0",
					signalCode: "1",
					signalNumber: "11",
					sendingProcess: "0",
					senderRuid: "0",
					exitValue: "0",
					signalValue: "0",
					faultingAddress: "0x0"
				)
			)
		)
		sdk = try JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: mockLogger,
			httpClient: StubHttpClient(),
			attributionApi: MockHttpClient(),
			privacyApi: MockHttpClient(),
			eventApi: MockHttpClient(),
			logApi: MockHttpClient(),
			userPropertyApi: MockHttpClient(),
			remoteConfigApi: MockHttpClient(),
			sessionManagerBuilder: { SessionManagerImpl($0) },
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: TestAdTrackingProvider(idfa: nil, idfv: Self.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			claimsProvider: MockClaimsProvider(),
			crashReporter: crashReporter,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()

		let metrics = mockLogger.entries.filter { $0.level == .metric && $0.message == "crash" }
		XCTAssertEqual(metrics.count, 1, "Expected one 'crash' metric to be published for signal report")

		let errors = mockLogger.entries.filter {
			$0.level == .error && $0.message.contains("Application shutdown due to crash")
		}
		XCTAssertEqual(errors.count, 1, "Expected one error log for signal crash report")
	}

	func testNativeCrashReportFailureLogsError() throws {
		let mockLogger = MockLogger()
		let crashReporter = MockCrashReporter()
		crashReporter.nativeCrashReportStub = .failure(JustTrackError.custom("simulated native crash report error"))
		sdk = try JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: mockLogger,
			httpClient: StubHttpClient(),
			attributionApi: MockHttpClient(),
			privacyApi: MockHttpClient(),
			eventApi: MockHttpClient(),
			logApi: MockHttpClient(),
			userPropertyApi: MockHttpClient(),
			remoteConfigApi: MockHttpClient(),
			sessionManagerBuilder: { SessionManagerImpl($0) },
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: TestAdTrackingProvider(idfa: nil, idfv: Self.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			claimsProvider: MockClaimsProvider(),
			crashReporter: crashReporter,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()

		let errors = mockLogger.entries.filter {
			$0.level == .error && $0.message.contains("An error during retrieving a native crash report received")
		}
		XCTAssertEqual(errors.count, 1, "Expected one error log when native crash report retrieval fails")

		let metrics = mockLogger.entries.filter { $0.level == .metric && $0.message == "crash" }
		XCTAssertTrue(metrics.isEmpty, "No 'crash' metric should be published on native crash report failure")
	}

	// MARK: - register(preliminaryRetargetingParametersListener:)

	func testRegisterPreliminaryRetargetingParametersListenerReturnsSubscription() throws {
		sdk = try makeSdk(mockHttpClient: MockHttpClient())
		let subscription = (sdk as! JustTrackSdkImpl).register(preliminaryRetargetingParametersListener: { _ in })
		subscription.unsubscribe()
	}

	// MARK: - deprecated publish(event:) wrapper

	func testDeprecatedPublishEventDelegatesToTrack() throws {
		sdk = try makeSdk(mockHttpClient: MockHttpClient())
		// Before start(), track() rejects with .stopped. We only need to
		// exercise the wrapper; the rejection path proves it forwards.
		let event = JtAppOpenEvent(sessionId: "s", duration: 1, unit: .milliseconds, happenedAt: Date())
		let future = (sdk as! JustTrackSdkImpl).publish(event: event)
		let expectation = self.expectation(description: #function)
		future.observe { result in
			if case .failure = result {
				expectation.fulfill()
			} else {
				XCTFail("expected rejection before start")
			}
		}
		wait(for: [expectation], timeout: 5)
	}

	// MARK: - applicationWillTerminate

	func testApplicationWillTerminateIsIdempotent() throws {
		sdk = try makeSdk(mockHttpClient: MockHttpClient())
		sdk.start()
		(sdk as! JustTrackSdkImpl).applicationWillTerminate()
		// Second call after shutdown must not crash.
		(sdk as! JustTrackSdkImpl).applicationWillTerminate()
	}

	// MARK: - forward(transactionId:productId:quantity:)

	@available(iOS 15.0, *)
	func testForwardTransactionIdRejectedWhenNotRunning() throws {
		sdk = try makeSdk(mockHttpClient: MockHttpClient())
		let result = (sdk as! JustTrackSdkImpl).forward(transactionId: "123", productId: "p", quantity: 1)
		guard case .failure(let error) = result else {
			XCTFail("expected failure when not running")
			return
		}
		XCTAssertEqual(
			(error as? JustTrackError)?.justTrackGetErrorDescription(),
			JustTrackError.stopped.justTrackGetErrorDescription()
		)
	}

	@available(iOS 15.0, *)
	func testForwardTransactionIdRejectsInvalidId() throws {
		sdk = try makeSdk(mockHttpClient: MockHttpClient())
		sdk.start()
		let result = (sdk as! JustTrackSdkImpl).forward(transactionId: "not-a-uint64", productId: "p", quantity: 1)
		guard case .failure(let error) = result else {
			XCTFail("expected failure for invalid transactionId")
			return
		}
		XCTAssertTrue(
			((error as? JustTrackError)?.justTrackGetErrorDescription() ?? "").contains("Wrong transactionId")
		)
	}

	@available(iOS 15.0, *)
	func testForwardTransactionIdSuccess() throws {
		sdk = try makeSdk(mockHttpClient: MockHttpClient())
		sdk.start()
		let result = (sdk as! JustTrackSdkImpl).forward(transactionId: "42", productId: "com.example.product", quantity: 2)
		if case .failure(let error) = result {
			XCTFail("unexpected failure: \(error)")
		}
	}

	// MARK: - start(config:) after stop hits the already-started warning

	func testStartAfterStopHitsAlreadyBeenStartedBranch() throws {
		sdk = try makeSdk(mockHttpClient: MockHttpClient())
		sdk.start()
		XCTAssertTrue(sdk.isRunning())
		(sdk as! JustTrackSdkImpl).stop()
		XCTAssertFalse(sdk.isRunning())
		// Second start: !isStarted && hasAlreadyBeenStarted → warning branch.
		sdk.start()
		XCTAssertTrue(sdk.isRunning())
	}

	// MARK: - getUserEventQueue fallback after shutdown

	func testGetUserEventQueueReconstructsAfterShutdown() throws {
		sdk = try makeSdk(mockHttpClient: MockHttpClient())
		sdk.start()
		sdk.shutdown()
		let queue = (sdk as! JustTrackSdkImpl).getUserEventQueue()
		let queue2 = (sdk as! JustTrackSdkImpl).getUserEventQueue()
		XCTAssertTrue(queue === queue2, "Second access must return the cached queue")
	}

	// MARK: - integrate(with:) before start drains pendingAdapters

	func testIntegrateBeforeStartDrainsOnStart() throws {
		sdk = try makeSdk(mockHttpClient: MockHttpClient())
		let adapter = MockJustTrackSDKAdapter()
		let future = sdk.integrate(with: adapter)
		XCTAssertEqual(adapter.integrateCallCount, 0)

		let expectation = self.expectation(description: #function)
		future.observe { result in
			if case .success = result { expectation.fulfill() } else { XCTFail("expected success") }
		}

		sdk.start()
		wait(for: [expectation], timeout: 5)
		XCTAssertEqual(adapter.integrateCallCount, 1)
	}

	func testIntegrateBeforeStartPropagatesAdapterFailure() throws {
		sdk = try makeSdk(mockHttpClient: MockHttpClient())
		let adapter = MockJustTrackSDKAdapter()
		struct AdapterError: Error {}
		adapter.integrateStub = { _, _ in FutureImpl<Void>().reject(AdapterError()) }
		let future = sdk.integrate(with: adapter)

		let expectation = self.expectation(description: #function)
		future.observe { result in
			if case .failure = result { expectation.fulfill() } else { XCTFail("expected failure") }
		}

		sdk.start()
		wait(for: [expectation], timeout: 5)
	}

	// MARK: - start(config:) with userId and trackingInfo

	func testStartAppliesConfigUserIdAndTrackingInfo() throws {
		let mockHttpClient = MockHttpClient()
		var config = JustTrackSdkConfig.default
		try config.set(userId: "explicit-user-id")
		config.trackingInfo = try JustTrackSdkConfig.TrackingInfo(id: "tid-1", provider: "appsflyer")

		sdk = try JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: config,
			manualStart: true
		)
		sdk.start()
		XCTAssertTrue(sdk.isRunning())
	}

	// MARK: - anonymize() failure paths

	func testAnonymizeRejectedWhenSdkNotRunning() throws {
		sdk = try makeSdk(mockHttpClient: MockHttpClient())
		// not started yet
		let expectation = self.expectation(description: #function)
		sdk.anonymize().observe { result in
			if case .failure(let error) = result,
				(error as? JustTrackError)?.justTrackGetErrorDescription() == JustTrackError.stopped.justTrackGetErrorDescription()
			{
				expectation.fulfill()
			} else {
				XCTFail("expected .stopped, got: \(result)")
			}
		}
		wait(for: [expectation], timeout: 5)
	}

	func testAnonymizePropagatesPrivacyApiFailure() throws {
		let mockHttpClient = MockHttpClient()
		let failingPrivacyApi = FailingPrivacyApi()
		sdk = try JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: failingPrivacyApi,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()

		let expectation = self.expectation(description: #function)
		sdk.anonymize().observe { result in
			if case .failure(let error) = result, error is FailingPrivacyApi.AnonymizeError {
				expectation.fulfill()
			} else {
				XCTFail("expected FailingPrivacyApi.AnonymizeError, got: \(result)")
			}
		}
		wait(for: [expectation], timeout: 5)
	}

	// MARK: - track(event:) early-exit branches

	func testTrackInvalidEventReturnsValidationError() throws {
		sdk = try makeSdk(mockHttpClient: MockHttpClient())
		sdk.start()
		let invalidEvent = AppEvent("")  // empty name → validate() throws
		let expectation = self.expectation(description: #function)
		sdk.track(event: invalidEvent).observe { result in
			if case .failure(let error) = result, error is InvalidFieldError {
				expectation.fulfill()
			} else {
				XCTFail("expected InvalidFieldError, got: \(result)")
			}
		}
		wait(for: [expectation], timeout: 5)
	}

	func testTrackAfterShutdownReturnsSdkShutdownError() throws {
		sdk = try makeSdk(mockHttpClient: MockHttpClient())
		sdk.start()
		// shutdown() nils the sessionManager but does not flip isStarted via stop().
		// So `isRunning()` still returns true, and we fall through to the
		// `guard let sessionManager` rejection.
		sdk.shutdown()
		XCTAssertTrue(sdk.isRunning())
		let expectation = self.expectation(description: #function)
		sdk.track(event: AppEvent("an_event")).observe { result in
			if case .failure(let error) = result, error is SdkShutdownError {
				expectation.fulfill()
			} else {
				XCTFail("expected SdkShutdownError, got: \(result)")
			}
		}
		wait(for: [expectation], timeout: 5)
	}

	// MARK: - Connection tracking

	func testTrackEventAttachesConnectionTypeDimensionWhenEnabled() throws {
		let connectivityManager = TestConnectivityManager()
		connectivityManager.connectionType = .wifi
		let testHttpClient = TestAttributionHttpClient(changeInstallId: false, remainingFails: 0)
		let expectation = self.expectation(description: #function)

		testHttpClient.onEventsPublished = { dto in
			let userEvent = dto.events.first { $0.name == "test_connection_event" }
			if let userEvent {
				XCTAssertEqual(userEvent.dimensions["jt_connection_type"], "online")
				expectation.fulfill()
			}
		}

		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: StubHttpClient(),
			attributionApi: testHttpClient,
			privacyApi: testHttpClient,
			eventApi: testHttpClient,
			logApi: testHttpClient,
			userPropertyApi: testHttpClient,
			remoteConfigApi: testHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in connectivityManager },
			adTrackingProvider: TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true,
			enableConnectionTracking: true
		)
		sdk.start()
		sdk.track(event: AppEvent("test_connection_event"))
		waitForExpectations(timeout: 10)
	}

	func testTrackEventAttachesOfflineWhenDisconnected() throws {
		let connectivityManager = TestConnectivityManager()
		connectivityManager.connectionType = .offline
		let testHttpClient = TestAttributionHttpClient(changeInstallId: false, remainingFails: 0)
		let expectation = self.expectation(description: #function)

		testHttpClient.onEventsPublished = { dto in
			let userEvent = dto.events.first { $0.name == "test_offline_event" }
			if let userEvent {
				XCTAssertEqual(userEvent.dimensions["jt_connection_type"], "offline")
				expectation.fulfill()
			}
		}

		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: StubHttpClient(),
			attributionApi: testHttpClient,
			privacyApi: testHttpClient,
			eventApi: testHttpClient,
			logApi: testHttpClient,
			userPropertyApi: testHttpClient,
			remoteConfigApi: testHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in connectivityManager },
			adTrackingProvider: TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true,
			enableConnectionTracking: true
		)
		sdk.start()
		sdk.track(event: AppEvent("test_offline_event"))
		waitForExpectations(timeout: 10)
	}

	func testTrackEventDoesNotAttachConnectionTypeWhenDisabled() throws {
		let testHttpClient = TestAttributionHttpClient(changeInstallId: false, remainingFails: 0)
		let expectation = self.expectation(description: #function)

		testHttpClient.onEventsPublished = { dto in
			let userEvent = dto.events.first { $0.name == "test_no_connection_event" }
			if let userEvent {
				XCTAssertNil(userEvent.dimensions["jt_connection_type"])
				expectation.fulfill()
			}
		}

		sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: StubHttpClient(),
			attributionApi: testHttpClient,
			privacyApi: testHttpClient,
			eventApi: testHttpClient,
			logApi: testHttpClient,
			userPropertyApi: testHttpClient,
			remoteConfigApi: testHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
		sdk.start()
		sdk.track(event: AppEvent("test_no_connection_event"))
		waitForExpectations(timeout: 10)
	}

	// MARK: - forward(adImpression:) invalid-validation branch

	func testForwardAdImpressionWithInvalidCurrencyReturnsError() throws {
		sdk = try makeSdk(mockHttpClient: MockHttpClient())
		sdk.start()
		// Revenue with a non-ISO-4217 currency makes the emitted
		// JtAdInternalEvent fail validate() (Money.validate throws).
		// Revenue is non-negative so we pass the early "negative revenue" guard.
		let impression = AdImpression(unit: .banner, sdkName: "test_network")
			.set(revenue: Money(value: 1.0, currency: "usd"))  // lowercase → invalid
		let expectation = self.expectation(description: #function)
		sdk.forward(adImpression: impression).observe { result in
			if case .failure(let error) = result,
				(error as? JustTrackError)?.justTrackGetErrorDescription() == JustTrackError.custom("Invalid ad impression").justTrackGetErrorDescription()
			{
				expectation.fulfill()
			} else {
				XCTFail("expected 'Invalid ad impression', got: \(result)")
			}
		}
		wait(for: [expectation], timeout: 5)
	}

	// MARK: - onFinishAdTrackingAuthorization second call

	func testOnFinishAdTrackingAuthorizationCalledTwiceExercisesProceedSecondBranch() throws {
		let mockHttpClient = MockHttpClient()
		let installId = StringID()
		mockHttpClient.sendAttributionRequestResponseData = makeAttributionResponseData(installId: installId.value)
		sdk = try makeSdk(mockHttpClient: mockHttpClient)
		sdk.start()

		// Wait for the first attribution so that attributionOutput is populated.
		let attributionExpectation = self.expectation(description: "attribution")
		sdk.attribution.observe { _ in attributionExpectation.fulfill() }
		wait(for: [attributionExpectation], timeout: 10)

		// Now hit the `needsToGetIdfa == false` + non-nil idfa branch.
		(sdk as! JustTrackSdkImpl).onFinishAdTrackingAuthorization()
		// One more time to also exercise the fulfilled-attributionOutput path.
		(sdk as! JustTrackSdkImpl).onFinishAdTrackingAuthorization()
		// Allow async observers to run.
		Thread.sleep(forTimeInterval: 0.3)
	}

	// MARK: - Test Helpers

	/// Builds a JustTrackSdkImpl wired up with the given MockHttpClient for all APIs.
	private func makeSdk(mockHttpClient: MockHttpClient) throws -> JustTrackSdkImpl {
		return try JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: StubHttpClient(),
			attributionApi: mockHttpClient,
			privacyApi: mockHttpClient,
			eventApi: mockHttpClient,
			logApi: mockHttpClient,
			userPropertyApi: mockHttpClient,
			remoteConfigApi: mockHttpClient,
			sessionManagerBuilder: SessionManagerImpl.init,
			connectivityManagerBuilder: { _ in try! ConnectivityManagerImpl() },
			adTrackingProvider: TestAdTrackingProvider(idfa: Self.idfa, idfv: Self.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(StringID().value)"),
			config: .default,
			manualStart: true
		)
	}

	/// Returns the number of sendAttributionRequest calls in a call list.
	private func attributionRequestCount(in calls: [MockHttpClient.Call]) -> Int {
		calls.filter {
			if case .sendAttributionRequest = $0 { return true }
			return false
		}.count
	}

	/// Builds a minimal valid attribution response JSON data (no retargeting).
	private func makeAttributionResponseData(installId: String) -> Data {
		let response: [String: Any] = [
			"user": [
				"installId": installId,
				"type": "acquisition",
				"redownload": false,
			],
			"attribution": [
				"campaign": [
					"externalId": "42",
					"name": "Test Campaign",
					"type": "acquisition",
					"organic": false,
				] as [String: Any],
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
			"retargeting": NSNull(),
		]
		return try! JSONSerialization.data(withJSONObject: response, options: [])
	}

	/// Builds an attribution response JSON data that includes retargeting parameters.
	private func makeAttributionResponseDataWithRetargeting(
		installId: String,
		retargetingUrl: String,
		retargetingAttributes: [String: String]
	) -> Data {
		let response: [String: Any] = [
			"user": [
				"installId": installId,
				"type": "acquisition",
				"redownload": true,
			],
			"attribution": [
				"campaign": [
					"externalId": "42",
					"name": "Test Campaign",
					"type": "acquisition",
					"organic": false,
				] as [String: Any],
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
			"retargeting": [
				"url": retargetingUrl,
				"attributes": retargetingAttributes,
			] as [String: Any],
		]
		return try! JSONSerialization.data(withJSONObject: response, options: [])
	}
}

class TestConnectivityManager: ConnectivityManager {
	let subscriptionManager: SubscriptionManager<()>
	var connectionType: ConnectionType = .wifi

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
		self.init(changeInstallId: false, remainingFails: 0, allowAttributionRequest: true)
	}

	convenience init(changeInstallId: Bool, remainingFails: Int) {
		self.init(changeInstallId: changeInstallId, remainingFails: remainingFails, allowAttributionRequest: true)
	}

	init(changeInstallId: Bool, remainingFails: Int, allowAttributionRequest: Bool) {
		self.remainingFails = remainingFails
		self.successfulCalls = 0
		self.onEventsPublished = nil
		self.onCustomUserIdPublished = nil
		self.onFirebaseAppInstanceIdPublished = nil
		super.init(changeInstallId: changeInstallId, allowAttributionRequest: allowAttributionRequest)
	}

	init(changeInstallId: Bool, onEventsPublished: @escaping (DTOUserEvent) -> Void) {
		self.remainingFails = 0
		self.successfulCalls = 0
		self.onEventsPublished = onEventsPublished
		self.onCustomUserIdPublished = nil
		self.onFirebaseAppInstanceIdPublished = nil
		super.init(changeInstallId: changeInstallId, allowAttributionRequest: true)
	}

	init(changeInstallId: Bool, onCustomUserIdPublished: @escaping (DTOPublishCustomUserIdRequest) -> Void) {
		self.remainingFails = 0
		self.successfulCalls = 0
		self.onEventsPublished = nil
		self.onCustomUserIdPublished = onCustomUserIdPublished
		self.onFirebaseAppInstanceIdPublished = nil
		super.init(changeInstallId: changeInstallId, allowAttributionRequest: true)
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

class BaseTestHttpClient: AttributionApi, PrivacyApi, EventApi, LogApi, UserPropertyApi, RemoteConfigApi {
	private let attributionRequestAllowed: FutureImpl<()>
	let installId: StringID?

	init(changeInstallId: Bool, allowAttributionRequest: Bool) {
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

	// MARK: AttributionApi

	func sendAttributionRequest(request: DTOAttributionRequest, userData: UserData) -> Future<Data> {
		let f: FutureImpl<Data> = FutureImpl()
		attributionRequestAllowed.observe(using: { _ in
			_ = f.resolve(self.attributionResponseData(installId: request.user.installInstanceId, idfv: request.user.deviceId))
		})

		return f.toFuture()
	}

	func sendAnonymizeRequest(request: DTOAnonymizeRequest, userData: UserData) -> Future<Data> {
		return FutureImpl("{}".data(using: .utf8)).toFuture()
	}

	func getSignedIpClaim(ipProtocol: IPProtocol, userData: UserData) -> Future<Data> {
		return FutureImpl(signedIpClaimResponse(ip: "127.0.0.1", type: "IPv4", token: "some random token")).toFuture()
	}

	// MARK: EventApi

	func sendUserEvents(events: DTOUserEvent, userData: UserData) -> Future<Data> {
		return FutureImpl("{}".data(using: .utf8)).toFuture()
	}

	// MARK: LogApi

	func sendLogs(input: DTOLogInput, userData: UserData) -> Future<Data> {
		return FutureImpl("{}".data(using: .utf8)).toFuture()
	}

	// MARK: UserPropertyApi

	func sendCustomUserId(request: DTOPublishCustomUserIdRequest, userData: UserData) -> Future<Data> {
		XCTFail("Unexpected call to publish a Custom user id")

		return FutureImpl("{}".data(using: .utf8)).toFuture()
	}

	func sendFirebaseAppInstanceId(request: DTOPublishFirebaseAppInstanceIdRequest, userData: UserData) -> Future<Data> {
		XCTFail("Unexpected call to publish a Firebase app instance id")

		return FutureImpl("{}".data(using: .utf8)).toFuture()
	}

	// MARK: RemoteConfigApi

	func sendSetExperimentVariant(request: DTOSetExperimentVariantRequest, userData: UserData) -> Future<Data> {
		return FutureImpl("{}".data(using: .utf8)).toFuture()
	}

	func getAssignments(parameters: GetAssignmentsParameters, userData: UserData) -> Future<AssignmentsResponse> {
		let data = "{\"assignments\":[]}".data(using: .utf8)!
		return FutureImpl(AssignmentsResponse(data: data, retryAfterSeconds: nil)).toFuture()
	}

	func postEnrollments(request: DTOPostEnrollmentRequest, userData: UserData) -> Future<Data> {
		return FutureImpl("{\"enrolledAssignments\":[]}".data(using: .utf8)).toFuture()
	}

	// MARK: Helpers

	func signedIpClaimResponse(ip: String, type: String, token: String) -> Data {
		let response: [String: Any] = [
			"ip": ip,
			"type": type,
			"token": token,
		]

		return try! JSONSerialization.data(withJSONObject: response, options: [])
	}

	func attributionResponseData(installId newInstallId: String, idfv: String) -> Data {
		let response: [String: Any] = [
			"user": [
				"installId": installId?.value ?? newInstallId,
				"type": "acquisition",
				"redownload": false,
			],
			"attribution": [
				"campaign": [
					"externalId": "42",
					"name": "Test Campaign",
					"type": "acquisition",
					"organic": false,
				] as [String: Any],
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

/// PrivacyApi that always rejects `sendAnonymizeRequest`.
final class FailingPrivacyApi: PrivacyApi {
	struct AnonymizeError: Error {}

	func sendAnonymizeRequest(request: DTOAnonymizeRequest, userData: UserData) -> Future<Data> {
		FutureImpl<Data>().reject(AnonymizeError())
	}
}
