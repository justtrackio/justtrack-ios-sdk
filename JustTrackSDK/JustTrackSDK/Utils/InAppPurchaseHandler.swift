import Foundation
import StoreKit

final class InAppPurchaseHandler {
	private weak var sdk: JustTrackSdk?
	private let logger: Logger

	init(sdk: JustTrackSdk, logger: Logger) {
		self.sdk = sdk
		self.logger = logger
	}

	@available(iOS 15.0, *)
	func reportOnTransactionId(_ transactionId: UInt64, productId: String, quantity: Int) {
		Task {
			await report(transactionId: transactionId, productId: productId, quantity: quantity)
		}
	}

	@available(iOS 15.0, *)
	private func report(transactionId: UInt64, productId: String, quantity: Int) async {
		do {
			if let product = (try await Product.products(for: [productId])).first {
				await report(transactionId: transactionId, product: product, quantity: quantity)
			} else {
				await reportOnMissingProduct(productId: productId)
			}
		} catch {
			await reportOnMissingProduct(productId: productId, error: error)
		}
	}

	@available(iOS 15.0, *)
	@MainActor
	private func report(transactionId: UInt64, product: Product, quantity: Int) {
		let transactionId = String(transactionId)
		let productId = product.id
		let unitPrice = product.price
		let currency = product.priceFormatStyle.currencyCode
		let isSubscription = [.autoRenewable, .nonRenewable].contains(product.type)
		let totalPrice = Money(value: NSDecimalNumber(decimal: unitPrice * Decimal(quantity)).doubleValue, currency: currency)
		if isSubscription {
			forwardInAppPurchase(transactionId: transactionId, subscriptionId: productId, totalPrice: totalPrice)
		} else {
			forwardInAppPurchase(transactionId: transactionId, productId: productId, totalPrice: totalPrice)
		}
	}

	func forwardInAppPurchase(transactionId: String?, productId: String, totalPrice: Money) {
		forwardInAppPurchase(
			transactionId: transactionId,
			productId: productId,
			eventProductType: "purchase",
			logPurchaseKind: "product",
			productIdField: "productId",
			totalPrice: totalPrice
		)
	}

	func forwardInAppPurchase(transactionId: String?, subscriptionId: String, totalPrice: Money) {
		forwardInAppPurchase(
			transactionId: transactionId,
			productId: subscriptionId,
			eventProductType: "subscription",
			logPurchaseKind: "subscription",
			productIdField: "subscriptionId",
			totalPrice: totalPrice
		)
	}

	private func forwardInAppPurchase(
		transactionId: String?,
		productId: String,
		eventProductType: String,
		logPurchaseKind: String,
		productIdField: String,
		totalPrice: Money
	) {
		if totalPrice.value < 0 {
			logger.warn(
				"Negative revenue for \(logPurchaseKind) purchase",
				LoggerFieldsImpl()
					.with(productIdField, productId)
					.with("revenue", totalPrice.value)
					.with("currency", totalPrice.currency)
			)

			return
		}

		do {
			try totalPrice.validate()
		} catch {
			logger.warn("Not publishing invalid \(logPurchaseKind) purchase: \(error)", LoggerFieldsImpl().with(productIdField, productId))

			return
		}

		guard let sdk else {
			return
		}

		_ = sdk.track(
			event: JtPurchaseInternalEvent(
				jtAction: "success",
				jtProductId: productId,
				jtToken: transactionId ?? readReceiptData() ?? "",
				jtProductType: eventProductType,
				revenue: totalPrice,
				happenedAt: Date()
			)
		)
	}

	@MainActor
	private func reportOnMissingProduct(productId: String, error: Error? = nil) {
		var fields = LoggerFieldsImpl().with("productId", productId)
		if let error {
			fields = fields.with("error", error.justTrackGetErrorDescription())
		}
		logger.warn("Failed to find product", fields)
	}

	private func readReceiptData() -> String? {
		if let appStoreReceiptUrl = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: appStoreReceiptUrl.path) {
			do {
				let receiptData = try Data(contentsOf: appStoreReceiptUrl, options: .alwaysMapped)

				return receiptData.base64EncodedString()
			} catch {
				logger.warn("Failed to read receipt data", LoggerFieldsImpl().with("error", error))
			}
		} else {
			logger.debug("No receipt data file available")
		}

		return nil
	}
}
