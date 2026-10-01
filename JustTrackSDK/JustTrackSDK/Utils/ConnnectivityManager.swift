import Foundation

protocol ConnectivityManager {
	var connectionType: ConnectionType { get }
	func registerOnReconnect(_ callback: @escaping () -> Void) -> Subscription
	func shutdown()
}

class ConnectivityManagerImpl: ConnectivityManager {
	private let subscriptions: SubscriptionManager<()>
	private var reachability: Reachability?
	private var _connectionType: ConnectionType

	var connectionType: ConnectionType {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }
		return _connectionType
	}

	init() throws {
		self.subscriptions = SubscriptionManager()
		let reachability = try Reachability()
		self._connectionType = Self.mapConnection(reachability.connection)
		reachability.whenReachable = self.onReachable
		reachability.whenUnreachable = self.onUnreachable
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

	private func onReachable(_ reachability: Reachability) {
		objc_sync_enter(self)
		self._connectionType = Self.mapConnection(reachability.connection)
		objc_sync_exit(self)
		DispatchQueue.main.async { self.subscriptions.call(value: ()) }
	}

	private func onUnreachable(_: Reachability) {
		objc_sync_enter(self)
		self._connectionType = .offline
		objc_sync_exit(self)
	}

	private static func mapConnection(_ connection: Reachability.Connection) -> ConnectionType {
		switch connection {
		case .unavailable:
			return .offline
		case .wifi:
			return .wifi
		case .cellular:
			return .cellularUnknown
		}
	}
}
