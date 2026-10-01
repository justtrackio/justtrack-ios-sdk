import XCTest

@testable import JustTrackSDK

final class AppDelegateWatcherTests: XCTestCase {
	private lazy var delegateWatcher: AppDelegateWatcher = {
		let delegateWatcher: AppDelegateWatcher
		if let notificationCenter {
			delegateWatcher = AppDelegateWatcher(
				notificationCenter: notificationCenter
			)
			notificationCenter.observer = delegateWatcher
		} else {
			delegateWatcher = AppDelegateWatcher()
		}
		delegateWatcher.reportee = reportee
		return delegateWatcher
	}()

	private var notificationCenter: MockNotificationCenter<AppDelegateWatcher>?

	private var reportee = MockAppDelegateWatcherReportee()

	func testAddObserverIsCalledDuringInit() {
		notificationCenter = MockNotificationCenter<AppDelegateWatcher>()
		_ = delegateWatcher

		XCTAssertEqual(
			notificationCenter!.calls,
			[
				.addObserver(
					observer: delegateWatcher,
					selector: "appDidBecomeActive",
					name: UIApplication.didBecomeActiveNotification.rawValue
				),
				.addObserver(
					observer: delegateWatcher,
					selector: "appDidEnterBackground",
					name: UIApplication.didEnterBackgroundNotification.rawValue
				),
				.addObserver(
					observer: delegateWatcher,
					selector: "appWillTerminate",
					name: UIApplication.willTerminateNotification.rawValue
				),
			]
		)
	}

	func testMoveToForegroundIsCalledWhenApplicationDidBecomeActiveNotificationIsPosted() {
		_ = delegateWatcher

		NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

		XCTAssertEqual(self.reportee.calls, [.moveToForeground])
	}

	func testMoveToBackgroundIsCalledWhenApplicationDidEnterBackgroundNotificationIsPosted() {
		_ = delegateWatcher

		NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

		XCTAssertEqual(self.reportee.calls, [.moveToBackground])
	}

	func testApplicationWillTerminateIsCalledWhenApplicationWillTerminateNotificationIsPosted() {
		_ = delegateWatcher

		NotificationCenter.default.post(name: UIApplication.willTerminateNotification, object: nil)

		XCTAssertEqual(self.reportee.calls, [.applicationWillTerminate])
	}

	// MARK: - uninstall

	func testUninstallOnMainThreadNilsReporteeImmediately() {
		let watcher = AppDelegateWatcher()
		watcher.reportee = reportee

		// Call from main thread (XCTest runs on main thread)
		XCTAssertTrue(Thread.isMainThread)
		watcher.uninstall()

		XCTAssertNil(watcher.reportee)
	}

	func testUninstallOffMainThreadNilsReporteeAsynchronously() {
		let watcher = AppDelegateWatcher()
		watcher.reportee = reportee

		let expectation = self.expectation(description: "uninstall off-main")

		DispatchQueue.global().async {
			XCTAssertFalse(Thread.isMainThread)
			watcher.uninstall()

			DispatchQueue.main.async {
				expectation.fulfill()
			}
		}

		waitForExpectations(timeout: 2)
		XCTAssertNil(watcher.reportee)
	}

	func testUninstallPreventsCallbacksAfterUninstallOnMainThread() {
		_ = delegateWatcher

		delegateWatcher.uninstall()

		NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

		XCTAssertTrue(reportee.calls.isEmpty)
	}

	func testUninstallCanBeCalledMultipleTimes() {
		let watcher = AppDelegateWatcher()
		watcher.reportee = reportee

		watcher.uninstall()
		watcher.uninstall()

		XCTAssertNil(watcher.reportee)
	}

	func testNoReporteeDoesNotCrashOnNotification() {
		let watcher = AppDelegateWatcher()
		// reportee not set — should not crash

		NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
		NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
		NotificationCenter.default.post(name: UIApplication.willTerminateNotification, object: nil)
	}
}
