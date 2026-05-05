import XCTest

@testable import JustTrackSDK

final class EnvironmentSettingsTests: XCTestCase {

	private let url = URL(string: "https://justtrack.io")!

	func testApiTokenDoesNotContainSandboxPrefixWhenEnvironmentIsSandbox() {
		XCTAssertEqual(
			EnvironmentSettings(prefixedApiToken: "sandbox-api-token", serverUrl: url).apiToken,
			"api-token"
		)
	}

	func testApiTokenDoesNotContainProdPrefixWhenEnvironmentIsProduction() {
		XCTAssertEqual(
			EnvironmentSettings(prefixedApiToken: "prod-api-token", serverUrl: url).apiToken,
			"api-token"
		)
	}
}
