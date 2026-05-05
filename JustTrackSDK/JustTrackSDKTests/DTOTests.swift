import Foundation
import XCTest

@testable import JustTrackSDK

final class DTOTests: XCTestCase {
	func testStaticDateSeconds() {
		print(Locale.current.debugDescription)
		let date = Date(timeIntervalSince1970: 0)
		let s = formatDateSeconds(date)
		XCTAssertEqual("1970-01-01T00:00:00Z", s)
	}

	func testStaticDateMilliseconds() {
		print(Locale.current.debugDescription)
		let date = Date(timeIntervalSince1970: 0)
		let s = formatDateMilliseconds(date)
		XCTAssertEqual("1970-01-01T00:00:00.000Z", s)
	}

	func testManyDatesSeconds() {
		for i in 0..<1000 {
			let date = Date(timeIntervalSince1970: TimeInterval(i * 999997))
			let s = formatDateSeconds(date)
			guard let d = parseDate(s) else {
				XCTFail()
				return
			}
			XCTAssertEqual(date, d)
			XCTAssertEqual(formatDateSeconds(d), s)
		}
	}

	func testManyDatesMilliseconds() {
		for i in 0..<1000 {
			let date = Date(timeIntervalSince1970: TimeInterval(i) * 999997.125)
			let s = formatDateMilliseconds(date)
			guard let d = parseDate(s) else {
				XCTFail()
				return
			}
			XCTAssertEqual(date, d)
			XCTAssertEqual(formatDateMilliseconds(d), s)
		}
	}

	func testUserEvent() throws {
		let events = [
			PublishingEvent(event: StorableEvent(id: 1, event: JtAppOpenEvent(sessionId: "", duration: 0, unit: .milliseconds, happenedAt: Date()).build(sessionId: ""), sequenceNumber: 1))
		]
		let data = try PublishableUserEvent.build(
			batch: PublishingBatch(events: events, sdkVersion: currentSdkVersion()),
			idfa: "idfa",
			userId: StringID(),
			installId: StringID(),
			idfvProvider: TestAdTrackingProvider(
				idfa: nil,
				idfv: StringID(value: "1f46d3ce-cfd4-4da1-b011-f07ab64ce184")!
			),
			applicationVersion: AppVersionImpl(code: "1", name: "1.0.0"),
			platformType: .native
		).json()
		guard let s = String(data: data, encoding: .utf8) else {
			XCTFail()
			return
		}
		for c in s {
			XCTAssert(c.isASCII)
		}
	}

	func testGetUniqueId() {
		XCTAssertEqual("a", getUniqueId(advertiserId: "a", trackingId: "b", deviceId: "c"))
		XCTAssertEqual("b", getUniqueId(advertiserId: "", trackingId: "b", deviceId: "c"))
		XCTAssertEqual("a", getUniqueId(advertiserId: "a", trackingId: "", deviceId: "c"))
		XCTAssertEqual("a", getUniqueId(advertiserId: "a", trackingId: "b", deviceId: ""))
		XCTAssertEqual("c", getUniqueId(advertiserId: "", trackingId: "", deviceId: "c"))
		XCTAssertEqual("b", getUniqueId(advertiserId: "", trackingId: "b", deviceId: ""))
		XCTAssertEqual("a", getUniqueId(advertiserId: "a", trackingId: "", deviceId: ""))
		XCTAssertEqual("", getUniqueId(advertiserId: "", trackingId: "", deviceId: ""))
	}

	func testComputeUserId() {
		let bundleId = "io.justtrack.app"
		let uniqueId = "c3c4b7c7-0668-4662-9023-6a53e99efdde"
		let userId = computeUserId(bundleId: bundleId, uniqueId: uniqueId)
		XCTAssertEqual(userId.value, "73fbcde5-7e03-4135-986c-14f41c8774a4")
	}
}
