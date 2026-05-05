import AppTrackingTransparency
import Foundation
import UIKit

/*
 We use `AdTrackingEventPublisher`, to keep the SDK informed about the current ATT status.
 The class informs the SDK if the authorization is still in progress or if it was finished with a certain result.
 */

protocol AdTrackingEventPublisherObserver: AnyObject {
	func onFinishAdTrackingAuthorization()
	func onPublishAdTrackingEvent(_ event: AppEvent)
}

protocol AdTrackingEventPublishing {
	func set(observer: AdTrackingEventPublisherObserver?)
}

@objc
public final class AdTrackingEventPublisher: NSObject, AdTrackingEventPublishing {
	@objc
	public static let shared = AdTrackingEventPublisher()

	private var adTrackingAuthorizationRequestRunning = false

	private weak var observer: AdTrackingEventPublisherObserver? {
		didSet {
			checkAuthorization()
			publishPendingEvents()
		}
	}

	func set(observer: AdTrackingEventPublisherObserver?) {
		self.observer = observer
	}

	private var timer: Timer? {
		willSet {
			timer?.invalidate()
		}
	}

	private var pendingEvents = [AppEvent]()

	private var trackingAuthStatusIsNotDetermined: Bool {
		if #available(iOS 14, *) {
			return ATTrackingManager.trackingAuthorizationStatus == .notDetermined
		}
		return false
	}

	let needToWaitForAuthorizationStatus: Bool = {
		if #available(iOS 17.5, *) {
			return false
		} else if #available(iOS 17.4, *) {
			return true
		} else {
			return false
		}
	}()

	override init() {
		super.init()

		if needToWaitForAuthorizationStatus {
			NotificationCenter.default.addObserver(
				self,
				selector: #selector(checkForAuthorizationStatus),
				name: UIApplication.didBecomeActiveNotification,
				object: nil
			)
		}
	}

	@objc
	public func setAdTrackingAuthorizationRequestRunning(_ running: Bool) {
		objc_sync_enter(self)

		/*
         We currently use this solution to fix the ATT bug on iOS 17.4 that immediately returns the wrong `.denied` result after we perform `ATTrackingManager.requestTrackingAuthorization { authStatus in }`.
         The idea is that despite the `authStatus` inside the closure is wrong, we still can check the actual auth status using `ATTrackingManager.trackingAuthorizationStatus`.

         If `running` is `true` and `trackingAuthStatusIsNotDetermined` is `.notDetermined`, we assumed that requesting the ATT permission is still ongoing.

         The problem is that `.notDetermined` is a default value for the auth status. And if we didn't request the ATT permission before, `ATTrackingManager.trackingAuthorizationStatus` is always `.notDetermined`. So each time we initialized the SDK, it stalled while the current auth status is `.notDetermined`.

         So now we use `trackingAuthStatusIsNotDetermined` in combination with `needToWaitForAuthorizationStatus` to set `adTrackingAuthorizationRequestRunning` to `true` when `trackingAuthStatusIsNotDetermined` is `true` and `running` is `false` only on iOS 17.4.
         */

		adTrackingAuthorizationRequestRunning = trackingAuthStatusIsNotDetermined && needToWaitForAuthorizationStatus && UIApplication.shared.applicationState == .active || running
		notifyObserverIfNeededWithLock()
	}

	private func checkAuthorization() {
		objc_sync_enter(self)

		guard let observer else {
			objc_sync_exit(self)
			return
		}

		if !adTrackingAuthorizationRequestRunning {
			objc_sync_exit(self)
			observer.onFinishAdTrackingAuthorization()
			return
		}

		defer { objc_sync_exit(self) }

		if needToWaitForAuthorizationStatus {
			// for good measure, add a timer that checks once per second if the user already made a decision
			timer = Timer.scheduledTimer(
				withTimeInterval: 1,
				repeats: true,
				block: { _ in
					self.checkForAuthorizationStatus()
				}
			)
		}
	}

	@objc
	public func onRequestAdTrackingPermission() {
		publishEvent(JtTrackingPermissionEvent(jtAction: "requested", happenedAt: Date()))
	}

	@objc
	public func onAuthorizeGettingAdTrackingPermission() {
		publishEvent(JtTrackingPermissionEvent(jtAction: "authorized", happenedAt: Date()))
	}

	@objc
	public func onRestrictGettingAdTrackingPermission() {
		publishEvent(JtTrackingPermissionEvent(jtAction: "restricted", happenedAt: Date()))
	}

	@objc
	public func onRevokeGettingAdTrackingPermission() {
		publishEvent(JtTrackingPermissionEvent(jtAction: "revoked", happenedAt: Date()))
	}

	@objc
	public func onDenyGettingAdTrackingPermission() {
		publishEvent(JtTrackingPermissionEvent(jtAction: "denied", happenedAt: Date()))
	}

	private func publishEvent(_ event: AppEvent) {
		objc_sync_enter(self)

		guard let observer else {
			defer { objc_sync_exit(self) }

			pendingEvents.append(event)
			return
		}

		objc_sync_exit(self)

		observer.onPublishAdTrackingEvent(event)
	}

	private func publishPendingEvents() {
		objc_sync_enter(self)

		guard let observer else {
			objc_sync_exit(self)

			return
		}
		let eventsToPublich = pendingEvents
		pendingEvents = []
		objc_sync_exit(self)

		for event in eventsToPublich {
			observer.onPublishAdTrackingEvent(event)
		}
	}

	@objc
	private func checkForAuthorizationStatus() {
		objc_sync_enter(self)

		if !trackingAuthStatusIsNotDetermined {
			adTrackingAuthorizationRequestRunning = false
		}

		notifyObserverIfNeededWithLock()
	}

	private func notifyObserverIfNeededWithLock() {
		if !adTrackingAuthorizationRequestRunning {
			timer = nil
			objc_sync_exit(self)
			observer?.onFinishAdTrackingAuthorization()
		} else {
			objc_sync_exit(self)
		}
	}
}
