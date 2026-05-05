import Foundation

@testable import JustTrackSDK

final class MockJustTrackSDKAdapter: JusttrackAdapter {
	var integrateCallCount = 0
	var integrateCalledWith: [(sdk: JustTrackSdk, logger: JustTrackSDK.Logger)] = []
	var integrateStub: ((JustTrackSdk, JustTrackSDK.Logger) -> Future<Void>)?

	func integrate(
		sdk: JustTrackSdk,
		logger: JustTrackSDK.Logger
	) -> Future<Void> {
		integrateCallCount += 1
		integrateCalledWith.append((sdk: sdk, logger: logger))

		if let stub = integrateStub {
			return stub(sdk, logger)
		}

		return FutureImpl<Void>().resolve(())
	}
}
