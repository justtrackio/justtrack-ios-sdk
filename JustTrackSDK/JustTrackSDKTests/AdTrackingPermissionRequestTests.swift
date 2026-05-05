import XCTest

@testable import JustTrackSDK

final class AdTrackingPermissionRequestTests: XCTestCase {
	func testRequestUnknownToAuthorized() {
		let requester = TestAdTrackingPermissionRequester(currentPermission: .unknown, finalPermission: .authorized)
		AdTrackingProviderImpl(forTesting: ()).requestTrackingAuthorization(requester: requester) { success in
			XCTAssertTrue(success)
		}
	}

	func testRequestUnknownToDenied() {
		let requester = TestAdTrackingPermissionRequester(currentPermission: .unknown, finalPermission: .denied)
		AdTrackingProviderImpl(forTesting: ()).requestTrackingAuthorization(requester: requester) { success in
			XCTAssertFalse(success)
		}
	}

	func testRequestAuthorizedToNil() {
		let requester = TestAdTrackingPermissionRequester(currentPermission: .authorized, finalPermission: nil)
		AdTrackingProviderImpl(forTesting: ()).requestTrackingAuthorization(requester: requester) { success in
			XCTAssertTrue(success)
		}
	}

	func testRequestAuthorizedToAuthorized() {
		let requester = TestAdTrackingPermissionRequester(currentPermission: .authorized, finalPermission: .authorized)
		AdTrackingProviderImpl(forTesting: ()).requestTrackingAuthorization(requester: requester) { success in
			XCTAssertTrue(success)
		}
	}

	func testRequestDeniedToNil() {
		let requester = TestAdTrackingPermissionRequester(currentPermission: .denied, finalPermission: nil)
		AdTrackingProviderImpl(forTesting: ()).requestTrackingAuthorization(requester: requester) { success in
			XCTAssertFalse(success)
		}
	}

	func testRequestRestrictedToNil() {
		let requester = TestAdTrackingPermissionRequester(currentPermission: .restricted, finalPermission: nil)
		AdTrackingProviderImpl(forTesting: ()).requestTrackingAuthorization(requester: requester) { success in
			XCTAssertFalse(success)
		}
	}

	private func assertEvents(_ pendingEvents: [AppEvent], _ expectedEvents: [String]) {
		XCTAssertEqual(pendingEvents.count, expectedEvents.count)
		for i in 0..<pendingEvents.count {
			let event = pendingEvents[i].build(sessionId: "")
			XCTAssertEqual(event.name, expectedEvents[i])
			XCTAssertNotNil(event.happenedAt)
			if i > 0 {
				let previousEvent = pendingEvents[i - 1].build(sessionId: "")
				XCTAssertGreaterThanOrEqual(event.happenedAt!, previousEvent.happenedAt!)
			}
		}
	}
}

class TestAdTrackingPermissionRequester: AdTrackingPermissionRequester {
	var currentPermission: AdTrackingStatus
	let finalPermission: AdTrackingStatus?
	let waitWithCallbacks: Bool
	var callbacks: [() -> Void]

	convenience init(currentPermission: AdTrackingStatus, finalPermission: AdTrackingStatus?) {
		self.init(currentPermission: currentPermission, finalPermission: finalPermission, waitWithCallbacks: false)
	}

	init(currentPermission: AdTrackingStatus, finalPermission: AdTrackingStatus?, waitWithCallbacks: Bool) {
		self.currentPermission = currentPermission
		self.finalPermission = finalPermission
		self.waitWithCallbacks = waitWithCallbacks
		self.callbacks = []
	}

	func getAdTrackingPermission() -> AdTrackingStatus {
		return currentPermission
	}

	func requestAdTrackingPermission(_ onResponse: @escaping (AdTrackingStatus) -> Void) {
		XCTAssertNotNil(finalPermission)
		guard let finalPermission = finalPermission else {
			return
		}
		callbacks.append {
			self.currentPermission = finalPermission
			Thread.sleep(forTimeInterval: 0.005)  // 5ms
			onResponse(finalPermission)
		}
		if !waitWithCallbacks {
			callCallbacks()
		}
	}

	func callCallbacks() {
		let callbacks = self.callbacks
		self.callbacks = []
		// we should not have more than one callback pending at any time
		XCTAssertLessThanOrEqual(callbacks.count, 1)

		for callback in callbacks {
			callback()
		}
	}
}
