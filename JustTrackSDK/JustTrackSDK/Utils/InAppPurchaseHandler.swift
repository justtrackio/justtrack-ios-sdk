import StoreKit

@available(iOS 15.0, *)
final class InAppPurchaseHandler {
	static let shared = InAppPurchaseHandler()

	func report(on transaction: Transaction, sdk: JustTrackSdkImpl, logger: Logger) {
		Task {
			await report(transactionId: transaction.id, productId: transaction.productID, quantity: transaction.purchasedQuantity, sdk: sdk, logger: logger)
		}
	}

	func reportOnTransactionId(_ transactionId: UInt64, productId: String, quantity: Int, sdk: JustTrackSdkImpl, logger: Logger) {
		Task {
			await report(transactionId: transactionId, productId: productId, quantity: quantity, sdk: sdk, logger: logger)
		}
	}

	private func report(transactionId: UInt64, productId: String, quantity: Int, sdk: JustTrackSdkImpl, logger: Logger) async {
		do {
			if let product = (try await Product.products(for: [productId])).first {
				await report(transactionId: transactionId, product: product, quantity: quantity, sdk: sdk)
			} else {
				await reportOnMissingProduct(productId: productId, logger: logger)
			}
		} catch {
			await reportOnMissingProduct(productId: productId, logger: logger, error: error)
		}
	}

	@MainActor
	private func report(transactionId: UInt64, product: Product, quantity: Int, sdk: JustTrackSdkImpl) {
		let transactionId = String(transactionId)
		let productId = product.id
		let unitPrice = product.price
		let currency = product.priceFormatStyle.currencyCode
		let isSubscription = [.autoRenewable, .nonRenewable].contains(product.type)
		let totalPrice = Money(value: NSDecimalNumber(decimal: unitPrice * Decimal(quantity)).doubleValue, currency: currency)
		if isSubscription {
			_ = sdk.forwardInAppPurchase(transactionId: transactionId, subscriptionId: productId, totalPrice: totalPrice)
		} else {
			_ = sdk.forwardInAppPurchase(transactionId: transactionId, productId: productId, totalPrice: totalPrice)
		}
	}

	@MainActor
	private func reportOnMissingProduct(productId: String, logger: Logger, error: Error? = nil) {
		var fields = LoggerFieldsImpl().with("productId", productId)
		if let error {
			fields = fields.with("error", error.justTrackGetErrorDescription())
		}
		logger.warn("Failed to find product", fields)
	}
}
