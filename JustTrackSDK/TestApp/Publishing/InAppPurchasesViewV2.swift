import JustTrackSDK
import StoreKit
import SwiftUI

struct ProductHolder: Hashable {
	let id = UUID()

	var transaction: StoreKit.Transaction?
	let product: Product
	var isRefunded = false
	var subscriptionStatus: Product.SubscriptionInfo.Status?

	init(product: Product) {
		self.product = product
	}

	init(isRefunded: Bool, transaction: StoreKit.Transaction, product: Product) {
		self.isRefunded = isRefunded
		self.transaction = transaction
		self.product = product
	}
}

@MainActor
final class InAppProductProviderV2: ObservableObject {
	@Published var products: [ProductHolder] = []
	@Published var purchasedProducts: Set<String> = []
	@Published var isRestoring = false
	@Published var restoreMessage = ""

	private var updateListenerTask: Task<Void, Never>?

	init() {
		fetchProducts()
		startTransactionListener()
		updatePurchasedProducts()
	}

	deinit {
		updateListenerTask?.cancel()
	}

	private func startTransactionListener() {
		updateListenerTask = Task {
			for await result in StoreKit.Transaction.updates {
				switch result {
				case let .verified(transaction):
					await self.handleTransaction(transaction)
				case let .unverified(transaction, _):
					await self.handleTransaction(transaction)
				}
			}
		}
	}

	private func handleTransaction(_ transaction: StoreKit.Transaction) async {
		if transaction.revocationDate != nil {
			purchasedProducts.remove(transaction.productID)
		} else {
			purchasedProducts.insert(transaction.productID)
		}
		await updateProductStatuses()
	}

	private func updatePurchasedProducts() {
		Task {
			for await result in Transaction.currentEntitlements {
				switch result {
				case let .verified(transaction):
					if transaction.revocationDate == nil {
						purchasedProducts.insert(transaction.productID)
					}
				case let .unverified(transaction, _):
					if transaction.revocationDate == nil {
						purchasedProducts.insert(transaction.productID)
					}
				}
			}
			await updateProductStatuses()
		}
	}

	private func updateProductStatuses() async {
		for i in products.indices {
			let product = products[i].product
			if product.type == .autoRenewable {
				let statuses = try? await product.subscription?.status
				products[i].subscriptionStatus = statuses?.first
			}
		}
	}

	private func fetchProducts() {
		Task(priority: .high) {
			products = try await Product.products(
				for: [
					"test_consumable_purchase",
					"test_consumable_purchase_2",
					"test_consumable_purchase_3",
					"test_non_consumable_purchase",
					"test_non_consumable_purchase_2",
					"test_non_consumable_purchase_3",
					"test_auto_renewable_subscription",
					"test_auto_renewable_subscription_2_1",
					"test_auto_renewable_subscription_3",
					"test_auto_renewable_subscription_5",
					"test_auto_renewable_subscription_6",
					"test_auto_renewable_subscription_7",
					"test_non_renewing_subscription",
					"non_renewing_premium",
					"coins_100",
					"coins_500",
					"coins_2500",
					"premium_unlock",
				]
			).map(ProductHolder.init)
			await updateProductStatuses()
		}
	}

	func restorePurchases() async {
		isRestoring = true
		restoreMessage = "Restoring purchases..."

		do {
			try await AppStore.sync()
			purchasedProducts.removeAll()

			for await result in Transaction.currentEntitlements {
				switch result {
				case let .verified(transaction):
					if transaction.revocationDate == nil {
						purchasedProducts.insert(transaction.productID)
						await transaction.finish()
					}
				case let .unverified(transaction, _):
					if transaction.revocationDate == nil {
						purchasedProducts.insert(transaction.productID)
						await transaction.finish()
					}
				}
			}

			await updateProductStatuses()
			restoreMessage = "Restored \(purchasedProducts.count) purchase(s)"
		} catch {
			restoreMessage = "Restore failed: \(error.localizedDescription)"
		}

		isRestoring = false

		DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
			self.restoreMessage = ""
		}
	}
}

