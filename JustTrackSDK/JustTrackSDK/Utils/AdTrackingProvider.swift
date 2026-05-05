import AdSupport
import AppTrackingTransparency
import UIKit

protocol AdTrackingProvider {
	func provideIDFA() -> StringID?
	func provideIDFV() -> StringID?
	func requestTrackingAuthorization(requester: AdTrackingPermissionRequester, _ onAuthorized: @escaping (Bool) -> Void)
	func setLogger(_ logger: Logger)
}

final class AdTrackingProviderImpl: NSObject, AdTrackingProvider {
	static let instance = AdTrackingProviderImpl()

	private var logger: AdTrackingLogger
	private var trackingPermissionRequested: Bool
	private var trackingPermissionResult: AdTrackingStatus?
	private var pendingCallbacks: [(Bool) -> Void]

	private override init() {
		logger = AdTrackingLogger()
		trackingPermissionRequested = false
		trackingPermissionResult = nil
		pendingCallbacks = []
	}

	convenience init(forTesting: ()) {
		self.init()
	}

	func setLogger(_ logger: Logger) {
		self.logger.set(sdkLogger: logger)
	}

	func provideIDFA() -> StringID? {
		let manager = ASIdentifierManager.shared()

		// check if we are allowed to read the IDFA
		if #available(iOS 14, *) {
			switch ATTrackingManager.trackingAuthorizationStatus {
			case .authorized:
				// we are allowed to read the IDFA, so lets do that
				break
			case .denied, .notDetermined, .restricted:
				// we can't read the IDFA right now, so abort
				return nil
			default:
				// we don't know if we can read the IDFA, lets just try it
				break
			}
		} else if !manager.isAdvertisingTrackingEnabled {
			return nil
		}

		if manager.advertisingIdentifier.uuidString == "00000000-0000-0000-0000-000000000000" {
			return nil
		}

		return StringID(value: manager.advertisingIdentifier.uuidString)
	}

	func provideIDFV() -> StringID? {
		guard let identifierForVendor = UIDevice.current.identifierForVendor else { return nil }
		return StringID(value: identifierForVendor.uuidString)
	}

	func requestTrackingAuthorization(requester: AdTrackingPermissionRequester, _ onAuthorized: @escaping (Bool) -> Void) {
		logger.debug("Requesting tracking authorization")

		objc_sync_enter(self)
		// did we already finish requesting the permission? if so, then we can just call the callback directly
		if let trackingPermissionResult {
			objc_sync_exit(self)
			logger.debug("We have already been authorized with status \(trackingPermissionResult)")
			onAuthorized(trackingPermissionResult == AdTrackingStatus.authorized)

			return
		}
		// we didn't yet call the callback, but did we already perform the request for the permission?
		// then add ourselves to the list of callbacks and wait to be called again
		if trackingPermissionRequested {
			pendingCallbacks.append(onAuthorized)
			objc_sync_exit(self)
			logger.debug("Tracking authorization request added to list of pending requests")

			return
		}

		// at this point, we are going to request it (or at least query it from the device)
		trackingPermissionRequested = true

		let permission = requester.getAdTrackingPermission()

		switch permission {
		case .authorized, .restricted, .denied:
			trackingPermissionResult = permission
			objc_sync_exit(self)
			logger.debug("Tracking authorization requester provided us with status \(permission)")
			onAuthorized(permission == .authorized)
			return

		case .unknown:
			objc_sync_exit(self)
			logger.debug("Tracking authorization requester didn't provide a status yet, requesting tracking permission from the user")
		}

		requester.requestAdTrackingPermission { permission in
			self.logger.debug("User provided tracking permission \(permission)")
			objc_sync_enter(self)
			let toCall = self.pendingCallbacks
			self.pendingCallbacks = []

			self.trackingPermissionResult = permission
			objc_sync_exit(self)

			let authorized = permission == .authorized

			onAuthorized(authorized)
			for callback in toCall {
				callback(authorized)
			}
		}
	}

	func getAdTrackingPermissionRequester() -> AdTrackingPermissionRequester {
		return AdTrackingPermissionRequesterImpl(logger: logger)
	}
}

protocol AdTrackingPermissionRequester {
	func getAdTrackingPermission() -> AdTrackingStatus
	func requestAdTrackingPermission(_ onResponse: @escaping (AdTrackingStatus) -> Void)
}

enum AdTrackingStatus: String {
	case authorized
	case denied
	case restricted
	case unknown
}

@objc
public class AdTrackingPermissionRequesterImpl: NSObject, AdTrackingPermissionRequester {
	private let logger: Logger
	private var onBecomeActiveCallbacks: [() -> Void] = []

