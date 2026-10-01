import StoreKit

/// Main entry point for the justtrack SDK.
/// This class provides methods to configure, initialize and interact with the tracking system.
public final class JustTrack {
	private static let appStartedAt = Date()
	private static var started = false
	private static weak var sdk: JustTrackSdkImpl?
	private static let lock = JustTrack()

	private init() {}

	internal static func resetForTesting(clearStorage: Bool) {
		objc_sync_enter(lock)
		defer { objc_sync_exit(lock) }

		started = false
		sdk = nil
		LoggerImpl().debug("Reset for testing")

		if clearStorage {
			UserDefaults.standard.removeObject(forKey: PendingIdStoreKey.customUserIdKey)
			UserDefaults.standard.removeObject(forKey: PendingIdStoreKey.firebaseAppInstanceIdKey)
			UserDefaults.standard.removeObject(forKey: EventStore.key)
			UserDefaults.standard.removeObject(forKey: Session.key)
			UserDefaults.standard.removeObject(forKey: Store.attributionKey)
			UserDefaults.standard.removeObject(forKey: Store.timestampsKey)
			UserDefaults.standard.removeObject(forKey: Store.appVersionAtInstallKey)
			UserDefaults.standard.removeObject(forKey: Store.currentAppVersionKey)
			UserDefaults.standard.removeObject(forKey: Store.postbackConversionValueSetKey)
			LoggerImpl().debug("Cleared storage for testing")
		}
	}

	/// Requests tracking authorization from the user.
	/// If not supported on this device, checks if ad tracking is limited.
	/// If authorization was already permitted or denied, the callback is invoked immediately.
	/// Otherwise it prompts the user for authorization and returns whether the user allowed tracking.
	/// - Parameter onAuthorized: Callback that receives whether the user authorized tracking.
	public static func requestTrackingAuthorization(_ onAuthorized: @escaping (Bool) -> Void) {
		let provider = AdTrackingProviderImpl.instance
		provider.requestTrackingAuthorization(requester: provider.getAdTrackingPermissionRequester(), onAuthorized)
	}

	/// Returns the current justtrack SDK instance if available.
	/// - Returns: The SDK instance or nil if not initialized.
	public static func getInstance() -> JustTrackSdk? {
		objc_sync_enter(lock)
		defer { objc_sync_exit(lock) }

		return sdk
	}

	internal static func provideInstance(_ builder: JustTrackSdkBuilder) throws -> JustTrackSdk {
		objc_sync_enter(lock)

		if let sdk {
			objc_sync_exit(lock)

			return sdk
		}

		let sdk: JustTrackSdkImpl
		do {
			sdk = try builder.createSdk()
		} catch {
			objc_sync_exit(lock)

			throw error
		}
		self.sdk = sdk

		objc_sync_exit(lock)

		builder.configure(sdk: sdk)

		return sdk
	}

	internal static func setSdk(_ sdkInstance: JustTrackSdkImpl) {
		objc_sync_enter(lock)
		defer { objc_sync_exit(lock) }

		sdk = sdkInstance
		notifyQueuedEvents()
	}

	private static func getAppStartedAt() -> AppStateEvent? {
		if started {
			return nil
		}

		started = true

		return AppStateEvent(startedAt: appStartedAt, doneAt: Date())
	}

	private static func notifyQueuedEvents() {
		guard let sdk = sdk else { return }

		if let event = getAppStartedAt() {
			sdk.notifyAppStart(event)
		}
	}
}

struct AppStateEvent {
	let startedAt: Date
	let startingTook: TimeInterval

	fileprivate init(startedAt: Date, doneAt: Date) {
		self.startedAt = startedAt
		self.startingTook = doneAt.timeIntervalSince(startedAt)
	}
}