struct InAppPurchasesViewV2: View {
	@State private var showManageSubscriptions = false
	@StateObject private var productProvider = InAppProductProviderV2()
	private var sdk: JustTrackSdk

	init(sdk: JustTrackSdk) {
		self.sdk = sdk
	}

	var body: some View {
		ScrollView {
			VStack(spacing: 16) {
				if !productProvider.restoreMessage.isEmpty {
					Text(productProvider.restoreMessage)
						.padding()
						.background(Color.blue.opacity(0.1))
						.cornerRadius(8)
				}

				HStack(spacing: 8) {
					DefaultButton("Restore Purchases", background: .blue) {
						Task {
							await productProvider.restorePurchases()
						}
					}
					.disabled(productProvider.isRestoring)
					.frame(maxWidth: .infinity)

					DefaultButton("Manage Subscriptions", background: .green) {
						showManageSubscriptions = true
					}
					.frame(maxWidth: .infinity)
				}
				.padding(.horizontal)

				Divider()

				VStack(spacing: 16) {
					ForEach(productProvider.products.sorted(by: { $0.product.displayName < $1.product.displayName }), id: \.self) { holder in
						ProductRowView(
							holder: holder,
							isPurchased: productProvider.purchasedProducts.contains(holder.product.id),
							onBuy: { product in
								buy(product: product)
							},
							onRefund: { product, transaction in
								refund(soldProduct: product, transaction: transaction)
							}
						)
					}
				}
				.padding()
			}
		}
		.navigationTitle("In-App Purchases V2")
		.sheet(isPresented: $showManageSubscriptions) {
			ManageSubscriptionsView()
		}
	}

	private func buy(product: Product?) {
		guard let product else { return }
		Task(priority: .high) {
			do {
				let installId = try await sdk.getInstallInstanceId().async()
				guard let token = UUID(uuidString: installId) else {
					print("Failed to create UUID from install instance ID: \(installId)")
					return
				}
				let purchaseResult = try await product.purchase(options: [
					.appAccountToken(token)
				])
				switch purchaseResult {
				case let .success(transactionResult):
					switch transactionResult {
					case let .verified(transaction):
						_ = sdk.forward(transaction: transaction)
						await transaction.finish()
						update(isRefunded: false, soldProduct: product, transaction: transaction)
					case let .unverified(transaction, _):
						_ = sdk.forward(transaction: transaction)
						await transaction.finish()
						update(isRefunded: false, soldProduct: product, transaction: transaction)
					}
				default:
					print("Purchase is not successful: \(purchaseResult)")
				}
			} catch {
				print("Failed to purchase product: \(error)")
			}
		}
	}

	private func refund(soldProduct: Product, transaction: StoreKit.Transaction) {
		Task(priority: .high) {
			do {
				if let windowScene = UIApplication.shared
					.connectedScenes
					.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
				{
					try await _ = transaction.beginRefundRequest(in: windowScene)
					update(isRefunded: true, soldProduct: soldProduct, transaction: transaction)
				} else {
					print("No active window scene found.")
				}
			} catch {
				print("Failed to initiate refund request: \(error)")
			}
		}
	}

	@MainActor
	private func update(isRefunded: Bool, soldProduct: Product, transaction: StoreKit.Transaction) {
		guard let productIndex = productProvider.products.firstIndex(where: { $0.product == soldProduct }) else { return }
		productProvider.products[productIndex] = ProductHolder(isRefunded: isRefunded, transaction: transaction, product: soldProduct)

		if isRefunded {
			productProvider.purchasedProducts.remove(soldProduct.id)
		} else {
			productProvider.purchasedProducts.insert(soldProduct.id)
		}
	}
}

