import Foundation
import XCTest

@testable import JustTrackSDK

final class DTOTests: XCTestCase {
	func testStaticDateSeconds() {
		let date = Date(timeIntervalSince1970: 0)
		let s = formatDateSeconds(date)
		XCTAssertEqual("1970-01-01T00:00:00Z", s)
	}

	func testStaticDateMilliseconds() {
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

	// MARK: - DTOAppVersion

	func testAppVersionRoundtrip() throws {
		let dto = DTOAppVersion.fixture()
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOAppVersion.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	func testAppVersionDecodesFromJson() throws {
		let json = """
			{"name":"2.3.1","code":"42"}
			"""
		let data = Data(json.utf8)
		let decoded = try JSONDecoder().decode(DTOAppVersion.self, from: data)
		XCTAssertEqual(decoded.name, "2.3.1")
		XCTAssertEqual(decoded.code, "42")
	}

	// MARK: - DTOSdkVersion

	func testSdkVersionRoundtrip() throws {
		let dto = DTOSdkVersion.fixture()
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOSdkVersion.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	func testSdkVersionOmitsNilWrapper() throws {
		let dto = DTOSdkVersion.fixture(wrapper: nil)
		let data = try JSONEncoder().encode(dto)
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertNil(json["wrapper"])
	}

	func testSdkVersionIncludesWrapper() throws {
		let dto = DTOSdkVersion.fixture(wrapper: "unity")
		let data = try JSONEncoder().encode(dto)
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertEqual(json["wrapper"] as? String, "unity")
	}

	func testSdkVersionDecodesFromJson() throws {
		let json = """
			{"major":4,"minor":2,"patch":0,"name":"4.2.0","platform":"ios","wrapper":"flutter"}
			"""
		let data = Data(json.utf8)
		let decoded = try JSONDecoder().decode(DTOSdkVersion.self, from: data)
		XCTAssertEqual(decoded.major, 4)
		XCTAssertEqual(decoded.minor, 2)
		XCTAssertEqual(decoded.patch, 0)
		XCTAssertEqual(decoded.name, "4.2.0")
		XCTAssertEqual(decoded.platform, "ios")
		XCTAssertEqual(decoded.wrapper, "flutter")
	}

	func testSdkVersionDecodesWithoutWrapper() throws {
		let json = """
			{"major":1,"minor":0,"patch":0,"name":"1.0.0","platform":"ios"}
			"""
		let data = Data(json.utf8)
		let decoded = try JSONDecoder().decode(DTOSdkVersion.self, from: data)
		XCTAssertNil(decoded.wrapper)
	}

	// MARK: - DTOAnonymizeRequest

	func testAnonymizeRequestEncodes() throws {
		let dto = DTOAnonymizeRequest.fixture()
		let data = try dto.json()
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertNotNil(json["installInstanceId"])
		XCTAssertNotNil(json["deviceId"])
		XCTAssertNotNil(json["idfv"])
	}

	func testAnonymizeRequestEncodesNilFields() throws {
		let dto = DTOAnonymizeRequest(
			installInstanceId: StringID(),
			deviceId: nil,
			idfv: nil
		)
		let data = try dto.json()
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertNotNil(json["installInstanceId"])
		XCTAssertNil(json["deviceId"])
		XCTAssertNil(json["idfv"])
	}

	// MARK: - DTOAttributionRequest

	func testAttributionRequestRoundtrip() throws {
		let dto = DTOAttributionRequest.fixture()
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOAttributionRequest.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	func testAttributionRequestJson() throws {
		let dto = DTOAttributionRequest.fixture(
			claims: ["claim1", "claim2"],
			parameters: ["key": "value"]
		)
		let data = try dto.json()
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertEqual(json["claims"] as? [String], ["claim1", "claim2"])
		let params = json["parameters"] as? [String: String]
		XCTAssertEqual(params?["key"], "value")
	}

	// MARK: - DTOAttributionRequestUser

	func testAttributionRequestUserRoundtrip() throws {
		let dto = DTOAttributionRequestUser.fixture()
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOAttributionRequestUser.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	func testAttributionRequestUserDefaultsEmptyStrings() {
		let dto = DTOAttributionRequestUser(
			userId: StringID(),
			installInstanceId: StringID(),
			idfv: nil,
			idfa: nil,
			hasLimitedAdTracking: true,
			trackingId: nil,
			trackingProvider: nil,
			countryIso: nil
		)
		XCTAssertEqual(dto.deviceId, "")
		XCTAssertEqual(dto.advertiserId, "")
		XCTAssertEqual(dto.trackingId, "")
		XCTAssertEqual(dto.trackingProvider, "")
		XCTAssertNil(dto.countryIso)
		XCTAssertTrue(dto.hasLimitedAdTracking)
	}

	// MARK: - DTOAttributionRequestDevice

	func testAttributionRequestDeviceRoundtrip() throws {
		let dto = DTOAttributionRequestDevice.fixture()
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOAttributionRequestDevice.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	func testAttributionRequestDeviceTypeStringValue() throws {
		let phoneDevice = DTOAttributionRequestDevice.fixture(type: .phone)
		let tabletDevice = DTOAttributionRequestDevice.fixture(type: .tablet)
		let phoneData = try JSONEncoder().encode(phoneDevice)
		let tabletData = try JSONEncoder().encode(tabletDevice)
		let phoneJson = try JSONSerialization.jsonObject(with: phoneData) as! [String: Any]  // swiftlint:disable:this force_cast
		let tabletJson = try JSONSerialization.jsonObject(with: tabletData) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertEqual(phoneJson["type"] as? String, "phone")
		XCTAssertEqual(tabletJson["type"] as? String, "tablet")
	}

	// MARK: - DTOAttributionRequestDeviceOS

	func testAttributionRequestDeviceOSRoundtrip() throws {
		let dto = DTOAttributionRequestDeviceOS(version: "16.0", name: "iOS")
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOAttributionRequestDeviceOS.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	// MARK: - DTOAttributionRequestDeviceDisplay

	func testAttributionRequestDeviceDisplayRoundtrip() throws {
		let dto = DTOAttributionRequestDeviceDisplay(width: 390, height: 844)
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOAttributionRequestDeviceDisplay.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	// MARK: - DTOAttributionResponse

	func testAttributionResponseDecodesValidJson() throws {
		let json = """
			{
				"user": {
					"installId": "41C70613-2994-42DC-BBE1-325968AF9000",
					"type": "organic",
					"redownload": false,
					"testGroup": 5
				},
				"attribution": {
					"campaign": {"externalId": "1", "name": "campaign", "type": "ua", "organic": true},
					"channel": {"id": 2, "name": "channel", "incent": false},
					"network": {"id": 3, "name": "network"},
					"sourceId": "src1",
					"sourceBundleId": "com.test",
					"sourcePlacement": "banner",
					"adsetId": "adset1",
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		let response = try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false)
		XCTAssertEqual(response.installId.value, "41c70613-2994-42dc-bbe1-325968af9000")
		XCTAssertEqual(response.userType, "organic")
		XCTAssertFalse(response.isRedownload)
		XCTAssertEqual(response.campaign.id, "1")
		XCTAssertEqual(response.campaign.name, "campaign")
		XCTAssertEqual(response.campaign.type, "ua")
		XCTAssertTrue(response.campaign.isOrganic)
		XCTAssertEqual(response.channel.id, 2)
		XCTAssertEqual(response.channel.name, "channel")
		XCTAssertFalse(response.channel.isIncent)
		XCTAssertEqual(response.partner.id, 3)
		XCTAssertEqual(response.partner.name, "network")
		XCTAssertEqual(response.sourceId, "src1")
		XCTAssertEqual(response.sourceBundleId, "com.test")
		XCTAssertEqual(response.sourcePlacement, "banner")
		XCTAssertEqual(response.adsetId, "adset1")
		XCTAssertNil(response.retargetingParameters)
	}

	func testAttributionResponseDecodesRetargeting() throws {
		let json = """
			{
				"user": {
					"installId": "41C70613-2994-42DC-BBE1-325968AF9000",
					"type": "retargeting",
					"redownload": true
				},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "rt", "organic": false},
					"channel": {"id": 2, "name": "ch", "incent": true},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2024-06-15T12:30:00Z"
				},
				"retargeting": {
					"url": "https://example.com/deep",
					"attributes": {"key1": "val1", "key2": "val2"}
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		let response = try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: true)
		XCTAssertNotNil(response.retargetingParameters)
		XCTAssertEqual(response.retargetingParameters?.url?.absoluteString, "https://example.com/deep")
		XCTAssertTrue(response.retargetingParameters?.wasAlreadyInstalled ?? false)
	}

	func testAttributionResponseThrowsOnInvalidJson() {
		let data = Data("not json".utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnMissingInstallId() {
		let json = """
			{
				"user": {"type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "ua", "organic": true},
					"channel": {"id": 2, "name": "ch", "incent": false},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnInvalidInstallId() {
		let json = """
			{
				"user": {"installId": "not-a-uuid", "type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "ua", "organic": true},
					"channel": {"id": 2, "name": "ch", "incent": false},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnMissingUserType() {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "ua", "organic": true},
					"channel": {"id": 2, "name": "ch", "incent": false},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnMissingRedownload() {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic"},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "ua", "organic": true},
					"channel": {"id": 2, "name": "ch", "incent": false},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnMissingAttribution() {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnMissingCampaign() {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false},
				"attribution": {
					"channel": {"id": 2, "name": "ch", "incent": false},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnMissingExternalId() {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"name": "c", "type": "ua", "organic": true},
					"channel": {"id": 2, "name": "ch", "incent": false},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseDecodesEmptyExternalId() throws {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "", "name": "c", "type": "ua", "organic": true},
					"channel": {"id": 2, "name": "ch", "incent": false},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		let response = try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false)
		XCTAssertEqual(response.campaign.id, "")
		XCTAssertEqual(response.campaign.name, "c")
	}

	func testAttributionResponseThrowsOnMissingCampaignName() {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "1", "type": "ua", "organic": true},
					"channel": {"id": 2, "name": "ch", "incent": false},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnMissingCampaignType() {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "organic": true},
					"channel": {"id": 2, "name": "ch", "incent": false},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnMissingCampaignOrganic() {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "ua"},
					"channel": {"id": 2, "name": "ch", "incent": false},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseDecodesWithoutAttributionType() throws {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "ua", "organic": true},
					"channel": {"id": 2, "name": "ch", "incent": false},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		let response = try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false)
		XCTAssertEqual(response.campaign.id, "1")
	}

	func testAttributionResponseThrowsOnMissingChannel() {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "ua", "organic": true},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnMissingChannelId() {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "ua", "organic": true},
					"channel": {"name": "ch", "incent": false},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnMissingChannelName() {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "ua", "organic": true},
					"channel": {"id": 2, "incent": false},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnMissingChannelIncent() {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "ua", "organic": true},
					"channel": {"id": 2, "name": "ch"},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnMissingNetwork() {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "ua", "organic": true},
					"channel": {"id": 2, "name": "ch", "incent": false},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnMissingNetworkId() {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "ua", "organic": true},
					"channel": {"id": 2, "name": "ch", "incent": false},
					"network": {"name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnMissingNetworkName() {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "ua", "organic": true},
					"channel": {"id": 2, "name": "ch", "incent": false},
					"network": {"id": 3},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnMissingAttributedAt() {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "ua", "organic": true},
					"channel": {"id": 2, "name": "ch", "incent": false},
					"network": {"id": 3, "name": "n"}
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnInvalidAttributedAt() {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "ua", "organic": true},
					"channel": {"id": 2, "name": "ch", "incent": false},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "not-a-date"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseDecodesRetargetingWithoutUrl() throws {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "retargeting", "redownload": true},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "rt", "organic": false},
					"channel": {"id": 2, "name": "ch", "incent": true},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2024-06-15T12:30:00Z"
				},
				"retargeting": {
					"attributes": {"key1": "val1"}
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		let response = try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false)
		XCTAssertNotNil(response.retargetingParameters)
		XCTAssertNil(response.retargetingParameters?.url)
	}

	func testAttributionResponseDecodesRetargetingWithoutAttributes() throws {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "retargeting", "redownload": true},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "rt", "organic": false},
					"channel": {"id": 2, "name": "ch", "incent": true},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2024-06-15T12:30:00Z"
				},
				"retargeting": {
					"url": "https://example.com/deep"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		let response = try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false)
		XCTAssertNotNil(response.retargetingParameters)
		XCTAssertEqual(response.retargetingParameters?.url?.absoluteString, "https://example.com/deep")
	}

	func testAttributionResponseDecodesWithoutOptionalSourceFields() throws {
		let json = """
			{
				"user": {"installId": "41C70613-2994-42DC-BBE1-325968AF9000", "type": "organic", "redownload": false},
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "ua", "organic": true},
					"channel": {"id": 2, "name": "ch", "incent": false},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		let response = try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false)
		XCTAssertNil(response.sourceId)
		XCTAssertNil(response.sourceBundleId)
		XCTAssertNil(response.sourcePlacement)
		XCTAssertNil(response.adsetId)
	}

	func testAttributionResponseThrowsOnNonObjectJson() {
		let data = Data("[1, 2, 3]".utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	func testAttributionResponseThrowsOnMissingUser() {
		let json = """
			{
				"attribution": {
					"campaign": {"externalId": "1", "name": "c", "type": "ua", "organic": true},
					"channel": {"id": 2, "name": "ch", "incent": false},
					"network": {"id": 3, "name": "n"},
					"attributedAt": "2025-01-01T00:00:00Z"
				}
			}
			"""
		let data = Data(json.utf8)
		let userId = StringID(value: "AC9BA146-B518-4E2D-8946-047A1B93E35C")!
		XCTAssertThrowsError(try DTOAttributionResponse(userId: userId, data: data, wasAlreadyInstalled: false))
	}

	// MARK: - DTOAssignment

	func testAssignmentRoundtrip() throws {
		let dto = DTOAssignment.fixture()
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOAssignment.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	func testAssignmentDecodesWithNilPending() throws {
		let json = """
			{
				"experiment": "exp",
				"variant": "var",
				"experimentId": "eid",
				"variantId": "vid",
				"configKey": "key",
				"configValue": "val"
			}
			"""
		let data = Data(json.utf8)
		let decoded = try JSONDecoder().decode(DTOAssignment.self, from: data)
		XCTAssertNil(decoded.pending)
		XCTAssertEqual(decoded.experiment, "exp")
	}

	// MARK: - DTOGetAssignmentsResponse

	func testGetAssignmentsResponseDecodesAssignments() throws {
		let json = """
			{
				"assignments": [
					{
						"experiment": "exp1",
						"variant": "control",
						"experimentId": "eid1",
						"variantId": "vid1",
						"configKey": "key1",
						"configValue": "val1",
						"pending": true
					}
				]
			}
			"""
		let data = Data(json.utf8)
		let response = try DTOGetAssignmentsResponse(data: data)
		XCTAssertEqual(response.assignments.count, 1)
		XCTAssertEqual(response.assignments[0].experiment, "exp1")
	}

	func testGetAssignmentsResponseDecodesNullAssignments() throws {
		let json = """
			{"assignments": null}
			"""
		let data = Data(json.utf8)
		let response = try DTOGetAssignmentsResponse(data: data)
		XCTAssertTrue(response.assignments.isEmpty)
	}

	func testGetAssignmentsResponseDirectInit() {
		let assignment = DTOAssignment.fixture()
		let response = DTOGetAssignmentsResponse(assignments: [assignment])
		XCTAssertEqual(response.assignments.count, 1)
		XCTAssertEqual(response.assignments[0], assignment)
	}

	// MARK: - DTOLogMessage

	func testLogMessageRoundtrip() throws {
		let dto = DTOLogMessage.fixture(fields: ["key": "value"])
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOLogMessage.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	func testLogMessageEncodeAndInitFromEncoded() {
		let dto = DTOLogMessage.fixture(fields: ["f1": "v1"])
		let encoded = dto.encode()
		let restored = DTOLogMessage(encoded: encoded)
		XCTAssertNotNil(restored)
		XCTAssertEqual(restored, dto)
	}

	func testLogMessageInitFromEncodedReturnsNilForInvalid() {
		let invalid: [String: Any] = ["level": "warn"]
		let result = DTOLogMessage(encoded: invalid)
		XCTAssertNil(result)
	}

	func testLogMessageInitFromEncodedReturnsNilForInvalidFields() {
		let invalid: [String: Any] = [
			"level": "warn",
			"message": "msg",
			"fields": ["key": 123],
			"timestamp": "1970-01-01T00:00:00.041Z",
		]
		let result = DTOLogMessage(encoded: invalid)
		XCTAssertNil(result)
	}

	func testLogMessageInitFromEncodedReturnsNilForInvalidTimestamp() {
		let invalid: [String: Any] = [
			"level": "warn",
			"message": "msg",
			"fields": [String: String](),
			"timestamp": "not-a-date",
		]
		let result = DTOLogMessage(encoded: invalid)
		XCTAssertNil(result)
	}

	// MARK: - DTOLogMetric

	func testLogMetricRoundtrip() throws {
		let dto = DTOLogMetric.fixture(dimensions: ["dim1": "val1"])
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOLogMetric.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	func testLogMetricEncodeAndInitFromEncoded() {
		let dto = DTOLogMetric.fixture(dimensions: ["d1": "v1"])
		let encoded = dto.encode()
		let restored = DTOLogMetric(encoded: encoded)
		XCTAssertNotNil(restored)
		XCTAssertEqual(restored, dto)
	}

	func testLogMetricInitFromEncodedReturnsNilForInvalid() {
		let invalid: [String: Any] = ["metric": "m"]
		let result = DTOLogMetric(encoded: invalid)
		XCTAssertNil(result)
	}

	func testLogMetricInitFromEncodedReturnsNilForInvalidDimensions() {
		let invalid: [String: Any] = [
			"metric": "m",
			"dimensions": ["key": 123],
			"value": 1.0,
			"unit": "count",
			"timestamp": "1970-01-01T00:00:00.041Z",
		]
		let result = DTOLogMetric(encoded: invalid)
		XCTAssertNil(result)
	}

	func testLogMetricInitFromEncodedReturnsNilForInvalidTimestamp() {
		let invalid: [String: Any] = [
			"metric": "m",
			"dimensions": [String: String](),
			"value": 1.0,
			"unit": "count",
			"timestamp": "bad",
		]
		let result = DTOLogMetric(encoded: invalid)
		XCTAssertNil(result)
	}

	// MARK: - DTOLogInput

	func testLogInputRoundtrip() throws {
		let dto = DTOLogInput(
			messages: [.fixture()],
			metrics: [.fixture()],
			appVersion: .fixture(),
			sdkVersion: .fixture(),
			clientDate: Date(timeIntervalSince1970: 100)
		)
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOLogInput.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	func testLogInputJson() throws {
		let dto = DTOLogInput(
			messages: [],
			metrics: [],
			appVersion: .fixture(),
			sdkVersion: .fixture(),
			clientDate: Date(timeIntervalSince1970: 0)
		)
		let data = try dto.json()
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertEqual(json["clientDate"] as? String, "1970-01-01T00:00:00.000Z")
		XCTAssertNotNil(json["appVersion"])
		XCTAssertNotNil(json["sdkVersion"])
	}

	// MARK: - DTOPostEnrollmentRequest

	func testPostEnrollmentRequestRoundtrip() throws {
		let dto = DTOPostEnrollmentRequest(
			installInstanceId: "install-123",
			experimentIds: ["exp1", "exp2"]
		)
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOPostEnrollmentRequest.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	func testPostEnrollmentRequestConvenienceInit() {
		let installId = StringID(value: "41C70613-2994-42DC-BBE1-325968AF9000")!
		let dto = DTOPostEnrollmentRequest(installId: installId, experimentIds: ["exp1"])
		XCTAssertEqual(dto.installInstanceId, "41c70613-2994-42dc-bbe1-325968af9000")
		XCTAssertEqual(dto.experimentIds, ["exp1"])
	}

	func testPostEnrollmentRequestJsonUsesSortedKeys() throws {
		let dto = DTOPostEnrollmentRequest(
			installInstanceId: "install-123",
			experimentIds: ["exp1"]
		)
		let data = try dto.json()
		let jsonString = String(data: data, encoding: .utf8)!
		let experimentIdsIndex = jsonString.range(of: "experimentIds")!.lowerBound
		let installIndex = jsonString.range(of: "installInstanceId")!.lowerBound
		XCTAssertTrue(experimentIdsIndex < installIndex, "Keys should be sorted alphabetically")
	}

	// MARK: - DTOPostEnrollmentResponse

	func testPostEnrollmentResponseDecodes() throws {
		let json = """
			{
				"enrolledAssignments": [
					{
						"experiment": "exp",
						"variant": "var",
						"experimentId": "eid",
						"variantId": "vid",
						"configKey": "key",
						"configValue": "val",
						"pending": false
					}
				]
			}
			"""
		let data = Data(json.utf8)
		let response = try DTOPostEnrollmentResponse(data: data)
		XCTAssertEqual(response.enrolledAssignments.count, 1)
		XCTAssertEqual(response.enrolledAssignments[0].experiment, "exp")
		XCTAssertEqual(response.enrolledAssignments[0].pending, false)
	}

	func testPostEnrollmentResponseDirectInit() {
		let assignment = DTOAssignment.fixture()
		let response = DTOPostEnrollmentResponse(enrolledAssignments: [assignment])
		XCTAssertEqual(response.enrolledAssignments.count, 1)
	}

	// MARK: - DTOPublishCustomUserIdRequest

	func testPublishCustomUserIdRequestRoundtrip() throws {
		let dto = DTOPublishCustomUserIdRequest(installId: "install-1", customUserId: "user-1")
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOPublishCustomUserIdRequest.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	func testPublishCustomUserIdRequestJson() throws {
		let dto = DTOPublishCustomUserIdRequest(installId: "install-1", customUserId: "user-1")
		let data = try dto.json()
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertEqual(json["installId"] as? String, "install-1")
		XCTAssertEqual(json["customUserId"] as? String, "user-1")
	}

	// MARK: - DTOPublishFirebaseAppInstanceIdRequest

	func testPublishFirebaseAppInstanceIdRequestRoundtrip() throws {
		let dto = DTOPublishFirebaseAppInstanceIdRequest(uuid: "uuid-1", firebaseInstanceId: "fid-1")
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOPublishFirebaseAppInstanceIdRequest.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	func testPublishFirebaseAppInstanceIdRequestJson() throws {
		let dto = DTOPublishFirebaseAppInstanceIdRequest(uuid: "uuid-1", firebaseInstanceId: "fid-1")
		let data = try dto.json()
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertEqual(json["uuid"] as? String, "uuid-1")
		XCTAssertEqual(json["firebaseInstanceId"] as? String, "fid-1")
	}

	// MARK: - DTOSetExperimentVariantRequest

	func testSetExperimentVariantRequestRoundtrip() throws {
		let dto = DTOSetExperimentVariantRequest(
			installInstanceId: "install-1",
			justtrackSdkVersion: "1.0.0",
			appVersionName: "2.0.0",
			appVersionCode: "42",
			osVersion: "16.0",
			experiment: "exp1",
			variant: "control",
			tags: ["tag1", "tag2"],
			happenedAt: "2025-01-01T00:00:00.000Z"
		)
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOSetExperimentVariantRequest.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	func testSetExperimentVariantRequestJsonUsesSortedKeys() throws {
		let dto = DTOSetExperimentVariantRequest(
			installInstanceId: "install-1",
			justtrackSdkVersion: "1.0.0",
			appVersionName: "2.0.0",
			appVersionCode: "42",
			osVersion: "16.0",
			experiment: "exp1",
			variant: "control",
			tags: [],
			happenedAt: nil
		)
		let data = try dto.json()
		let jsonString = String(data: data, encoding: .utf8)!
		let appIndex = jsonString.range(of: "appVersionCode")!.lowerBound
		let expIndex = jsonString.range(of: "experiment")!.lowerBound
		XCTAssertTrue(appIndex < expIndex, "Keys should be sorted alphabetically")
	}

	func testSetExperimentVariantRequestConvenienceInitWithDate() throws {
		let date = Date(timeIntervalSince1970: 1_735_689_600)  // 2025-01-01T00:00:00Z
		let installId = StringID(value: "41C70613-2994-42DC-BBE1-325968AF9000")!
		let dto = DTOSetExperimentVariantRequest(
			installId: installId,
			sdkVersion: currentSdkVersion(),
			appVersion: AppVersionImpl(code: "42", name: "2.0.0"),
			osVersion: "16.0",
			experiment: "exp1",
			variant: "control",
			tags: ["tag1"],
			happenedAt: date
		)
		XCTAssertEqual(dto.installInstanceId, installId.value)
		XCTAssertNotNil(dto.happenedAt)
		XCTAssertTrue(dto.happenedAt!.contains("2025-01-01"))
	}

	func testSetExperimentVariantRequestConvenienceInitWithNilDate() throws {
		let installId = StringID(value: "41C70613-2994-42DC-BBE1-325968AF9000")!
		let dto = DTOSetExperimentVariantRequest(
			installId: installId,
			sdkVersion: currentSdkVersion(),
			appVersion: AppVersionImpl(code: "42", name: "2.0.0"),
			osVersion: "16.0",
			experiment: "exp1",
			variant: "control",
			tags: [],
			happenedAt: nil
		)
		XCTAssertNil(dto.happenedAt)
	}

	func testSetExperimentVariantRequestNilHappenedAt() throws {
		let dto = DTOSetExperimentVariantRequest(
			installInstanceId: "install-1",
			justtrackSdkVersion: "1.0.0",
			appVersionName: "2.0.0",
			appVersionCode: "42",
			osVersion: "16.0",
			experiment: "exp1",
			variant: "control",
			tags: [],
			happenedAt: nil
		)
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOSetExperimentVariantRequest.self, from: data)
		XCTAssertNil(decoded.happenedAt)
	}

	// MARK: - DTOSignIPResponse

	func testSignIPResponseDecodesValidJson() throws {
		let json = """
			{"ip": "1.2.3.4", "type": "ipv4", "token": "abc123"}
			"""
		let data = Data(json.utf8)
		let response = try DTOSignIPResponse(data: data)
		XCTAssertEqual(response.ip, "1.2.3.4")
		XCTAssertEqual(response.type, "ipv4")
		XCTAssertEqual(response.token, "abc123")
	}

	func testSignIPResponseThrowsOnInvalidJson() {
		let data = Data("not json".utf8)
		XCTAssertThrowsError(try DTOSignIPResponse(data: data))
	}

	func testSignIPResponseThrowsOnMissingField() {
		let json = """
			{"ip": "1.2.3.4", "type": "ipv4"}
			"""
		let data = Data(json.utf8)
		XCTAssertThrowsError(try DTOSignIPResponse(data: data))
	}

	func testSignIPResponseThrowsOnMissingIp() {
		let json = """
			{"type": "ipv4", "token": "abc123"}
			"""
		let data = Data(json.utf8)
		XCTAssertThrowsError(try DTOSignIPResponse(data: data))
	}

	func testSignIPResponseThrowsOnMissingType() {
		let json = """
			{"ip": "1.2.3.4", "token": "abc123"}
			"""
		let data = Data(json.utf8)
		XCTAssertThrowsError(try DTOSignIPResponse(data: data))
	}

	func testSignIPResponseThrowsOnNonObjectJson() {
		let data = Data("[1, 2, 3]".utf8)
		XCTAssertThrowsError(try DTOSignIPResponse(data: data))
	}

	// MARK: - DTOUserEventDevice

	func testUserEventDeviceRoundtrip() throws {
		let dto = DTOUserEventDevice.fixture()
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOUserEventDevice.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	func testUserEventDeviceFormatsDate() throws {
		let dto = DTOUserEventDevice(
			connectionType: "wifi",
			os: .fixture(),
			date: Date(timeIntervalSince1970: 0)
		)
		let data = try JSONEncoder().encode(dto)
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertEqual(json["date"] as? String, "1970-01-01T00:00:00.000Z")
	}

	// MARK: - DTOUserEventDeviceOS

	func testUserEventDeviceOSRoundtrip() throws {
		let dto = DTOUserEventDeviceOS.fixture()
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOUserEventDeviceOS.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	// MARK: - DTOUserEventUser

	func testUserEventUserRoundtrip() throws {
		let dto = DTOUserEventUser.fixture()
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOUserEventUser.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	func testUserEventUserOmitsNilFields() throws {
		let dto = DTOUserEventUser(
			installInstanceId: "install-1",
			countryIso: nil,
			localeCode: nil,
			deviceId: nil,
			idfv: nil,
			userId: nil
		)
		let data = try JSONEncoder().encode(dto)
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertEqual(json["installInstanceId"] as? String, "install-1")
		XCTAssertNil(json["countryIso"])
		XCTAssertNil(json["localeCode"])
		XCTAssertNil(json["deviceId"])
		XCTAssertNil(json["idfv"])
		XCTAssertNil(json["userId"])
	}

	func testUserEventUserIncludesNonNilFields() throws {
		let dto = DTOUserEventUser.fixture()
		let data = try JSONEncoder().encode(dto)
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertNotNil(json["countryIso"])
		XCTAssertNotNil(json["localeCode"])
		XCTAssertNotNil(json["deviceId"])
		XCTAssertNotNil(json["idfv"])
		XCTAssertNotNil(json["userId"])
	}

	// MARK: - DTOUserEventEvent

	func testUserEventEventRoundtrip() throws {
		let dto = DTOUserEventEvent.fixture()
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOUserEventEvent.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	func testUserEventEventOmitsDimensionsWhenEmpty() throws {
		let dto = DTOUserEventEvent.fixture(dimensions: [:])
		let data = try JSONEncoder().encode(dto)
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertNil(json["dimensions"])
	}

	func testUserEventEventIncludesDimensionsWhenNonEmpty() throws {
		let dto = DTOUserEventEvent.fixture(dimensions: ["key": "value"])
		let data = try JSONEncoder().encode(dto)
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertNotNil(json["dimensions"])
	}

	func testUserEventEventOmitsValueWhenNoUnitOrCurrency() throws {
		let dto = DTOUserEventEvent.fixture(value: 5.0, unit: nil, currency: nil)
		let data = try JSONEncoder().encode(dto)
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertNil(json["value"])
		XCTAssertNil(json["unit"])
		XCTAssertNil(json["currency"])
	}

	func testUserEventEventIncludesValueWhenUnitPresent() throws {
		let dto = DTOUserEventEvent.fixture(value: 42.0, unit: .count, currency: nil)
		let data = try JSONEncoder().encode(dto)
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertEqual(json["value"] as? Double, 42.0)
		XCTAssertEqual(json["unit"] as? String, "count")
		XCTAssertNil(json["currency"])
	}

	func testUserEventEventIncludesValueWhenCurrencyPresent() throws {
		let dto = DTOUserEventEvent.fixture(value: 9.99, unit: nil, currency: "USD")
		let data = try JSONEncoder().encode(dto)
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertEqual(json["value"] as? Double, 9.99)
		XCTAssertEqual(json["currency"] as? String, "USD")
		XCTAssertNil(json["unit"])
	}

	func testUserEventEventDecodesWithMissingOptionalFields() throws {
		let json = """
			{
				"id": "e1",
				"name": "event1",
				"sessionId": "s1",
				"happenedAt": "2025-01-01T00:00:00.000Z",
				"sequenceNumber": 1
			}
			"""
		let data = Data(json.utf8)
		let decoded = try JSONDecoder().decode(DTOUserEventEvent.self, from: data)
		XCTAssertEqual(decoded.id, "e1")
		XCTAssertEqual(decoded.name, "event1")
		XCTAssertTrue(decoded.dimensions.isEmpty)
		XCTAssertEqual(decoded.value, 0)
		XCTAssertNil(decoded.unit)
		XCTAssertNil(decoded.currency)
	}

	func testUserEventEventFormatsDate() throws {
		let dto = DTOUserEventEvent.fixture(happenedAt: Date(timeIntervalSince1970: 0))
		let data = try JSONEncoder().encode(dto)
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertEqual(json["happenedAt"] as? String, "1970-01-01T00:00:00.000Z")
	}

	// MARK: - DTOUserEvent (full structure)

	func testUserEventFullRoundtrip() throws {
		let dto = DTOUserEvent.fixture()
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(DTOUserEvent.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	func testUserEventDTOJson() throws {
		let dto = DTOUserEvent.fixture()
		let data = try dto.json()
		let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]  // swiftlint:disable:this force_cast
		XCTAssertNotNil(json["appVersion"])
		XCTAssertNotNil(json["sdkVersion"])
		XCTAssertNotNil(json["user"])
		XCTAssertNotNil(json["device"])
		XCTAssertNotNil(json["events"])
	}

	// MARK: - Breadcrumb

	func testBreadcrumbRoundtrip() throws {
		let dto = Breadcrumb(
			message: "User tapped button",
			category: "ui",
			level: "info",
			timestamp: Date(timeIntervalSince1970: 1000)
		)
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(Breadcrumb.self, from: data)
		XCTAssertEqual(dto, decoded)
	}

	// MARK: - NativeCrashReport

	func testNativeCrashReportExceptionRoundtrip() throws {
		let dto = NativeCrashReport(
			timestamp: 1000.0,
			reportType: .exception,
			name: "NSInvalidArgumentException",
			reason: "unrecognized selector",
			callStack: "frame1\nframe2",
			signalInfo: nil
		)
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(NativeCrashReport.self, from: data)
		XCTAssertEqual(decoded.timestamp, 1000.0)
		XCTAssertEqual(decoded.reportType, .exception)
		XCTAssertEqual(decoded.name, "NSInvalidArgumentException")
		XCTAssertEqual(decoded.reason, "unrecognized selector")
		XCTAssertEqual(decoded.callStack, "frame1\nframe2")
		XCTAssertNil(decoded.signalInfo)
	}

	func testNativeCrashReportSignalRoundtrip() throws {
		let signalInfo = NativeCrashReport.SignalInfo(
			errorNumber: "0",
			signalCode: "1",
			signalNumber: "11",
			sendingProcess: "1234",
			senderRuid: "501",
			exitValue: "0",
			signalValue: "0",
			faultingAddress: "0x0000"
		)
		let dto = NativeCrashReport(
			timestamp: 2000.0,
			reportType: .signal,
			name: "SIGSEGV",
			reason: nil,
			callStack: "frame1",
			signalInfo: signalInfo
		)
		let data = try JSONEncoder().encode(dto)
		let decoded = try JSONDecoder().decode(NativeCrashReport.self, from: data)
		XCTAssertEqual(decoded.reportType, .signal)
		XCTAssertNil(decoded.reason)
		XCTAssertNotNil(decoded.signalInfo)
		XCTAssertEqual(decoded.signalInfo?.signalNumber, "11")
		XCTAssertEqual(decoded.signalInfo?.faultingAddress, "0x0000")
	}

	func testNativeCrashReportSignalInfoNilFaultingAddress() throws {
		let signalInfo = NativeCrashReport.SignalInfo(
			errorNumber: "0",
			signalCode: "1",
			signalNumber: "11",
			sendingProcess: "1234",
			senderRuid: "501",
			exitValue: "0",
			signalValue: "0",
			faultingAddress: nil
		)
		let data = try JSONEncoder().encode(signalInfo)
		let decoded = try JSONDecoder().decode(NativeCrashReport.SignalInfo.self, from: data)
		XCTAssertNil(decoded.faultingAddress)
	}

	// MARK: - DTODecodingError

	func testDTODecodingErrorDescription() {
		let error = DTODecodingError("test message")
		XCTAssertEqual(error.description, "DTODecodingError: test message")
		XCTAssertEqual(error.message, "test message")
	}
}
