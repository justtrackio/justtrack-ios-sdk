import UIKit

final class AppDelegateWatcher {
	weak var reportee: AppDelegateWatcherReportee?

	init(
		notificationCenter: NotificationBroadcasting = NotificationCenter.default
	) {
		notificationCenter.addObserver(
			self,
			selector: #selector(appDidBecomeActive),
			name: UIApplication.didBecomeActiveNotification,
			object: nil
		)
		notificationCenter.addObserver(
			self,
			selector: #selector(appDidEnterBackground),
			name: UIApplication.didEnterBackgroundNotification,
			object: nil
		)
		notificationCenter.addObserver(
			self,
			selector: #selector(appWillTerminate),
			name: UIApplication.willTerminateNotification,
			object: nil
		)
	}

	func uninstall() {
		if Thread.isMainThread {
			reportee = nil
		} else {
			DispatchQueue.main.async {
				self.reportee = nil
			}
		}
	}

	@objc
	private func appDidBecomeActive() {
		reportee?.moveToForeground()
	}

	@objc
	private func appDidEnterBackground() {
		reportee?.moveToBackground()
	}

	@objc
	private func appWillTerminate() {
		reportee?.applicationWillTerminate()
	}
}
