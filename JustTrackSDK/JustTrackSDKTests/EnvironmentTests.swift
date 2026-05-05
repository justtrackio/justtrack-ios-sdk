import XCTest

@testable import JustTrackSDK

final class EnvironmentTests: XCTestCase {
	func testProvidesCorrectDefaultProductionUrls() {
		let env = Environment()

		let urls = [
			Route.attribution: "https://attribution.justtrack.io/v4/attribute",
			.trackEvent: "https://sdk-api.justtrack.io/v4/track",
			.publishCustomUserId: "https://sdk-api.justtrack.io/v0/customUserId/publish",
			.publishFirebaseAppInstanceId: "https://sdk-api.justtrack.io/v0/firebase/instanceId/publish",
			.log: "https://justtrack-logs.justtrack.io/v2/log",
			.signIPv4: "https://ipv4.justtrack.io/v0/sign/",
			.signIPv6: "https://ipv6.justtrack.io/v0/sign/",
		]

		for url in urls {
			XCTAssertEqual(env.getUrl(route: url.key, idfaProvided: false), url.value)
		}

		let idfaProvidedUrls = [
			Route.attribution: "https://attribution-att.justtrack.io/v4/attribute",
			.trackEvent: "https://sdk-api-att.justtrack.io/v4/track",
			.publishCustomUserId: "https://sdk-api-att.justtrack.io/v0/customUserId/publish",
			.publishFirebaseAppInstanceId: "https://sdk-api-att.justtrack.io/v0/firebase/instanceId/publish",
			.log: "https://justtrack-logs-att.justtrack.io/v2/log",
			.signIPv4: "https://4-att.justtrack.io/v0/sign/",
			.signIPv6: "https://6-att.justtrack.io/v0/sign/",
		]
		for url in idfaProvidedUrls {
			XCTAssertEqual(env.getUrl(route: url.key, idfaProvided: true), url.value)
		}
	}

	func testSandboxProvidesCorrectUrls() {
		let env = Environment(url: URL(string: "https://test.url")!)

		let urls = [
			Route.attribution: "https://attribution.test.url/v4/attribute",
			.trackEvent: "https://sdk-api.test.url/v4/track",
			.publishCustomUserId: "https://sdk-api.test.url/v0/customUserId/publish",
			.publishFirebaseAppInstanceId: "https://sdk-api.test.url/v0/firebase/instanceId/publish",
			.log: "https://justtrack-logs.test.url/v2/log",
			.signIPv4: "https://ipv4.test.url/v0/sign/",
			.signIPv6: "https://ipv6.test.url/v0/sign/",
		]
		for url in urls {
			XCTAssertEqual(env.getUrl(route: url.key, idfaProvided: false), url.value)
		}

		let idfaProvidedUrls = [
			Route.attribution: "https://attribution-att.test.url/v4/attribute",
			.trackEvent: "https://sdk-api-att.test.url/v4/track",
			.publishCustomUserId: "https://sdk-api-att.test.url/v0/customUserId/publish",
			.publishFirebaseAppInstanceId: "https://sdk-api-att.test.url/v0/firebase/instanceId/publish",
			.log: "https://justtrack-logs-att.test.url/v2/log",
			.signIPv4: "https://4-att.test.url/v0/sign/",
			.signIPv6: "https://6-att.test.url/v0/sign/",
		]
		for url in idfaProvidedUrls {
			XCTAssertEqual(env.getUrl(route: url.key, idfaProvided: true), url.value)
		}
	}
}
