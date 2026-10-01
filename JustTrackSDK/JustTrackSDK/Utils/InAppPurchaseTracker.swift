import StoreKit

protocol InAppPurchaseTracker {
	func start(handler: InAppPurchaseHandler?)
	func set(enabled: Bool)
}

class InAppPurchaseTrackerImpl: InAppPurchaseTracker {
	private weak var handler: InAppPurchaseHandler?
	private weak var logger: Logger?
	private var enabled: Bool
	private let tracker: JTInAppPurchaseTracking

	convenience init(logger: Logger) {
		self.init(logger: logger, tracker: JTInAppPurchaseTracker())
	}

	internal init(logger: Logger, tracker: JTInAppPurchaseTracking) {
		self.handler = nil
		self.logger = logger
		self.enabled = false
		self.tracker = tracker
	}

	deinit {
		tracker.removeTransactionObserver()
	}

	func start(handler: InAppPurchaseHandler?) {
		self.handler = handler

		tracker.addTransactionObserver(
			self.handle(productId:transactionId:quantity:unitPrice:currency:isSubscription:),
			missingProductHandler: { productId in
				self.logger?.warn("Failed to find product", LoggerFieldsImpl().with("productId", productId))
			}
		)
	}

	func set(enabled: Bool) {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		self.enabled = enabled
	}

	private func handle(productId: String, transactionId: String?, quantity: Int, unitPrice: NSDecimalNumber, currency: String, isSubscription: Bool) {
		objc_sync_enter(self)
		let isEnabled = enabled
		objc_sync_exit(self)

		guard isEnabled else {
			return
		}

		let totalPrice = Money(value: NSDecimalNumber(decimal: unitPrice.decimalValue * Decimal(quantity)).doubleValue, currency: currency)

		if isSubscription {
			handler?.forwardInAppPurchase(transactionId: transactionId, subscriptionId: productId, totalPrice: totalPrice)
		} else {
			handler?.forwardInAppPurchase(transactionId: transactionId, productId: productId, totalPrice: totalPrice)
		}
	}
}
