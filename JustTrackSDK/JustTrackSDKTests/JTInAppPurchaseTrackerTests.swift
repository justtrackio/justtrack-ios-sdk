import Foundation
import StoreKit
import XCTest

@testable import JustTrackSDK

final class JTInAppPurchaseTrackerTests: XCTestCase {
	// MARK: - addTransactionObserver / removeTransactionObserver

	func testAddTransactionObserverStoresHandlers() {
		let sut = JTInAppPurchaseTracker()
		var received: (String, String?, Int, NSDecimalNumber, String, Bool)?
		var missing: String?

		sut.addTransactionObserver(
			{ pid, tid, qty, price, ccy, sub in
				received = (pid, tid, qty, price, ccy, sub)
			},
			missingProductHandler: { pid in
				missing = pid
			}
		)

		// Drive the stored transaction handler via the internal hook.
		sut.handleTransaction(
			productId: "p1",
			transactionId: "t1",
			quantity: 2,
			price: NSDecimalNumber(string: "1.99"),
			currency: "USD",
			isSubscription: false
		)

		XCTAssertEqual(received?.0, "p1")
		XCTAssertEqual(received?.1, "t1")
		XCTAssertEqual(received?.2, 2)
		XCTAssertEqual(received?.3, NSDecimalNumber(string: "1.99"))
		XCTAssertEqual(received?.4, "USD")
		XCTAssertEqual(received?.5, false)
		XCTAssertNil(missing)

		sut.removeTransactionObserver()
	}

	func testHandleTransactionDoesNothingWithoutObserver() {
		let sut = JTInAppPurchaseTracker()
		// No observer set; must not crash.
		sut.handleTransaction(
			productId: "p1",
			transactionId: nil,
			quantity: 1,
			price: .zero,
			currency: "USD",
			isSubscription: false
		)
	}

	func testRemoveTransactionObserverClearsHandlers() {
		let sut = JTInAppPurchaseTracker()
		var called = false
		sut.addTransactionObserver(
			{ _, _, _, _, _, _ in called = true },
			missingProductHandler: { _ in }
		)

		sut.removeTransactionObserver()

		sut.handleTransaction(
			productId: "p",
			transactionId: nil,
			quantity: 1,
			price: .zero,
			currency: "USD",
			isSubscription: false
		)
		XCTAssertFalse(called)
	}

	// MARK: - productsRequest(_:didReceive:)

	func testProductsRequestWithoutPendingCompletionIsNoop() {
		let sut = JTInAppPurchaseTracker()
		let response = FakeProductsResponse(products: [])
		// No completion stored; must not crash.
		sut.productsRequest(SKProductsRequest(), didReceive: response)
	}

	func testProductsRequestWithEmptyResponseDeliversNil() {
		let sut = JTInAppPurchaseTracker()
		let expectation = expectation(description: "completion")
		var delivered: SKProduct?
		var didFire = false
		sut.loadProduct(productId: "p1") { product in
			didFire = true
			delivered = product
			expectation.fulfill()
		}

		sut.productsRequest(SKProductsRequest(), didReceive: FakeProductsResponse(products: []))

		wait(for: [expectation], timeout: 1.0)
		XCTAssertTrue(didFire)
		XCTAssertNil(delivered)
	}

	func testProductsRequestWithProductDeliversFirstProduct() {
		let sut = JTInAppPurchaseTracker()
		let product = FakeProduct(productId: "p1", price: NSDecimalNumber(string: "0.99"))
		let expectation = expectation(description: "completion")
		var delivered: SKProduct?
		sut.loadProduct(productId: "p1") { p in
			delivered = p
			expectation.fulfill()
		}

		sut.productsRequest(SKProductsRequest(), didReceive: FakeProductsResponse(products: [product]))

		wait(for: [expectation], timeout: 1.0)
		XCTAssertTrue(delivered === product)
	}

	func testProductsRequestClearsCompletionAfterDelivery() {
		let sut = JTInAppPurchaseTracker()
		var firstCount = 0
		sut.loadProduct(productId: "p1") { _ in firstCount += 1 }
		sut.productsRequest(SKProductsRequest(), didReceive: FakeProductsResponse(products: []))
		XCTAssertEqual(firstCount, 1)

		// Second invocation without re-arming must be a no-op.
		sut.productsRequest(SKProductsRequest(), didReceive: FakeProductsResponse(products: []))
		XCTAssertEqual(firstCount, 1)
	}

	// MARK: - paymentQueue(_:updatedTransactions:)

