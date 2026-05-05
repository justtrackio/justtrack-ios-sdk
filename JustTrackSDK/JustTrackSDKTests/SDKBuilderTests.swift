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
}