	init(logger: Logger) {
		self.logger = logger
		super.init()

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(applicationDidBecomeActive),
			name: UIApplication.didBecomeActiveNotification,
			object: nil
		)
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	func getAdTrackingPermission() -> AdTrackingStatus {
		if #available(iOS 14, *) {
			return AdTrackingPermissionRequesterImpl.translateAdTrackingPermission(ATTrackingManager.trackingAuthorizationStatus)
		} else {
			let enabled = ASIdentifierManager.shared().isAdvertisingTrackingEnabled
			return enabled ? .authorized : .restricted  // if we already know the user disabled this for all apps, that is restricted, not denied
		}
	}

	func requestAdTrackingPermission(_ onResponse: @escaping (AdTrackingStatus) -> Void) {
		if #available(iOS 14, *) {
			// we should only call requestAdTrackingPermission if our UI application is active.
			// if the app is not yet active, we might get a not-determined result and never be
			// able to show the ATT dialog again.
			// see also <https://stackoverflow.com/questions/71557227/attrackingmanager-requesttrackingauthorization-always-returns-not-determined-a>
			ensureActive {
				ATTrackingManager.requestTrackingAuthorization(completionHandler: { status in
					let permission = AdTrackingPermissionRequesterImpl.translateAdTrackingPermission(status)
					self.logger.debug("Got a response from the user with permission = \(permission) (status = \(status))")
					onResponse(permission)
				})
			}
		} else {
			let enabled = ASIdentifierManager.shared().isAdvertisingTrackingEnabled
			logger.debug("We are on iOS < 14, ad tracking is \(enabled ? "enabled" : "disabled")")
			onResponse(enabled ? .authorized : .denied)  // asking for permission should not return restricted
		}
	}

	private func ensureActive(block: @escaping () -> Void) {
		switch UIApplication.shared.applicationState {
		case .active:
			block()
		default:
			logger.debug("UI application is currently not active, waiting for it to become active")

			objc_sync_enter(self)
			defer { objc_sync_exit(self) }

			onBecomeActiveCallbacks.append {
				self.logger.debug("UI application became active")

				self.ensureActive(block: block)
			}
		}
	}

	@objc
	public func applicationDidBecomeActive() {
		objc_sync_enter(self)
		let callbacks = onBecomeActiveCallbacks
		onBecomeActiveCallbacks = []
		objc_sync_exit(self)

		for callback in callbacks {
			callback()
		}
	}

	@available(iOS 14, *)
	private static func translateAdTrackingPermission(_ status: ATTrackingManager.AuthorizationStatus) -> AdTrackingStatus {
		switch status {
		case .authorized:
			return .authorized
		case .denied:
			return .denied
		case .restricted:
			return .restricted
		case .notDetermined:
			return .unknown
		default:
			return .unknown
		}
	}
}

private class AdTrackingLogger: Logger {
	private var sdkLogger: Logger?

	private var pendingCalls: [() -> Void] = []

	func set(sdkLogger: Logger) {
		objc_sync_enter(self)
		self.sdkLogger = sdkLogger
		objc_sync_exit(self)
		executePendingCalls()
	}

	func debug(_ message: String, _ fields: [LoggerFields]) {
		withSdkLogger { sdkLogger in
			sdkLogger.debug(message, fields)
		}
	}

	func info(_ message: String, _ fields: [LoggerFields]) {
		withSdkLogger { sdkLogger in
			sdkLogger.info(message, fields)
		}
	}

	func warn(_ message: String, _ fields: [LoggerFields]) {
		withSdkLogger { sdkLogger in
			sdkLogger.warn(message, fields)
		}
	}

	func error(_ message: String, _ fields: [LoggerFields]) {
		withSdkLogger { sdkLogger in
			sdkLogger.error(message, fields)
		}
	}

	func error(_ message: String, _ exception: Error, _ fields: [LoggerFields]) {
		withSdkLogger { sdkLogger in
			sdkLogger.error(message, exception, fields)
		}
	}

	func publishMetric(_ metric: Metric, _ value: Double, _ dimensions: [LoggerFields]) {
		withSdkLogger { sdkLogger in
			sdkLogger.publishMetric(metric, value, dimensions)
		}
	}

	func debug(_ message: String) {
		withSdkLogger { sdkLogger in
			sdkLogger.debug("<ATT> \(message)")
		}
	}

	private func withSdkLogger(
		action: @escaping (Logger) -> Void
	) {
		objc_sync_enter(self)
		if let sdkLogger {
			objc_sync_exit(self)
			action(sdkLogger)
		} else {
			pendingCalls.append { [weak self] in
				self?.withSdkLogger(action: action)
			}
			objc_sync_exit(self)
		}
	}

	private func executePendingCalls() {
		objc_sync_enter(self)
		let callsToExecute = pendingCalls
		pendingCalls = []
		objc_sync_exit(self)

		for call in callsToExecute {
			call()
		}
	}
}
