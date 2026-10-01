import Foundation
import XCTest

@testable import JustTrackSDK

final class StoreTests: XCTestCase {
	private let userDefaults = UserDefaults(suiteName: "io.justtrack.test")!

	override func setUpWithError() throws {
		userDefaults.dictionaryRepresentation().keys.forEach { key in
			userDefaults.removeObject(forKey: key)
		}
	}

	func testStoreStoresAttributionInUserDefaults() {
		let store = Store(userDefaults: userDefaults)
		let attribution = AttributionOutput.fixture()

		store.storeAttribution(attribution: attribution)

		XCTAssertTrue(
			userDefaults.dictionary(forKey: Store.attributionKey)!.equals(attribution: AttributionOutput.fixtureDict)
		)
	}

	func testStoreReturnsAttributionFromUserDefaults() {
		let store = Store()
		UserDefaults.standard.setValue(AttributionOutput.fixtureDict, forKey: Store.attributionKey)

		let returnedOutput = store.getStoredOutput()!

		XCTAssertEqual(returnedOutput, .fixture(retargetingParameters: nil))
	}

	func testStoreMigratesV3ToIdentityOnlyV4Data() {
		var legacy = AttributionOutput.fixtureDict
		legacy["version"] = 3
		legacy["campaignId"] = 41
		legacy["type"] = "attribution"
		legacy.removeValue(forKey: "campaignExternalId")
		userDefaults.setValue(legacy, forKey: Store.attributionKey)

		let store = Store(userDefaults: userDefaults)
		let migrated = userDefaults.dictionary(forKey: Store.attributionKey)!

		XCTAssertEqual(Set(migrated.keys), Set(["version", "userId", "installId"]))
		XCTAssertEqual(migrated["version"] as? Int, 4)
		XCTAssertEqual(store.tryGetUserId()?.value, legacy["userId"] as? String)
		XCTAssertEqual(store.getInstallId().value, legacy["installId"] as? String)
		XCTAssertNil(store.getStoredOutput())
	}

	// MARK: - getStoredOutput: missing/invalid keys return nil

	func testStoreRoundTripsEmptyCampaignExternalId() {
		let store = Store(userDefaults: userDefaults)
		let campaign = Campaign(id: "", name: "organic", type: "acquisition", organic: true)
		let response = AttributionResponseImpl.fixture(campaign: campaign)

		store.storeAttribution(attribution: .fixture(attributionResponse: response))

		XCTAssertEqual(userDefaults.dictionary(forKey: Store.attributionKey)?["campaignExternalId"] as? String, "")
		XCTAssertEqual(store.getStoredOutput()?.attributionResponse.campaign.id, "")
	}

	func testGetStoredOutputReturnsNilWhenCampaignExternalIdMissing() {
		let store = Store(userDefaults: userDefaults)
		var dict = AttributionOutput.fixtureDict
		dict.removeValue(forKey: "campaignExternalId")
		dict["campaignId"] = "legacy-campaign-id"
		userDefaults.setValue(dict, forKey: Store.attributionKey)

		XCTAssertNil(store.getStoredOutput())
	}

	func testGetStoredOutputReturnsNilWhenNoData() {
		let store = Store(userDefaults: userDefaults)
		XCTAssertNil(store.getStoredOutput())
	}

	func testGetStoredOutputReturnsNilWhenVersionMismatch() {
		let store = Store(userDefaults: userDefaults)
		userDefaults.setValue(["version": 999], forKey: Store.attributionKey)
		XCTAssertNil(store.getStoredOutput())
	}

	func testGetStoredOutputReturnsNilWhenUserIdMissing() {
		let store = Store(userDefaults: userDefaults)
		var dict = AttributionOutput.fixtureDict
		dict.removeValue(forKey: "userId")
		userDefaults.setValue(dict, forKey: Store.attributionKey)
		XCTAssertNil(store.getStoredOutput())
	}

	func testGetStoredOutputReturnsNilWhenCreatedAtMissing() {
		let store = Store(userDefaults: userDefaults)
		var dict = AttributionOutput.fixtureDict
		dict.removeValue(forKey: "createdAt")
		userDefaults.setValue(dict, forKey: Store.attributionKey)
		XCTAssertNil(store.getStoredOutput())
	}

	func testGetStoredOutputReturnsNilWhenCreatedAtUnparseable() {
		let store = Store(userDefaults: userDefaults)
		var dict = AttributionOutput.fixtureDict
		dict["createdAt"] = "not-a-date"
		userDefaults.setValue(dict, forKey: Store.attributionKey)
		XCTAssertNil(store.getStoredOutput())
	}

