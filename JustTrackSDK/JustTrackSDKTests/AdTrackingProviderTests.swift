import XCTest

@testable import JustTrackSDK

final class AdTrackingProviderTests: XCTestCase {
	func testUnknownToAuthorizedWithDialog() {
		runTestWith(currentStatus: .unknown, finalStatus: .authorized)
	}

	func testUnknownToDeniedWithDialog() {
		runTestWith(currentStatus: .unknown, finalStatus: .denied)
	}

	func testAuthorizedToAuthorized() {
		runTestWith(currentStatus: .authorized, finalStatus: .authorized)
	}

	func testDeniedToDenied() {
		runTestWith(currentStatus: .denied, finalStatus: .denied)
	}

	func testUnknownToAuthorized() {
		runTestWith(currentStatus: .authorized, finalStatus: .authorized)
	}

	func testUnknownToRestricted() {
		runTestWith(currentStatus: .restricted, finalStatus: .restricted)
	}

	func testAuthorizedToRestricted() {
		runTestWith(currentStatus: .restricted, finalStatus: .restricted)
	}

	func testAuthorizedToDenied() {
		runTestWith(currentStatus: .denied, finalStatus: .restricted)
	}

	func runTestWith(
		currentStatus: AdTrackingStatus,
		finalStatus: AdTrackingStatus
	) {
		let provider = AdTrackingProviderImpl(forTesting: ())
		let requester = TestAdTrackingPermissionRequester(
			currentPermission: currentStatus,
			finalPermission: finalStatus,
			waitWithCallbacks: true
		)
		var callCount = 0
		provider.requestTrackingAuthorization(requester: requester) { allowed in
			callCount += 1
			XCTAssertEqual(finalStatus == .authorized, allowed)
		}
		provider.requestTrackingAuthorization(requester: requester) { allowed in
			callCount += 1
			XCTAssertEqual(finalStatus == .authorized, allowed)
		}
		if currentStatus == .unknown {
			XCTAssertEqual(0, callCount)
			requester.callCallbacks()
		}
		XCTAssertEqual(2, callCount)
		provider.requestTrackingAuthorization(
			requester: requester,
			{ allowed in
				callCount += 1
				XCTAssertEqual(finalStatus == .authorized, allowed)
			}
		)
		XCTAssertEqual(3, callCount)
	}
}
