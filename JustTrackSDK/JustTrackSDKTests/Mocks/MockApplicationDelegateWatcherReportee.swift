import XCTest

@testable import JustTrackSDK

final class MockAppDelegateWatcherReportee: AppDelegateWatcherReportee {
	enum Call: Equatable {
		case moveToForeground
		case moveToBackground
		case applicationWillTerminate
	}

	var calls = [Call]()

	func reset() {
		calls = []
	}

	func moveToForeground() {
		calls.append(.moveToForeground)
	}

	func moveToBackground() {
		calls.append(.moveToBackground)
	}

	func applicationWillTerminate() {
		calls.append(.applicationWillTerminate)
	}
}