	// MARK: - getAttributionTimestamps

	func testGetAttributionTimestampsReturnsNilWhenNoData() {
		let store = Store(userDefaults: userDefaults)
		XCTAssertNil(store.getAttributionTimestamps())
	}

	func testGetAttributionTimestampsReturnsNilWhenFirstAttributedAtMissing() {
		let store = Store(userDefaults: userDefaults)
		userDefaults.setValue(["lastOpenAt": "2024-01-01T00:00:00Z"], forKey: Store.timestampsKey)
		XCTAssertNil(store.getAttributionTimestamps())
	}

	func testGetAttributionTimestampsReturnsNilWhenFirstAttributedAtUnparseable() {
		let store = Store(userDefaults: userDefaults)
		userDefaults.setValue(["firstAttributedAt": "bad-date"], forKey: Store.timestampsKey)
		XCTAssertNil(store.getAttributionTimestamps())
	}

	func testGetAttributionTimestampsFallsBackToFirstAttributedAtWhenLastAttributedAtMissing() {
		let store = Store(userDefaults: userDefaults)
		store.storeAttribution(attribution: .fixture())

		// Remove lastAttributedAt key to exercise fallback branch
		var dict = userDefaults.dictionary(forKey: Store.timestampsKey)!
		dict.removeValue(forKey: "lastAttributedAt")
		userDefaults.setValue(dict, forKey: Store.timestampsKey)

		let timestamps = store.getAttributionTimestamps()
		XCTAssertNotNil(timestamps)
		XCTAssertEqual(
			timestamps?.lastAttributedAt.timeIntervalSince1970 ?? 0,
			timestamps?.firstAttributedAt.timeIntervalSince1970 ?? -1,
			accuracy: 1
		)
	}

	func testGetAttributionTimestampsFallsBackToFirstAttributedAtWhenLastOpenAtMissing() {
		let store = Store(userDefaults: userDefaults)
		store.storeAttribution(attribution: .fixture())

		var dict = userDefaults.dictionary(forKey: Store.timestampsKey)!
		dict.removeValue(forKey: "lastOpenAt")
		userDefaults.setValue(dict, forKey: Store.timestampsKey)

		let timestamps = store.getAttributionTimestamps()
		XCTAssertNotNil(timestamps)
		XCTAssertEqual(
			timestamps?.lastOpenAt.timeIntervalSince1970 ?? 0,
			timestamps?.firstAttributedAt.timeIntervalSince1970 ?? -1,
			accuracy: 1
		)
	}

	// MARK: - getAppVersionUpdateInfo

	func testGetAppVersionUpdateInfoReturnsInstalledAppWhenNoStoredVersion() {
		let store = Store(userDefaults: userDefaults)
		let current = AppVersionImpl(code: "1.0.0", name: "1.0.0")

		let info = store.getAppVersionUpdateInfo(currentVersion: current)

		XCTAssertEqual(info.kind, .installedApp)
	}

	func testGetAppVersionUpdateInfoReturnsNoChangeWhenVersionUnchanged() {
		let store = Store(userDefaults: userDefaults)
		let v1 = AppVersionImpl(code: "2.0.0", name: "2.0.0")

		// First call stores the version
		_ = store.getAppVersionUpdateInfo(currentVersion: v1)
		// Second call with same version
		let info = store.getAppVersionUpdateInfo(currentVersion: v1)

		XCTAssertEqual(info.kind, .noChange)
	}

	func testGetAppVersionUpdateInfoReturnsUpdatedAppWhenVersionChanged() {
		let store = Store(userDefaults: userDefaults)
		let v1 = AppVersionImpl(code: "1.0.0", name: "1.0.0")
		let v2 = AppVersionImpl(code: "2.0.0", name: "2.0.0")

		// Install at v1
		_ = store.getAppVersionUpdateInfo(currentVersion: v1)
		// Update to v2
		let info = store.getAppVersionUpdateInfo(currentVersion: v2)

		XCTAssertEqual(info.kind, .updatedApp)
	}

	// MARK: - readStoredAppVersion: old major/minor format

	func testReadStoredAppVersionWithOldMajorMinorFormat() {
		let store = Store(userDefaults: userDefaults)
		// Write in old format (major: UInt32, minor: UInt32, no code key)
		let oldFormat: [String: Any] = ["major": UInt32(3), "minor": UInt32(1), "name": "3.1"]
		userDefaults.setValue(oldFormat, forKey: Store.appVersionAtInstallKey)

		// readAppVersionAtInstall uses readStoredAppVersion internally
		let v = store.readAppVersionAtInstall(currentVersion: AppVersionImpl(code: "3.1.0", name: "3.1"))
		XCTAssertEqual(v.code, "3.1.0")
	}

