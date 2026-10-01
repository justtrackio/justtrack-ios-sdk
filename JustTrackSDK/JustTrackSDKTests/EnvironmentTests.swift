import Foundation
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

	func testPrivacyRoute() {
		let env = Environment()
		XCTAssertEqual(env.getUrl(route: .privacy, idfaProvided: false), "https://privacy.justtrack.io/v1/anonymize")
		XCTAssertEqual(env.getUrl(route: .privacy, idfaProvided: true), "https://privacy-att.justtrack.io/v1/anonymize")
	}

	func testTestAssignmentRoute() {
		let env = Environment()
		XCTAssertEqual(env.getUrl(route: .testAssignment, idfaProvided: false), "https://sdk-api.justtrack.io/ab-test/v0/assignment")
		XCTAssertEqual(env.getUrl(route: .testAssignment, idfaProvided: true), "https://sdk-api-att.justtrack.io/ab-test/v0/assignment")
	}

	func testExperimentVariantAssignmentRoute() {
		let env = Environment()
		XCTAssertEqual(env.getUrl(route: .experimentVariantAssignment, idfaProvided: false), "https://sdk-api.justtrack.io/v0/assignment")
		XCTAssertEqual(env.getUrl(route: .experimentVariantAssignment, idfaProvided: true), "https://sdk-api-att.justtrack.io/v0/assignment")
	}

	func testAssignmentsRoute() {
		let env = Environment()
		XCTAssertEqual(env.getUrl(route: .assignments, idfaProvided: false), "https://sdk-api.justtrack.io/ab-test/v0/assignments")
		XCTAssertEqual(env.getUrl(route: .assignments, idfaProvided: true), "https://sdk-api-att.justtrack.io/ab-test/v0/assignments")
	}

	func testIPProtocolProperties() {
		XCTAssertEqual(IPProtocol.ipV4.name, "IPv4")

		XCTAssertEqual(IPProtocol.ipV6.name, "IPv6")
	}

	func testIPProtocolRoute() {
		let env = Environment()
		let urlV4 = env.getUrl(route: IPProtocol.ipV4.route, idfaProvided: false)
		XCTAssertTrue(urlV4.contains("ipv4"))

		let urlV6 = env.getUrl(route: IPProtocol.ipV6.route, idfaProvided: false)
		XCTAssertTrue(urlV6.contains("ipv6"))
	}

	func testIPProtocolClaimDurationMetric() {
		let metricV4 = IPProtocol.ipV4.claimDurationMetric
		XCTAssertEqual(metricV4.unit, .seconds)

		let metricV6 = IPProtocol.ipV6.claimDurationMetric
		XCTAssertEqual(metricV6.unit, .seconds)
	}

	func testEnvironmentWithCustomUrl() {
		let env = Environment(url: URL(string: "https://custom.domain.com")!)
		XCTAssertEqual(env.getUrl(route: .attribution, idfaProvided: false), "https://attribution.custom.domain.com/v4/attribute")
	}

	func testLogRoute() {
		let env = Environment()
		XCTAssertEqual(env.getUrl(route: .log, idfaProvided: false), "https://justtrack-logs.justtrack.io/v2/log")
		XCTAssertEqual(env.getUrl(route: .log, idfaProvided: true), "https://justtrack-logs-att.justtrack.io/v2/log")
	}

	func testAllRoutesWithDefaultEnvironment() {
		let env = Environment()

		XCTAssertEqual(env.getUrl(route: .attribution, idfaProvided: false), "https://attribution.justtrack.io/v4/attribute")
		XCTAssertEqual(env.getUrl(route: .attribution, idfaProvided: true), "https://attribution-att.justtrack.io/v4/attribute")

		XCTAssertEqual(env.getUrl(route: .trackEvent, idfaProvided: false), "https://sdk-api.justtrack.io/v4/track")

		XCTAssertEqual(env.getUrl(route: .publishCustomUserId, idfaProvided: false), "https://sdk-api.justtrack.io/v0/customUserId/publish")

		XCTAssertEqual(env.getUrl(route: .publishFirebaseAppInstanceId, idfaProvided: false), "https://sdk-api.justtrack.io/v0/firebase/instanceId/publish")

		XCTAssertEqual(env.getUrl(route: .signIPv4, idfaProvided: false), "https://ipv4.justtrack.io/v0/sign/")
		XCTAssertEqual(env.getUrl(route: .signIPv4, idfaProvided: true), "https://4-att.justtrack.io/v0/sign/")

		XCTAssertEqual(env.getUrl(route: .signIPv6, idfaProvided: false), "https://ipv6.justtrack.io/v0/sign/")
		XCTAssertEqual(env.getUrl(route: .signIPv6, idfaProvided: true), "https://6-att.justtrack.io/v0/sign/")
	}

	func testEnvironmentWithPathAndQuery() {
		let env = Environment(url: URL(string: "https://example.com/path")!)
		let url = env.getUrl(route: .attribution, idfaProvided: false)
		XCTAssertTrue(url.contains("attribution.example.com/path"))
	}

	func testEnvironmentWithQueryAndFragment() {
		let env = Environment(url: URL(string: "https://example.com?key=val#frag")!)
		let url = env.getUrl(route: .attribution, idfaProvided: false)
		XCTAssertTrue(url.contains("key=val"))
		XCTAssertTrue(url.contains("#frag"))
	}

	func testEnvironmentWithOnlyFragment() {
		let env = Environment(url: URL(string: "https://example.com#section")!)
		let url = env.getUrl(route: .attribution, idfaProvided: false)
		XCTAssertTrue(url.contains("#section"))
	}

	func testEnvironmentWithPathQueryAndFragment() {
		let env = Environment(url: URL(string: "https://example.com/path?q=1#frag")!)
		let url = env.getUrl(route: .attribution, idfaProvided: false)
		XCTAssertTrue(url.contains("/path"))
		XCTAssertTrue(url.contains("q=1"))
		XCTAssertTrue(url.contains("#frag"))
	}

	func testEnvironmentWithNoHostUrl() {
		let env = Environment(url: URL(string: "http:///justpath")!)
		let url = env.getUrl(route: .attribution, idfaProvided: false)
		XCTAssertFalse(url.isEmpty)
	}

	func testEnvironmentWithEmptyPathUrl() {
		let env = Environment(url: URL(string: "https://bare.host")!)
		let url = env.getUrl(route: .attribution, idfaProvided: false)
		XCTAssertTrue(url.contains("bare.host"))
	}

	func testStripSchemeWithInvalidUrl() {
		let invalid = "http://host name with spaces:not-a-port"
		let result = stripScheme(url: invalid)
		XCTAssertEqual(result, invalid)
	}
}
