import XCTest

@testable import JustTrackSDK

final class AdIdsProviderWrapperTests: XCTestCase {
	private lazy var wrapper = AdIdsProviderWrapper()
	private var adIdsProvider = MockAdIdsProvider()

	func testProvideAdIdsReturnsErrorWhenThereIsNoProvider() {
		wrapper.provideAdIds().observe { result in
			switch result {
			case let .failure(error):
				if let adIdsError = error as? AdIdsProviderWrapperError {
					XCTAssertEqual(adIdsError, .noAdIdsProvider)
				} else {
					XCTFail("The error should be of type AdIdsProviderWrapperError.")
				}
			case .success:
				XCTFail("We should receive an error, if there is no AdIds provider.")
			}
		}
	}

	func testProvideAdIdsReturnsResultFromProvider() {
		let adIds = AdIds(idfa: StringID(), userId: StringID())
		wrapper.adIdsProvider = adIdsProvider
		_ = adIdsProvider.getAdIdsResult.fulfill(.success(adIds))

		wrapper.provideAdIds().observe { result in
			switch result {
			case .failure:
				XCTFail("We shouldn't receive an error, when an AdIds provider is set.")
			case let .success(ids):
				XCTAssertEqual(ids, adIds)
			}
		}
	}
}

extension AdIds: @retroactive Equatable {
	public static func == (lhs: AdIds, rhs: AdIds) -> Bool {
		lhs.userId == rhs.userId && lhs.idfa == rhs.idfa
	}
}