	func testReadStoredAppVersionReturnsNilForUnrecognizedFormatAndFallsBackToCurrent() {
		// Exercises the `return nil` branch in readStoredAppVersion when the persisted dictionary
		// matches neither the new (code/name) nor the legacy (major/minor) shape: readAppVersionAtInstall
		// then writes the currentVersion and returns it.
		let store = Store(userDefaults: userDefaults)
		let malformed: [String: Any] = ["unexpected": "value"]
		userDefaults.setValue(malformed, forKey: Store.appVersionAtInstallKey)

		let current = AppVersionImpl(code: "9.9.9", name: "9.9")
		let v = store.readAppVersionAtInstall(currentVersion: current)

		XCTAssertEqual(v.code, "9.9.9")
		XCTAssertEqual(v.name, "9.9")
	}

	func testReadAppVersionAtInstallReturnsSavedVersionOnSubsequentCall() {
		let store = Store(userDefaults: userDefaults)
		let v1 = AppVersionImpl(code: "1.0.0", name: "1.0")
		let v2 = AppVersionImpl(code: "2.0.0", name: "2.0")

		let first = store.readAppVersionAtInstall(currentVersion: v1)
		let second = store.readAppVersionAtInstall(currentVersion: v2)

		// Both calls should return the version at install (v1)
		XCTAssertEqual(first.code, "1.0.0")
		XCTAssertEqual(second.code, "1.0.0")
	}

	// MARK: - setFirstSdkInitTimestamp: idempotency

	func testSetFirstSdkInitTimestampIsIdempotent() {
		let store = Store(userDefaults: userDefaults)
		let t1 = Date(timeIntervalSince1970: 1_000_000)
		let t2 = Date(timeIntervalSince1970: 2_000_000)

		store.setFirstSdkInitTimestamp(t1)
		store.setFirstSdkInitTimestamp(t2)  // should be ignored

		let stored = store.getFirstSdkInitTimestamp()
		XCTAssertEqual(stored?.timeIntervalSince1970 ?? 0, t1.timeIntervalSince1970, accuracy: 0.001)
	}

	func testGetFirstSdkInitTimestampReturnsNilWhenNotSet() {
		let store = Store(userDefaults: userDefaults)
		XCTAssertNil(store.getFirstSdkInitTimestamp())
	}

	// MARK: - setLastOpen

	func testSetLastOpenUpdatesTimestamps() {
		let store = Store(userDefaults: userDefaults)
		store.storeAttribution(attribution: .fixture())

		let beforeSet = store.getAttributionTimestamps()
		Thread.sleep(forTimeInterval: 0.01)
		store.setLastOpen()
		let afterSet = store.getAttributionTimestamps()

		XCTAssertNotNil(afterSet)
		XCTAssertGreaterThanOrEqual(
			afterSet?.lastOpenAt.timeIntervalSince1970 ?? 0,
			beforeSet?.lastOpenAt.timeIntervalSince1970 ?? 0
		)
	}

	// MARK: - getUserId / getInstallId round-trip

	func testGetUserIdReturnsSameIdOnRepeatedCalls() {
		let store = Store(userDefaults: userDefaults)
		let id1 = store.getUserId(bundleId: "com.test", uniqueId: "unique")
		let id2 = store.getUserId(bundleId: "com.test", uniqueId: "unique")
		XCTAssertEqual(id1.value, id2.value)
	}

	func testGetInstallIdReturnsSameIdOnRepeatedCalls() {
		let store = Store(userDefaults: userDefaults)
		let id1 = store.getInstallId()
		let id2 = store.getInstallId()
		XCTAssertEqual(id1.value, id2.value)
	}
}

fileprivate extension [String: Any] {
	func equals(attribution dict: [String: Any]) -> Bool {
		guard keys == dict.keys else { return false }

		for key in keys {
			guard let value1 = self[key], let value2 = dict[key] else { return false }

			if let value1 = value1 as? String, let value2 = value2 as? String {
				guard value1 == value2 else { return false }
			} else if let value1 = value1 as? Int, let value2 = value2 as? Int {
				guard value1 == value2 else { return false }
			} else if let value1 = value1 as? Bool, let value2 = value2 as? Bool {
				guard value1 == value2 else { return false }
			} else {
				return false
			}
		}

		return true
	}
}
