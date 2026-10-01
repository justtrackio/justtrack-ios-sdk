import Foundation
import StoreKit

/// Observes `SKPaymentQueue` for completed transactions, resolves their `SKProduct`
/// via `SKProductsRequest`, and forwards the result through callbacks.
///
/// Test-injectable: production code depends on `JTInAppPurchaseTracking`.
protocol JTInAppPurchaseTracking: AnyObject {
	func addTransactionObserver(
		_ transactionHandler: @escaping (String, String?, Int, NSDecimalNumber, String, Bool) -> Void,
		missingProductHandler: @escaping (String) -> Void
	)
	func removeTransactionObserver()
}

final class JTInAppPurchaseTracker: NSObject, JTInAppPurchaseTracking {
	private var transactionHandler: ((String, String?, Int, NSDecimalNumber, String, Bool) -> Void)?
	private var missingProductHandler: ((String) -> Void)?
	private var productsRequestCompletionHandler: ((SKProduct?) -> Void)?

	func addTransactionObserver(
		_ transactionHandler: @escaping (String, String?, Int, NSDecimalNumber, String, Bool) -> Void,
		missingProductHandler: @escaping (String) -> Void
	) {
		self.transactionHandler = transactionHandler
		self.missingProductHandler = missingProductHandler
		SKPaymentQueue.default().add(self)
	}

	func removeTransactionObserver() {
		self.transactionHandler = nil
		self.missingProductHandler = nil
		SKPaymentQueue.default().remove(self)
	}

	internal func loadProduct(productId: String, completion: @escaping (SKProduct?) -> Void) {
		self.productsRequestCompletionHandler = completion
		let request = SKProductsRequest(productIdentifiers: [productId])
		request.delegate = self
		request.start()
	}

	internal func handleTransaction(
		productId: String,
		transactionId: String?,
		quantity: Int,
		price: NSDecimalNumber,
		currency: String,
		isSubscription: Bool
	) {
		transactionHandler?(productId, transactionId, quantity, price, currency, isSubscription)
	}
}

extension JTInAppPurchaseTracker: SKPaymentTransactionObserver {
	func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		for transaction in transactions {
			guard transaction.transactionState == .purchased else {
				continue
			}

			let productId = transaction.payment.productIdentifier
			let quantity = transaction.payment.quantity
			let transactionId = transaction.transactionIdentifier

			loadProduct(productId: productId) { [weak self] product in
				guard let self else { return }

				if let product {
					let price = product.price
					let currency = product.priceLocale.currencyCode ?? ""
					let isSubscription = product.subscriptionPeriod != nil

					self.handleTransaction(
						productId: productId,
						transactionId: transactionId,
						quantity: quantity,
						price: price,
						currency: currency,
						isSubscription: isSubscription
					)
				} else {
					self.missingProductHandler?(productId)
				}
			}
		}
	}
}

extension JTInAppPurchaseTracker: SKProductsRequestDelegate {
	func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
		guard let completion = productsRequestCompletionHandler else {
			return
		}

		if response.products.isEmpty {
			completion(nil)
		} else {
			completion(response.products.first)
		}

		productsRequestCompletionHandler = nil
	}
}
