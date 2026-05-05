import Foundation

/// Protocol for managing subscriptions that can be cancelled.
public protocol Subscription {
	/// Cancels the subscription and removes the associated listener.
	func unsubscribe()
}

class SubscriptionManager<Value> {
	typealias Callback = (Value) -> Void

	private var nextId: Int
	private var subscriptions: [Int: Callback]

	init() {
		self.nextId = 1
		self.subscriptions = [:]
	}

	func subscribe(listener: @escaping Callback) -> Subscription {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		let currentId = nextId
		self.nextId += 1
		self.subscriptions[currentId] = listener

		return SubscriptionImpl(manager: self, id: currentId)
	}

	fileprivate func unsubscribe(id: Int) {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		_ = self.subscriptions.removeValue(forKey: id)
	}

	func call(value: Value) {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		for subscription in subscriptions {
			DispatchQueue.main.async {
				subscription.value(value)
			}
		}
	}
}

struct SubscriptionImpl<Value>: Subscription {
	private weak var manager: SubscriptionManager<Value>?
	private let id: Int

	fileprivate init(manager: SubscriptionManager<Value>, id: Int) {
		self.manager = manager
		self.id = id
	}

	public func unsubscribe() {
		self.manager?.unsubscribe(id: self.id)
	}
}
