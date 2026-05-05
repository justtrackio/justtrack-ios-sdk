import JustTrackSDK
import StoreKit
import SwiftUI

final class InAppProductProvider: NSObject, ObservableObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
	enum ProductId {
		static let consumablePurchase = "consumable_purchase"
		static let nonConsumablePurchase = "non_consumable_purchase"
		static let autoRenewableSubscription = "auto_renewable_subscription"
		static let nonRenewingSubscription = "non_renewing_subscription"
		static let testNonRenewingSubscription = "test_non_renewing_subscription"
		static let nonRenewingPremium = "non_renewing_premium"
		static let coins100 = "coins_100"
		static let coins500 = "coins_500"
		static let coins2500 = "coins_2500"
		static let premiumUnlock = "premium_unlock"
	}

	@Published var consumablePurchase: SKProduct?
	@Published var nonConsumablePurchase: SKProduct?
	@Published var autoRenewableSubscription: SKProduct?
	@Published var nonRenewingSubscription: SKProduct?
	@Published var testNonRenewingSubscription: SKProduct?
	@Published var nonRenewingPremium: SKProduct?
	@Published var coins100: SKProduct?
	@Published var coins500: SKProduct?
	@Published var coins2500: SKProduct?
	@Published var premiumUnlock: SKProduct?
	@Published var purchasedProducts: Set<String> = []

	override init() {
		super.init()
		SKPaymentQueue.default().add(self)
		fetchProducts()
	}

	deinit {
		SKPaymentQueue.default().remove(self)
	}

	func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
		var products = [String: SKProduct]()

		for product in response.products {
			products[product.productIdentifier] = product
		}

		DispatchQueue.main.async {
			self.consumablePurchase = products[ProductId.consumablePurchase]
			self.nonConsumablePurchase = products[ProductId.nonConsumablePurchase]
			self.autoRenewableSubscription = products[ProductId.autoRenewableSubscription]
			self.nonRenewingSubscription = products[ProductId.nonRenewingSubscription]
			self.testNonRenewingSubscription = products[ProductId.testNonRenewingSubscription]
			self.nonRenewingPremium = products[ProductId.nonRenewingPremium]
			self.coins100 = products[ProductId.coins100]
			self.coins500 = products[ProductId.coins500]
			self.coins2500 = products[ProductId.coins2500]
			self.premiumUnlock = products[ProductId.premiumUnlock]
		}
	}

	func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		for transaction in transactions {
			switch transaction.transactionState {
			case .purchased:
				DispatchQueue.main.async {
					self.purchasedProducts.insert(transaction.payment.productIdentifier)
				}
				SKPaymentQueue.default().finishTransaction(transaction)
			case .restored:
				DispatchQueue.main.async {
					self.purchasedProducts.insert(transaction.payment.productIdentifier)
				}
				SKPaymentQueue.default().finishTransaction(transaction)
			case .failed:
				SKPaymentQueue.default().finishTransaction(transaction)
			case .deferred, .purchasing:
				break
			@unknown default:
				break
			}
		}
	}

	func restorePurchases() {
		SKPaymentQueue.default().restoreCompletedTransactions()
	}

	private func fetchProducts() {
		let request = SKProductsRequest(
			productIdentifiers: [
				ProductId.consumablePurchase,
				ProductId.nonConsumablePurchase,
				ProductId.autoRenewableSubscription,
				ProductId.nonRenewingSubscription,
				ProductId.testNonRenewingSubscription,
				ProductId.nonRenewingPremium,
				ProductId.coins100,
				ProductId.coins500,
				ProductId.coins2500,
				ProductId.premiumUnlock,
			]
		)
		request.delegate = self
		request.start()
	}
}

struct InAppPurchasesView: View {
	@State private var shouldTrackPurchases = true
	@StateObject private var productProvider = InAppProductProvider()
	private var sdk: JustTrackSdk

	init(sdk: JustTrackSdk) {
		self.sdk = sdk
	}

	var body: some View {
		ScrollView {
			VStack {
				HStack {
					VStack(alignment: .leading) {
						ListItemTitleView("Track In-App Purchases")
						ListItemTextView("When the toggle is on, all in-app purchases are tracked automatically")
					}

					Spacer()

					Toggle("", isOn: $shouldTrackPurchases)
						.onChange(of: shouldTrackPurchases) { _ in updateTrackingStatus() }
						.frame(width: 56, alignment: .trailing)
				}
				.padding()

				VStack(alignment: .center, spacing: 12) {
					Text("Core Products")
						.font(.headline)
						.padding(.top)

					DefaultButton(
						productProvider.consumablePurchase?.localizedTitle ?? "No Product",
						action: {
							buy(product: productProvider.consumablePurchase)
						}
					)
					DefaultButton(
						productProvider.nonConsumablePurchase?.localizedTitle ?? "No Product",
						action: {
							buy(product: productProvider.nonConsumablePurchase)
						}
					)
					DefaultButton(
						productProvider.autoRenewableSubscription?.localizedTitle ?? "No Product",
						action: {
							buy(product: productProvider.autoRenewableSubscription)
						}
					)
					DefaultButton(
						productProvider.nonRenewingSubscription?.localizedTitle ?? "No Product",
						action: {
							buy(product: productProvider.nonRenewingSubscription)
						}
					)

					Divider()

					Text("Additional Test Products")
						.font(.headline)

					DefaultButton(
						productProvider.testNonRenewingSubscription?.localizedTitle ?? "No Product",
						action: {
							buy(product: productProvider.testNonRenewingSubscription)
						}
					)
					DefaultButton(
						productProvider.nonRenewingPremium?.localizedTitle ?? "No Product",
						action: {
							buy(product: productProvider.nonRenewingPremium)
						}
					)
					DefaultButton(
						productProvider.premiumUnlock?.localizedTitle ?? "No Product",
						action: {
							buy(product: productProvider.premiumUnlock)
						}
					)

					Divider()

					Text("Coins")
						.font(.headline)

					DefaultButton(
						productProvider.coins100?.localizedTitle ?? "No Product",
						action: {
							buy(product: productProvider.coins100)
						}
					)
					DefaultButton(
						productProvider.coins500?.localizedTitle ?? "No Product",
						action: {
							buy(product: productProvider.coins500)
						}
					)
					DefaultButton(
						productProvider.coins2500?.localizedTitle ?? "No Product",
						action: {
							buy(product: productProvider.coins2500)
						}
					)

					Divider()

					DefaultButton(
						"Restore Purchases",
						background: .blue,
						action: {
							productProvider.restorePurchases()
						}
					)
				}
				.frame(maxWidth: .infinity)
				.padding()
			}
		}
		.navigationTitle("In-App Purchases")
	}

	private func buy(product: SKProduct?) {
		guard let product, SKPaymentQueue.canMakePayments() else { return }
		let payment = SKPayment(product: product)
		SKPaymentQueue.default().add(payment)
	}

	private func updateTrackingStatus() {
		sdk.set(automaticInAppPurchaseTracking: shouldTrackPurchases)
	}
}
