import StoreKit
import XCTest

@testable import JustTrackSDK

final class SKAdNetworkTests: XCTestCase {
	override func setUpWithError() throws {
		UserDefaults.standard.removeObject(forKey: Store.postbackConversionValueSetKey)
	}

	@available(iOS 11.3, *)
	func testConversionValueSetIsSavedInUserDefaultsDuringRegisterAppForAdNetworkAttributionCall() {
		SKAdNetwork.registerAppForAdNetworkAttribution()

		XCTAssert(UserDefaults.standard.bool(forKey: Store.postbackConversionValueSetKey))
	}

	@available(iOS 14.0, *)
	func testConversionValueIsSavedInUserDefaultsDuringUpdateConversionValueCall() {
		SKAdNetwork.updateConversionValue(Int.random(in: 1...63))

		XCTAssert(UserDefaults.standard.bool(forKey: Store.postbackConversionValueSetKey))
	}

	@available(iOS 15.4, *)
	func testConversionValueSetIsSavedInUserDefaultsDuringUpdatePostbackConversionValueCompletionHandlerCall() {
		SKAdNetwork.updatePostbackConversionValue(Int.random(in: 1...63), completionHandler: nil)

		XCTAssert(UserDefaults.standard.bool(forKey: Store.postbackConversionValueSetKey))
	}

	@available(iOS 16.1, *)
	func testConversionValueSetIsSavedInUserDefaultsDuringUpdatePostbackConversionValueCoarseValueCompletionHandlerCall() {
		let conversionValue = Int.random(in: 1...63)
		let coarseValue = [SKAdNetwork.CoarseConversionValue.low, .medium, .high].randomElement() ?? .low

		SKAdNetwork.updatePostbackConversionValue(conversionValue, coarseValue: coarseValue, completionHandler: nil)

		XCTAssert(UserDefaults.standard.bool(forKey: Store.postbackConversionValueSetKey))
	}

	@available(iOS 16.1, *)
	func testConversionValueSetIsSavedInUserDefaultsDuringUpdatePostbackConversionValueCoarseValueLockWindowCompletionHandlerCall() {
		let conversionValue = Int.random(in: 1...63)
		let coarseValue = [SKAdNetwork.CoarseConversionValue.low, .medium, .high].randomElement() ?? .low
		let lockWindow = Bool.random()

		SKAdNetwork.updatePostbackConversionValue(conversionValue, coarseValue: coarseValue, lockWindow: lockWindow, completionHandler: nil)

		XCTAssert(UserDefaults.standard.bool(forKey: Store.postbackConversionValueSetKey))
	}
}

final class MockSkAdNetwork: SkAdNetwork {
	enum Call: Equatable {
		case registerAppForAdNetworkAttribution
		case updatePostbackConversionValue(conversionValue: Int)
	}

	static var calls = [MockSkAdNetwork.Call]()

	static var updatePostbackConversionValueCompletion: Error?

	static func reset() {
		calls = []

		updatePostbackConversionValueCompletion = nil
	}

	static func registerAppForAdNetworkAttribution() {
		calls.append(.registerAppForAdNetworkAttribution)
	}

	static func updatePostbackConversionValue(
		_ conversionValue: Int,
		completionHandler completion: ((Error?) -> Void)?
	) {
		calls.append(.updatePostbackConversionValue(conversionValue: conversionValue))
		completion?(updatePostbackConversionValueCompletion)
	}
}
