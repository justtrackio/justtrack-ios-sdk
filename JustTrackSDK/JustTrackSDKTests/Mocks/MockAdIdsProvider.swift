@testable import JustTrackSDK

final class MockAdIdsProvider: AdIdsProvider {
	enum Call: Equatable {
		case getAdIds
	}

	var calls: [Call] = []

	func reset() {
		calls = []
		getAdIdsResult = FutureImpl<AdIds>()
	}

	var getAdIdsResult = FutureImpl<AdIds>()

	func getAdIds() -> JustTrackSDK.Future<AdIds> {
		calls.append(.getAdIds)
		return getAdIdsResult.toFuture()
	}
}
