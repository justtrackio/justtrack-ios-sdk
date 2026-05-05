import Foundation

protocol ConnectivityManager {
	func registerOnReconnect(_ callback: @escaping () -> Void) -> Subscription
	func shutdown()
}

class ConnectivityManagerImpl: ConnectivityManager {
	private let subscriptions: SubscriptionManager<()>
	private var reachability: Reachability?

	init() throws {
		self.subscriptions = SubscriptionManager()
		let reachability = try Reachability()
		reachability.whenReachable = self.onReachable
		try reachability.startNotifier()
		self.reachability = reachability
	}

	func shutdown() {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		self.reachability?.stopNotifier()
		self.reachability = nil
	}

	func registerOnReconnect(_ callback: @escaping () -> Void) -> Subscription {
		return subscriptions.subscribe(listener: { _ in
			callback()
		})
	}

	private func onReachable(_: Reachability) {
		DispatchQueue.main.async { self.subscriptions.call(value: ()) }
	}
}
