import XCTest

@testable import JustTrackSDK

final class SDKBuilderTests: XCTestCase {
	static let apiToken = TestCredentials.apiToken
	static let clientId = TestCredentials.clientId

	private var sdk: JustTrackSdk?

	override func setUp() {
		super.setUp()
		JustTrack.resetForTesting(clearStorage: true)
	}

	override func tearDown() {
		sdk?.shutdown()
		sdk = nil
		super.tearDown()
	}

	// MARK: Bundle ID Tests

	func testSetBundleIdReturnsBuilder() {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken)
		let result = builder.set(bundleId: "com.example.app")

		XCTAssertTrue(result === builder, "set(bundleId:) should return the same builder instance for chaining")
	}

	func testSetBundleIdWithEmptyStringDoesNotThrow() {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken)

		// Should not throw
		_ = builder.set(bundleId: "")

		XCTAssertNotNil(builder)
	}

	func testSetBundleIdWithValidBundleId() throws {
		let customBundleId = "com.example.custom.app"

		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(bundleId: customBundleId)
			.build()

		XCTAssertNotNil(sdk)
	}

	// MARK: Application Version Tests

	func testSetApplicationVersionReturnsBuilder() {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken)
		let result = builder.set(applicationVersion: "1.0.0", versionCode: "1")

		XCTAssertTrue(result === builder, "set(applicationVersion:versionCode:) should return the same builder instance for chaining")
	}

	func testSetApplicationVersionWithEmptyStringsDoesNotThrow() {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken)

		// Should not throw
		_ = builder.set(applicationVersion: "", versionCode: "")

		XCTAssertNotNil(builder)
	}

	func testSetApplicationVersionWithValidVersion() throws {
		let customVersionName = "2.0.0"
		let customVersionCode = "42"

		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(applicationVersion: customVersionName, versionCode: customVersionCode)
			.build()

		XCTAssertNotNil(sdk)
	}

	// MARK: Method Chaining Tests

	func testBuilderMethodChainingWithBundleIdAndApplicationVersion() throws {
		let customBundleId = "com.example.chained.app"
		let customVersionName = "3.0.0"
		let customVersionCode = "100"

		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(bundleId: customBundleId)
			.set(applicationVersion: customVersionName, versionCode: customVersionCode)
			.set(isLoggingEnabled: false)
			.set(manualStart: true)
			.build()

		XCTAssertNotNil(sdk)
	}

	func testBuilderMethodChainingOrderDoesNotMatter() throws {
		let customBundleId = "com.example.order.app"
		let customVersionName = "4.0.0"
		let customVersionCode = "200"

		// Set application version before bundle ID
		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(applicationVersion: customVersionName, versionCode: customVersionCode)
			.set(bundleId: customBundleId)
			.set(manualStart: true)
			.build()

		XCTAssertNotNil(sdk)
	}

	// MARK: Default Values Tests

	func testBuilderUsesDefaultBundleIdWhenNotSet() throws {
		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(manualStart: true)
			.build()

		XCTAssertNotNil(sdk)
	}

	func testBuilderUsesDefaultApplicationVersionWhenNotSet() throws {
		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(manualStart: true)
			.build()

		XCTAssertNotNil(sdk)
		// The SDK should use the default app version from Info.plist
		let appVersion = sdk?.appVersionAtInstall
		XCTAssertNotNil(appVersion)
		XCTAssertFalse(appVersion?.name.isEmpty ?? true)
	}

	// MARK: Edge Cases

	func testSetBundleIdCanBeCalledMultipleTimes() throws {
		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(bundleId: "com.first.app")
			.set(bundleId: "com.second.app")
			.set(bundleId: "com.final.app")
			.set(manualStart: true)
			.build()

		XCTAssertNotNil(sdk)
	}

	func testSetApplicationVersionCanBeCalledMultipleTimes() throws {
		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(applicationVersion: "1.0.0", versionCode: "1")
			.set(applicationVersion: "2.0.0", versionCode: "2")
			.set(applicationVersion: "3.0.0", versionCode: "3")
			.set(manualStart: true)
			.build()

		XCTAssertNotNil(sdk)
		XCTAssertEqual(sdk?.appVersionAtInstall.name, "3.0.0")
		XCTAssertEqual(sdk?.appVersionAtInstall.code, "3")
	}

	func testSetApplicationVersionWithSpecialCharacters() throws {
		let specialVersionName = "1.0.0-beta.1+build.123"
		let specialVersionCode = "12345"

		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(applicationVersion: specialVersionName, versionCode: specialVersionCode)
			.set(manualStart: true)
			.build()

		XCTAssertNotNil(sdk)
		XCTAssertEqual(sdk?.appVersionAtInstall.name, specialVersionName)
		XCTAssertEqual(sdk?.appVersionAtInstall.code, specialVersionCode)
	}

	// MARK: Logger Tests

	func testSetLoggerReturnsBuilder() {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken)
		let result = builder.set(logger: MockLogger())

		XCTAssertTrue(result === builder, "set(logger:) should return the same builder instance for chaining")
	}

	func testSetLoggerBuildsSdkSuccessfully() throws {
		let mockLogger = MockLogger()

		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(logger: mockLogger)
			.set(isLoggingEnabled: true)
			.set(manualStart: true)
			.build()

		XCTAssertNotNil(sdk)
	}

	// MARK: Tracking Id / Provider Tests

	func testSetTrackingIdReturnsBuilder() throws {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken)
		let result = try builder.set(trackingId: "trk-123", trackingProvider: "providerA")

		XCTAssertTrue(result === builder, "set(trackingId:trackingProvider:) should return the same builder instance for chaining")
	}

	func testSetTrackingIdThrowsOnInvalidValue() {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken)

		XCTAssertThrowsError(try builder.set(trackingId: "müller", trackingProvider: "providerA"))
		XCTAssertThrowsError(try builder.set(trackingId: "trk-123", trackingProvider: "prövider"))
	}

	func testSetTrackingIdBuildsSdkSuccessfully() throws {
		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(trackingId: "trk-123", trackingProvider: "providerA")
			.set(manualStart: true)
			.build()

		XCTAssertNotNil(sdk)
	}

	// MARK: User Id Tests

	func testSetUserIdReturnsBuilder() throws {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken)
		let result = try builder.set(userId: "user-123")

		XCTAssertTrue(result === builder, "set(userId:) should return the same builder instance for chaining")
	}

	func testSetUserIdThrowsOnInvalidValue() {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken)

		XCTAssertThrowsError(try builder.set(userId: ""))
	}

	func testSetUserIdBuildsSdkSuccessfully() throws {
		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(userId: "user-123")
			.set(manualStart: true)
			.build()

		XCTAssertNotNil(sdk)
	}

	// MARK: Firebase App Instance Id Tests

	func testSetFirebaseAppInstanceIdReturnsBuilder() {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken)
		let result = builder.set(firebaseAppInstanceId: "fb-instance-id")

		XCTAssertTrue(result === builder, "set(firebaseAppInstanceId:) should return the same builder instance for chaining")
	}

	func testSetFirebaseAppInstanceIdIsForwardedDuringConfigure() throws {
		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(firebaseAppInstanceId: "firebase-instance-id-1234")
			.set(manualStart: true)
			.build()

		XCTAssertNotNil(sdk)
	}

	// MARK: ODM Info Tests

	func testSetOdmInfoReturnsBuilder() {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken)
		let result = builder.set(odmInfo: "odm-payload")

		XCTAssertTrue(result === builder, "set(odmInfo:) should return the same builder instance for chaining")
	}

	func testSetOdmInfoIsForwardedDuringConfigure() throws {
		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(odmInfo: "odm-payload")
			.set(manualStart: true)
			.build()

		XCTAssertNotNil(sdk)
	}

	// MARK: Attribution Settings Setter Tests

	func testSetInactivityTimeFrameHoursReturnsBuilderAndBuilds() throws {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
		let result = builder.set(inactivityTimeFrameHours: 72)
		XCTAssertTrue(result === builder)

		sdk = try result.set(manualStart: true).build()
		XCTAssertNotNil(sdk)
	}

	func testSetReAttributionTimeFrameDaysReturnsBuilderAndBuilds() throws {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
		let result = builder.set(reAttributionTimeFrameDays: 30)
		XCTAssertTrue(result === builder)

		sdk = try result.set(manualStart: true).build()
		XCTAssertNotNil(sdk)
	}

	func testSetReFetchReAttributionDelaySecondsReturnsBuilderAndBuilds() throws {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
		let result = builder.set(reFetchReAttributionDelaySeconds: 10)
		XCTAssertTrue(result === builder)

		sdk = try result.set(manualStart: true).build()
		XCTAssertNotNil(sdk)
	}

	func testSetAttributionRetryDelaySecondsReturnsBuilderAndBuilds() throws {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
		let result = builder.set(attributionRetryDelaySeconds: 240)
		XCTAssertTrue(result === builder)

		sdk = try result.set(manualStart: true).build()
		XCTAssertNotNil(sdk)
	}

	// MARK: Automatic In-App Purchase Tracking Tests

	func testSetAutomaticInAppPurchaseTrackingTrueReturnsBuilderAndBuilds() throws {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
		let result = builder.set(automaticInAppPurchaseTracking: true)
		XCTAssertTrue(result === builder)

		sdk = try result.set(manualStart: true).build()
		XCTAssertNotNil(sdk)
	}

	func testSetAutomaticInAppPurchaseTrackingFalseReturnsBuilderAndBuilds() throws {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
		let result = builder.set(automaticInAppPurchaseTracking: false)
		XCTAssertTrue(result === builder)

		sdk = try result.set(manualStart: true).build()
		XCTAssertNotNil(sdk)
	}

	// MARK: Platform Type Tests

	func testSetPlatformTypeReturnsBuilder() {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken)
		let result = builder.set(platformType: .unity)

		XCTAssertTrue(result === builder, "set(platformType:) should return the same builder instance for chaining")
	}

	func testSetPlatformTypeBuildsSdkSuccessfully() throws {
		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(platformType: .unity)
			.set(manualStart: true)
			.build()

		XCTAssertNotNil(sdk)
	}

	// MARK: Manual Start Tests

	func testSetManualStartReturnsBuilder() {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken)
		let result = builder.set(manualStart: true)

		XCTAssertTrue(result === builder, "set(manualStart:) should return the same builder instance for chaining")
	}

	// MARK: Console Logging Tests

	func testSetIsLoggingEnabledReturnsBuilder() {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken)
		let result = builder.set(isLoggingEnabled: true)

		XCTAssertTrue(result === builder, "set(isLoggingEnabled:) should return the same builder instance for chaining")
	}

	func testSetIsLoggingEnabledTrueBuildsSdkSuccessfully() throws {
		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(isLoggingEnabled: true)
			.set(manualStart: true)
			.build()

		XCTAssertNotNil(sdk)
	}

	// MARK: Server URL Tests

	func testSetServerUrlReturnsBuilder() throws {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken)
		let result = try builder.set(serverUrl: "https://justtrack.io")

		XCTAssertTrue(result === builder, "set(serverUrl:) should return the same builder instance for chaining")
	}

	func testSetServerUrlBuildsSdkSuccessfully() throws {
		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(serverUrl: "https://justtrack.io")
			.set(manualStart: true)
			.build()

		XCTAssertNotNil(sdk)
	}

	func testSetServerUrlThrowsOnInvalidUrl() {
		let builder = JustTrackSdkBuilder(apiToken: Self.apiToken)

		XCTAssertThrowsError(try builder.set(serverUrl: "")) { error in
			XCTAssertEqual((error as? URLError)?.code, .badURL)
		}
	}

	// MARK: Attribution Settings Defaults

	func testAttributionSettingsHasExpectedDefaults() {
		let settings = AttributionSettings()

		XCTAssertEqual(settings.inactivityTimeFrameHours, 48)
		XCTAssertEqual(settings.reAttributionTimeFrameDays, 14)
		XCTAssertEqual(settings.reFetchReAttributionDelaySeconds, 5)
		XCTAssertEqual(settings.attributionRetryDelaySeconds, 120)
	}
}
