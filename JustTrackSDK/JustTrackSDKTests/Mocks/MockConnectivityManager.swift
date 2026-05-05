@testable import JustTrackSDK

final class MockConnectivityManager: ConnectivityManager {
	enum Call: Equatable {
		case registerOnReconnect
		case shutdown
	}

	var calls = [Call]()

	var registerOnReconnectSubscriptions = SubscriptionManager<Void>()

	func reset() {
		calls = []
	}

	func registerOnReconnect(_ callback: @escaping () -> Void) -> Subscription {
		calls.append(.registerOnReconnect)
		return registerOnReconnectSubscriptions.subscribe(listener: { _ in
			callback()
		})
	}

	func shutdown() {
		calls.append(.shutdown)
	}
}