	func testPaymentQueueIgnoresNonPurchasedStates() {
		let sut = JTInAppPurchaseTracker()
		var handlerCalled = false
		sut.addTransactionObserver(
			{ _, _, _, _, _, _ in handlerCalled = true },
			missingProductHandler: { _ in }
		)

		let tx = FakeTransaction(
			productId: "p1",
			quantity: 1,
			transactionId: "t1",
			state: .purchasing
		)
		sut.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [tx])

		XCTAssertFalse(handlerCalled)
		sut.removeTransactionObserver()
	}

	func testPaymentQueueForwardsPurchasedNonSubscription() {
		let sut = JTInAppPurchaseTracker()
		let expectation = expectation(description: "handler")
		var captured: (String, String?, Int, NSDecimalNumber, String, Bool)?
		sut.addTransactionObserver(
			{ pid, tid, qty, price, ccy, sub in
				captured = (pid, tid, qty, price, ccy, sub)
				expectation.fulfill()
			},
			missingProductHandler: { _ in
				XCTFail("missingProductHandler should not be called")
			}
		)

		let tx = FakeTransaction(
			productId: "p1",
			quantity: 3,
			transactionId: "t-1",
			state: .purchased
		)
		sut.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [tx])

		let product = FakeProduct(
			productId: "p1",
			price: NSDecimalNumber(string: "2.50"),
			currencyCode: "EUR",
			subscriptionPeriod: nil
		)
		sut.productsRequest(SKProductsRequest(), didReceive: FakeProductsResponse(products: [product]))

		wait(for: [expectation], timeout: 1.0)
		XCTAssertEqual(captured?.0, "p1")
		XCTAssertEqual(captured?.1, "t-1")
		XCTAssertEqual(captured?.2, 3)
		XCTAssertEqual(captured?.3, NSDecimalNumber(string: "2.50"))
		XCTAssertEqual(captured?.4, "EUR")
		XCTAssertEqual(captured?.5, false)
		sut.removeTransactionObserver()
	}

	func testPaymentQueueForwardsPurchasedSubscription() {
		let sut = JTInAppPurchaseTracker()
		let expectation = expectation(description: "handler")
		var captured: (String, String?, Int, NSDecimalNumber, String, Bool)?
		sut.addTransactionObserver(
			{ pid, tid, qty, price, ccy, sub in
				captured = (pid, tid, qty, price, ccy, sub)
				expectation.fulfill()
			},
			missingProductHandler: { _ in }
		)

		let tx = FakeTransaction(
			productId: "sub1",
			quantity: 1,
			transactionId: "t-sub",
			state: .purchased
		)
		sut.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [tx])

		let period = FakeSubscriptionPeriod()
		let product = FakeProduct(
			productId: "sub1",
			price: NSDecimalNumber(string: "4.99"),
			currencyCode: "USD",
			subscriptionPeriod: period
		)
		sut.productsRequest(SKProductsRequest(), didReceive: FakeProductsResponse(products: [product]))

		wait(for: [expectation], timeout: 1.0)
		XCTAssertEqual(captured?.0, "sub1")
		XCTAssertEqual(captured?.5, true, "should be detected as subscription")
		sut.removeTransactionObserver()
	}

	func testPaymentQueueUsesEmptyCurrencyWhenLocaleHasNoCurrencyCode() {
		let sut = JTInAppPurchaseTracker()
		let expectation = expectation(description: "handler")
		var captured: (String, String?, Int, NSDecimalNumber, String, Bool)?
		sut.addTransactionObserver(
			{ pid, tid, qty, price, ccy, sub in
				captured = (pid, tid, qty, price, ccy, sub)
				expectation.fulfill()
			},
			missingProductHandler: { _ in }
		)

		let tx = FakeTransaction(
			productId: "p1",
			quantity: 1,
			transactionId: nil,
			state: .purchased
		)
		sut.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [tx])

		let product = FakeProduct(
			productId: "p1",
			price: .one,
			currencyCode: nil,
			subscriptionPeriod: nil
		)
		sut.productsRequest(SKProductsRequest(), didReceive: FakeProductsResponse(products: [product]))

		wait(for: [expectation], timeout: 1.0)
		XCTAssertEqual(captured?.4, "")
		XCTAssertNil(captured?.1)
		sut.removeTransactionObserver()
	}

	func testPaymentQueueFiresMissingProductHandlerWhenProductMissing() {
		let sut = JTInAppPurchaseTracker()
		let expectation = expectation(description: "missing")
		var missing: String?
		sut.addTransactionObserver(
			{ _, _, _, _, _, _ in
				XCTFail("transactionHandler should not be called when product is missing")
			},
			missingProductHandler: { pid in
				missing = pid
				expectation.fulfill()
			}
		)

		let tx = FakeTransaction(
			productId: "missing-pid",
			quantity: 1,
			transactionId: "t-x",
			state: .purchased
		)
		sut.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [tx])
		sut.productsRequest(SKProductsRequest(), didReceive: FakeProductsResponse(products: []))

		wait(for: [expectation], timeout: 1.0)
		XCTAssertEqual(missing, "missing-pid")
		sut.removeTransactionObserver()
	}

	func testPaymentQueueWithMixedTransactionsOnlyProcessesPurchased() {
		let sut = JTInAppPurchaseTracker()
		var handlerCalls = 0
		sut.addTransactionObserver(
			{ _, _, _, _, _, _ in handlerCalls += 1 },
			missingProductHandler: { _ in }
		)

		let txs: [SKPaymentTransaction] = [
			FakeTransaction(productId: "p1", quantity: 1, transactionId: "t1", state: .failed),
			FakeTransaction(productId: "p2", quantity: 1, transactionId: "t2", state: .deferred),
			FakeTransaction(productId: "p3", quantity: 1, transactionId: "t3", state: .restored),
			FakeTransaction(productId: "p4", quantity: 1, transactionId: "t4", state: .purchased),
		]
		sut.paymentQueue(SKPaymentQueue.default(), updatedTransactions: txs)

		let product = FakeProduct(productId: "p4", price: .one)
		// Only the purchased transaction should have armed loadProduct's completion.
		sut.productsRequest(SKProductsRequest(), didReceive: FakeProductsResponse(products: [product]))

		XCTAssertEqual(handlerCalls, 1)
		sut.removeTransactionObserver()
	}

	func testPaymentQueueWithEmptyArrayIsNoop() {
		let sut = JTInAppPurchaseTracker()
		var called = false
		sut.addTransactionObserver(
			{ _, _, _, _, _, _ in called = true },
			missingProductHandler: { _ in called = true }
		)

		sut.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [])

		XCTAssertFalse(called)
		sut.removeTransactionObserver()
	}
}

