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
			} else if let value1 = value1 as? Data,
				let value2 = value2 as? Data,
				let sdkConfig1 = try? JSONDecoder().decode(AttributionOutputSdkConfig.self, from: value1),
				let sdkConfig2 = try? JSONDecoder().decode(AttributionOutputSdkConfig.self, from: value2)
			{
				guard sdkConfig1 == sdkConfig2 else { return false }
			} else {
				return false
			}
		}

		return true
	}
}
