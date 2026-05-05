import XCTest

@testable import JustTrackSDK

final class MockNotificationCenter<Observer: AnyObject>: NotificationBroadcasting {
	enum Call: Equatable {
		static func == (
			lhs: MockNotificationCenter<Observer>.Call,
			rhs: MockNotificationCenter<Observer>.Call
		) -> Bool {
			switch (lhs, rhs) {
			case let (.addObserver(lhsObserver, lhsSelector, lhsName), .addObserver(rhsObserver, rhsSelector, rhsName)):
				return lhsObserver === rhsObserver && lhsSelector == rhsSelector && lhsName == rhsName
			}
		}

		case addObserver(observer: Observer, selector: String, name: String?)
	}

	var calls = [Call]()

	weak var observer: Observer?

	func reset() {
		calls = []
	}

	func addObserver(
		_ observer: Any,
		selector aSelector: Selector,
		name aName: NSNotification.Name?,
		object anObject: Any?
	) {
		guard let observer = observer as? Observer else { return }
		calls.append(.addObserver(observer: observer, selector: aSelector.description, name: aName?.rawValue))
	}
}