// MARK: - Test doubles

private final class FakePayment: SKPayment {
	private let _productIdentifier: String
	private let _quantity: Int

	init(productId: String, quantity: Int) {
		self._productIdentifier = productId
		self._quantity = quantity
		super.init()
	}

	override var productIdentifier: String { _productIdentifier }
	override var quantity: Int { _quantity }
}

private final class FakeTransaction: SKPaymentTransaction {
	private let _payment: SKPayment
	private let _transactionIdentifier: String?
	private let _transactionState: SKPaymentTransactionState

	init(productId: String, quantity: Int, transactionId: String?, state: SKPaymentTransactionState) {
		self._payment = FakePayment(productId: productId, quantity: quantity)
		self._transactionIdentifier = transactionId
		self._transactionState = state
		super.init()
	}

	override var payment: SKPayment { _payment }
	override var transactionIdentifier: String? { _transactionIdentifier }
	override var transactionState: SKPaymentTransactionState { _transactionState }
}

private final class FakeProduct: SKProduct {
	private let _productIdentifier: String
	private let _price: NSDecimalNumber
	private let _priceLocale: Locale
	private let _subscriptionPeriod: SKProductSubscriptionPeriod?

	init(
		productId: String,
		price: NSDecimalNumber,
		currencyCode: String? = "USD",
		subscriptionPeriod: SKProductSubscriptionPeriod? = nil
	) {
		self._productIdentifier = productId
		self._price = price
		switch currencyCode {
		case "USD": self._priceLocale = Locale(identifier: "en_US")
		case "EUR": self._priceLocale = Locale(identifier: "de_DE")
		case .none: self._priceLocale = Locale(identifier: "")
		case .some(let code):
			// Fallback: synthesize locale by code; Apple honours this for
			// most ISO 4217 codes via the standard country mapping.
			self._priceLocale = Locale(identifier: "en_US")
			assertionFailure("Unhandled currency code in tests: \(code)")
		}
		self._subscriptionPeriod = subscriptionPeriod
		super.init()
	}

	override var productIdentifier: String { _productIdentifier }
	override var price: NSDecimalNumber { _price }
	override var priceLocale: Locale { _priceLocale }

	@available(iOS 12.0, *)
	override var subscriptionPeriod: SKProductSubscriptionPeriod? { _subscriptionPeriod }
}

private final class FakeSubscriptionPeriod: SKProductSubscriptionPeriod {}

private final class FakeProductsResponse: SKProductsResponse {
	private let _products: [SKProduct]

	init(products: [SKProduct]) {
		self._products = products
		super.init()
	}

	override var products: [SKProduct] { _products }
}