struct ProductRowView: View {
	let holder: ProductHolder
	let isPurchased: Bool
	let onBuy: (Product) -> Void
	let onRefund: (Product, StoreKit.Transaction) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				VStack(alignment: .leading, spacing: 4) {
					Text(holder.product.displayName)
						.font(.headline)
					Text(holder.product.displayPrice)
						.font(.subheadline)
						.foregroundColor(.secondary)

					if let subscriptionInfo = holder.product.subscription {
						Text(periodText(for: subscriptionInfo.subscriptionPeriod))
							.font(.caption)
							.foregroundColor(.blue)
					}

					if let status = holder.subscriptionStatus {
						switch status.state {
						case .subscribed:
							Text("Active Subscription")
								.font(.caption)
								.foregroundColor(.green)
						case .expired:
							Text("Expired")
								.font(.caption)
								.foregroundColor(.red)
						case .inBillingRetryPeriod:
							Text("Billing Retry")
								.font(.caption)
								.foregroundColor(.orange)
						case .inGracePeriod:
							Text("Grace Period")
								.font(.caption)
								.foregroundColor(.orange)
						case .revoked:
							Text("Revoked")
								.font(.caption)
								.foregroundColor(.red)
						default:
							EmptyView()
						}
					}
				}

				Spacer()

				if holder.isRefunded {
					DefaultButton("Refunded", background: .gray.opacity(0.25)) {}
						.disabled(true)
						.frame(width: 120)
				} else if let transaction = holder.transaction {
					VStack(spacing: 4) {
						DefaultButton("Refund", background: .red) {
							onRefund(holder.product, transaction)
						}
						.frame(width: 120)

						if holder.product.type == .autoRenewable {
							DefaultButton("Cancel", background: .orange) {
								cancelSubscription(for: holder.product)
							}
							.frame(width: 120)
						}
					}
				} else if isPurchased && holder.product.type != .consumable {
					Text("Purchased")
						.font(.caption)
						.foregroundColor(.green)
						.frame(width: 120)
				} else {
					DefaultButton("Buy", background: .blue) {
						onBuy(holder.product)
					}
					.frame(width: 120)
				}
			}
			.padding()
			.background(Color.gray.opacity(0.05))
			.cornerRadius(8)
		}
	}

	private func periodText(for period: Product.SubscriptionPeriod) -> String {
		switch period.unit {
		case .day:
			return period.value == 1 ? "Daily" : "\(period.value) Days"
		case .week:
			return period.value == 1 ? "Weekly" : "\(period.value) Weeks"
		case .month:
			return period.value == 1 ? "Monthly" : "\(period.value) Months"
		case .year:
			return period.value == 1 ? "Yearly" : "\(period.value) Years"
		@unknown default:
			return "Unknown Period"
		}
	}

	private func cancelSubscription(for product: Product) {
		Task {
			do {
				if let windowScene = UIApplication.shared
					.connectedScenes
					.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
				{
					try await AppStore.showManageSubscriptions(in: windowScene)
				}
			} catch {
				print("Failed to show manage subscriptions: \(error)")
			}
		}
	}
}

struct ManageSubscriptionsView: View {
	@Environment(\.dismiss) var dismiss
	@State private var isLoading = false
	@State private var errorMessage = ""

	var body: some View {
		NavigationView {
			VStack(spacing: 20) {
				Text("Manage Subscriptions")
					.font(.largeTitle)
					.padding()

				Text("Use this screen to manage your active subscriptions")
					.multilineTextAlignment(.center)
					.padding()

				DefaultButton("Open Subscription Management", background: .blue) {
					Task {
						await openSubscriptionManagement()
					}
				}
				.disabled(isLoading)

				if !errorMessage.isEmpty {
					Text(errorMessage)
						.foregroundColor(.red)
						.padding()
				}

				Spacer()
			}
			.navigationBarItems(trailing: Button("Done") { dismiss() })
		}
	}

	private func openSubscriptionManagement() async {
		isLoading = true
		errorMessage = ""

		do {
			if let windowScene = UIApplication.shared
				.connectedScenes
				.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
			{
				try await AppStore.showManageSubscriptions(in: windowScene)
			}
		} catch {
			errorMessage = "Failed to open subscriptions: \(error.localizedDescription)"
		}

		isLoading = false
	}
}
