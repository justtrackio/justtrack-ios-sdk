import XCTest

@testable import JustTrackSDK

final class AdTrackingEventPublisherObserverTests: XCTestCase {
	private let observer = MockAdTrackingEventPublisherObserver()

	override func setUp() {
		AdTrackingEventPublisher.shared.set(observer: nil)

	}

	func testObserverIsNotifiedAfterBeingSetWhenAuthorizationIsNotRunning() {
		AdTrackingEventPublisher.shared.setAdTrackingAuthorizationRequestRunning(false)

		AdTrackingEventPublisher.shared.set(observer: observer)

		XCTAssertEqual(observer.calls, [.onFinishAdTrackingAuthorization])
	}

	func testObserverIsNotifiedWithEventsAfterBeingSetWhenAuthorizationIsNotRunning() {
		AdTrackingEventPublisher.shared.setAdTrackingAuthorizationRequestRunning(false)
		AdTrackingEventPublisher.shared.onRequestAdTrackingPermission()
		AdTrackingEventPublisher.shared.onAuthorizeGettingAdTrackingPermission()
		AdTrackingEventPublisher.shared.onRestrictGettingAdTrackingPermission()
		AdTrackingEventPublisher.shared.onRevokeGettingAdTrackingPermission()
		AdTrackingEventPublisher.shared.onDenyGettingAdTrackingPermission()

		AdTrackingEventPublisher.shared.set(observer: observer)

		XCTAssertEqual(
			observer.calls,
			[
				.onFinishAdTrackingAuthorization,
				.onPublishAdTrackingEvent(eventName: "jt_tracking_permission", eventAction: "requested"),
				.onPublishAdTrackingEvent(eventName: "jt_tracking_permission", eventAction: "authorized"),
				.onPublishAdTrackingEvent(eventName: "jt_tracking_permission", eventAction: "restricted"),
				.onPublishAdTrackingEvent(eventName: "jt_tracking_permission", eventAction: "revoked"),
				.onPublishAdTrackingEvent(eventName: "jt_tracking_permission", eventAction: "denied"),
			]
		)
	}

	func testObserverIsNotNotifiedAfterBeingSetWhenAuthorizationIsRunning() {
		AdTrackingEventPublisher.shared.setAdTrackingAuthorizationRequestRunning(true)

		AdTrackingEventPublisher.shared.set(observer: observer)

		XCTAssertEqual(observer.calls, [])
	}

	func testObserverIsNotifiedAfterAuthorizationIsFinished() {
		AdTrackingEventPublisher.shared.setAdTrackingAuthorizationRequestRunning(true)
		AdTrackingEventPublisher.shared.set(observer: observer)

		AdTrackingEventPublisher.shared.setAdTrackingAuthorizationRequestRunning(false)

		XCTAssertEqual(observer.calls, [.onFinishAdTrackingAuthorization])
	}

	func testOnRequestAdTrackingPermissionPublishesEvent() {
		AdTrackingEventPublisher.shared.set(observer: observer)
		observer.reset()

		AdTrackingEventPublisher.shared.onRequestAdTrackingPermission()

		XCTAssertEqual(observer.calls, [.onPublishAdTrackingEvent(eventName: "jt_tracking_permission", eventAction: "requested")])
	}

	func testOnAuthorizeGettingAdTrackingPermissionPublishesEvent() {
		AdTrackingEventPublisher.shared.set(observer: observer)
		observer.reset()

		AdTrackingEventPublisher.shared.onAuthorizeGettingAdTrackingPermission()

		XCTAssertEqual(observer.calls, [.onPublishAdTrackingEvent(eventName: "jt_tracking_permission", eventAction: "authorized")])
	}

	func testOnRestrictGettingAdTrackingPermissionPublishesEvent() {
		AdTrackingEventPublisher.shared.set(observer: observer)
		observer.reset()

		AdTrackingEventPublisher.shared.onRestrictGettingAdTrackingPermission()

		XCTAssertEqual(observer.calls, [.onPublishAdTrackingEvent(eventName: "jt_tracking_permission", eventAction: "restricted")])
	}

	func testOnRevokeGettingAdTrackingPermissionPublishesEvent() {
		AdTrackingEventPublisher.shared.set(observer: observer)
		observer.reset()

		AdTrackingEventPublisher.shared.onRevokeGettingAdTrackingPermission()

		XCTAssertEqual(observer.calls, [.onPublishAdTrackingEvent(eventName: "jt_tracking_permission", eventAction: "revoked")])
	}

	func testOnDenyGettingAdTrackingPermissionPublishesEvent() {
		AdTrackingEventPublisher.shared.set(observer: observer)
		observer.reset()

		AdTrackingEventPublisher.shared.onDenyGettingAdTrackingPermission()

		XCTAssertEqual(observer.calls, [.onPublishAdTrackingEvent(eventName: "jt_tracking_permission", eventAction: "denied")])
	}
}
