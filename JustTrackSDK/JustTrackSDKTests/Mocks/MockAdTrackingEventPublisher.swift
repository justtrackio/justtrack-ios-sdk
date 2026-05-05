@testable import JustTrackSDK

final class MockAdTrackingEventPublisher: AdTrackingEventPublishing {
	var immediatelyReportsOnFinish: Bool

	weak var observer: AdTrackingEventPublisherObserver?

	init(immediatelyReportsOnFinish: Bool = true) {
		self.immediatelyReportsOnFinish = immediatelyReportsOnFinish
	}

	func set(observer: AdTrackingEventPublisherObserver?) {
		self.observer = observer
		if immediatelyReportsOnFinish {
			observer?.onFinishAdTrackingAuthorization()
		}
	}
}
