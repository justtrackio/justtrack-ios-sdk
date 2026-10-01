@testable import JustTrackSDK

final class MockAdTrackingEventPublisherObserver: AdTrackingEventPublisherObserver {
	enum Call: Equatable {
		case onFinishAdTrackingAuthorization
		case onPublishAdTrackingEvent(eventName: String, eventAction: String?)
	}

	var calls: [Call] = []

	func reset() {
		calls = []
	}

	func onFinishAdTrackingAuthorization() {
		calls.append(.onFinishAdTrackingAuthorization)
	}

	func onPublishAdTrackingEvent(_ event: AppEvent) {
		calls.append(.onPublishAdTrackingEvent(eventName: event.name, eventAction: event.getDimensions()[Dimension.jtAction.rawValue]))
	}
}
