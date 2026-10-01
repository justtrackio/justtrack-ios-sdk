import StoreKit
import StoreKitTest
import XCTest

@testable import JustTrackSDK

@available(iOS 15.0, *)
final class InAppPurchaseHandlerTests: XCTestCase {
	private var storeKitSession: SKTestSession?

	override func setUpWithError() throws {
		try super.setUpWithError()
		JustTrack.resetForTesting(clearStorage: true)

		let storeKitConfigurationUrl = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "TestApp", withExtension: "storekit"))
		storeKitSession = try SKTestSession(contentsOf: storeKitConfigurationUrl)
		storeKitSession?.clearTransactions()
		storeKitSession?.disableDialogs = true
	}

	override func tearDownWithError() throws {
		storeKitSession?.clearTransactions()
		storeKitSession = nil
		JustTrack.resetForTesting(clearStorage: true)

		try super.tearDownWithError()
	}

	func testReportOnTransactionIdPublishesConsumablePurchaseFromStoreKitProduct() throws {
		let productId = "consumable_purchase"
		let transactionId: UInt64 = 123
		let expectedQuantity = 2
		let expectedProduct = try awaitProduct(with: productId)
		let logger = MockLogger()
		let tracker = SpyInAppPurchaseEventTracker()

		let handler = InAppPurchaseHandler(sdk: tracker, logger: logger)
		handler.reportOnTransactionId(
			transactionId,
			productId: productId,
			quantity: expectedQuantity
		)

		let baseEvent = try waitForPurchaseEvent(in: tracker).build(sessionId: "sessionId")
		assertPurchaseEvent(
			baseEvent,
			productId: productId,
			productType: "purchase",
			token: String(transactionId),
			value: NSDecimalNumber(decimal: expectedProduct.price * Decimal(expectedQuantity)).doubleValue,
			currency: expectedProduct.priceFormatStyle.currencyCode
		)
	}

	func testReportOnTransactionIdPublishesSubscriptionFromStoreKitProduct() throws {
		let productId = "non_renewing_subscription"
		let transactionId: UInt64 = 456
		let expectedQuantity = 3
		let expectedProduct = try awaitProduct(with: productId)
		let logger = MockLogger()
		let tracker = SpyInAppPurchaseEventTracker()

		let handler = InAppPurchaseHandler(sdk: tracker, logger: logger)
		handler.reportOnTransactionId(
			transactionId,
			productId: productId,
			quantity: expectedQuantity
		)

		let baseEvent = try waitForPurchaseEvent(in: tracker).build(sessionId: "sessionId")
		assertPurchaseEvent(
			baseEvent,
			productId: productId,
			productType: "subscription",
			token: String(transactionId),
			value: NSDecimalNumber(decimal: expectedProduct.price * Decimal(expectedQuantity)).doubleValue,
			currency: expectedProduct.priceFormatStyle.currencyCode
		)
	}

	func testReportOnTransactionIdLogsWarningWhenStoreKitProductIsMissing() throws {
		let logger = MockLogger()
		let tracker = SpyInAppPurchaseEventTracker()
		let handler = InAppPurchaseHandler(sdk: tracker, logger: logger)

		handler.reportOnTransactionId(789, productId: "missing_product", quantity: 1)

		try waitForLog(in: logger) { entry in
			entry.level == .warn && entry.message == "Failed to find product"
		}
		XCTAssertTrue(tracker.events.isEmpty)
	}

	func testForwardInAppPurchasePublishesProductPurchase() throws {
		let logger = MockLogger()
		let tracker = SpyInAppPurchaseEventTracker()
		let handler = InAppPurchaseHandler(sdk: tracker, logger: logger)

		handler.forwardInAppPurchase(
			transactionId: "transaction-id",
			productId: "product-id",
			totalPrice: Money(value: 12.34, currency: "USD")
		)

		let baseEvent = try XCTUnwrap(tracker.events.first).build(sessionId: "sessionId")
		assertPurchaseEvent(
			baseEvent,
			productId: "product-id",
			productType: "purchase",
			token: "transaction-id",
			value: 12.34,
			currency: "USD"
		)
	}

	func testForwardInAppPurchaseUsesEmptyTokenWhenProductTransactionIdAndReceiptAreMissing() throws {
		let logger = MockLogger()
		let tracker = SpyInAppPurchaseEventTracker()
		let handler = InAppPurchaseHandler(sdk: tracker, logger: logger)

		handler.forwardInAppPurchase(
			transactionId: nil,
			productId: "product-id",
			totalPrice: Money(value: 1.0, currency: "USD")
		)

		let baseEvent = try XCTUnwrap(tracker.events.first).build(sessionId: "sessionId")
		assertPurchaseEvent(
			baseEvent,
			productId: "product-id",
			productType: "purchase",
			token: nil,
			value: 1.0,
			currency: "USD"
		)
	}

	func testForwardInAppPurchaseRejectsNegativeProductRevenue() {
		let logger = MockLogger()
		let tracker = SpyInAppPurchaseEventTracker()
		let handler = InAppPurchaseHandler(sdk: tracker, logger: logger)

		handler.forwardInAppPurchase(
			transactionId: "transaction-id",
			productId: "product-id",
			totalPrice: Money(value: -1.0, currency: "USD")
		)

		XCTAssertTrue(tracker.events.isEmpty)
		XCTAssertTrue(logger.entries.contains { $0.level == .warn && $0.message == "Negative revenue for product purchase" })
	}

	func testForwardInAppPurchaseRejectsInvalidProductRevenue() {
		let logger = MockLogger()
		let tracker = SpyInAppPurchaseEventTracker()
		let handler = InAppPurchaseHandler(sdk: tracker, logger: logger)

		handler.forwardInAppPurchase(
			transactionId: "transaction-id",
			productId: "product-id",
			totalPrice: Money(value: 1.0, currency: "usd")
		)

		XCTAssertTrue(tracker.events.isEmpty)
		XCTAssertTrue(logger.entries.contains { $0.level == .warn && $0.message.hasPrefix("Not publishing invalid product purchase") })
	}

	func testForwardInAppPurchaseDoesNotPublishWhenSdkIsReleased() {
		let logger = MockLogger()
		weak var tracker: SpyInAppPurchaseEventTracker?
		let handler = makeHandlerWithReleasedSdk(logger: logger, tracker: &tracker)

		handler.forwardInAppPurchase(
			transactionId: "transaction-id",
			productId: "product-id",
			totalPrice: Money(value: 1.0, currency: "USD")
		)

		XCTAssertNil(tracker)
	}

	func testForwardInAppPurchasePublishesSubscriptionPurchase() throws {
		let logger = MockLogger()
		let tracker = SpyInAppPurchaseEventTracker()
		let handler = InAppPurchaseHandler(sdk: tracker, logger: logger)

		handler.forwardInAppPurchase(
			transactionId: "transaction-id",
			subscriptionId: "subscription-id",
			totalPrice: Money(value: 23.45, currency: "EUR")
		)

		let baseEvent = try XCTUnwrap(tracker.events.first).build(sessionId: "sessionId")
		assertPurchaseEvent(
			baseEvent,
			productId: "subscription-id",
			productType: "subscription",
			token: "transaction-id",
			value: 23.45,
			currency: "EUR"
		)
	}

	func testForwardInAppPurchaseUsesEmptyTokenWhenSubscriptionTransactionIdAndReceiptAreMissing() throws {
		let logger = MockLogger()
		let tracker = SpyInAppPurchaseEventTracker()
		let handler = InAppPurchaseHandler(sdk: tracker, logger: logger)

		handler.forwardInAppPurchase(
			transactionId: nil,
			subscriptionId: "subscription-id",
			totalPrice: Money(value: 2.0, currency: "EUR")
		)

		let baseEvent = try XCTUnwrap(tracker.events.first).build(sessionId: "sessionId")
		assertPurchaseEvent(
			baseEvent,
			productId: "subscription-id",
			productType: "subscription",
			token: nil,
			value: 2.0,
			currency: "EUR"
		)
	}

	func testForwardInAppPurchaseRejectsNegativeSubscriptionRevenue() {
		let logger = MockLogger()
		let tracker = SpyInAppPurchaseEventTracker()
		let handler = InAppPurchaseHandler(sdk: tracker, logger: logger)

		handler.forwardInAppPurchase(
			transactionId: "transaction-id",
			subscriptionId: "subscription-id",
			totalPrice: Money(value: -1.0, currency: "EUR")
		)

		XCTAssertTrue(tracker.events.isEmpty)
		XCTAssertTrue(logger.entries.contains { $0.level == .warn && $0.message == "Negative revenue for subscription purchase" })
	}

	func testForwardInAppPurchaseRejectsInvalidSubscriptionRevenue() {
		let logger = MockLogger()
		let tracker = SpyInAppPurchaseEventTracker()
		let handler = InAppPurchaseHandler(sdk: tracker, logger: logger)

		handler.forwardInAppPurchase(
			transactionId: "transaction-id",
			subscriptionId: "subscription-id",
			totalPrice: Money(value: .infinity, currency: "EUR")
		)

		XCTAssertTrue(tracker.events.isEmpty)
		XCTAssertTrue(logger.entries.contains { $0.level == .warn && $0.message.hasPrefix("Not publishing invalid subscription purchase") })
	}

	func testForwardInAppPurchaseDoesNotPublishWhenSdkIsReleasedForSubscription() {
		let logger = MockLogger()
		weak var tracker: SpyInAppPurchaseEventTracker?
		let handler = makeHandlerWithReleasedSdk(logger: logger, tracker: &tracker)

		handler.forwardInAppPurchase(
			transactionId: "transaction-id",
			subscriptionId: "subscription-id",
			totalPrice: Money(value: 1.0, currency: "EUR")
		)

		XCTAssertNil(tracker)
	}

	private func awaitProduct(with productId: String) throws -> Product {
		let expectation = expectation(description: #function)
		var result: Result<Product, Error>?

		Task {
			do {
				guard let product = try await Product.products(for: [productId]).first else {
					throw InAppPurchaseHandlerTestError.missingProduct(productId)
				}
				result = .success(product)
			} catch {
				result = .failure(error)
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 10)
		return try XCTUnwrap(result).get()
	}

	private func waitForPurchaseEvent(in tracker: SpyInAppPurchaseEventTracker) throws -> AppEvent {
		let expectation = expectation(description: #function)
		var purchaseEvent: AppEvent?

		waitForEvent(
			matching: {
				purchaseEvent = tracker.events.first { $0.build(sessionId: "sessionId").name == JtPurchaseInternalEvent.name }
				return purchaseEvent != nil
			},
			expectation: expectation
		)

		waitForExpectations(timeout: 10)
		return try XCTUnwrap(purchaseEvent)
	}

	private func waitForLog(in logger: MockLogger, matching matcher: @escaping (MockLogger.Entry) -> Bool) throws {
		let expectation = expectation(description: #function)

		waitForEvent(
			matching: {
				logger.entries.contains(where: matcher)
			},
			expectation: expectation
		)

		waitForExpectations(timeout: 10)
	}

	private func assertPurchaseEvent(
		_ baseEvent: PublishableUserEvent,
		productId: String,
		productType: String,
		token: String?,
		value: Double,
		currency: String,
		file: StaticString = #filePath,
		line: UInt = #line
	) {
		XCTAssertEqual(baseEvent.name, JtPurchaseInternalEvent.name, file: file, line: line)
		XCTAssertEqual(baseEvent.dimensions[Dimension.jtAction.rawValue], "success", file: file, line: line)
		XCTAssertEqual(baseEvent.dimensions[Dimension.jtProductId.rawValue], productId, file: file, line: line)
		XCTAssertEqual(baseEvent.dimensions[Dimension.jtProductType.rawValue], productType, file: file, line: line)
		XCTAssertEqual(baseEvent.dimensions[Dimension.jtToken.rawValue], token, file: file, line: line)
		XCTAssertEqual(baseEvent.value, value, accuracy: 0.000001, file: file, line: line)
		XCTAssertEqual(baseEvent.currency, currency, file: file, line: line)
		XCTAssertNil(baseEvent.unit, file: file, line: line)
	}

	private func makeHandlerWithReleasedSdk(logger: Logger, tracker: inout SpyInAppPurchaseEventTracker?) -> InAppPurchaseHandler {
		let handler: InAppPurchaseHandler

		do {
			let strongTracker = SpyInAppPurchaseEventTracker()
			tracker = strongTracker
			handler = InAppPurchaseHandler(sdk: strongTracker, logger: logger)
		}

		return handler
	}

	private func waitForEvent(matching matcher: @escaping () -> Bool, expectation: XCTestExpectation) {
		if matcher() {
			expectation.fulfill()
			return
		}

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
			self.waitForEvent(matching: matcher, expectation: expectation)
		}
	}
}

private final class SpyInAppPurchaseEventTracker: MockJustTrackSdk {
	private(set) var events = [AppEvent]()

	override func track(event: AppEvent) -> Future<Void> {
		events.append(event)
		return FutureImpl<Void>().resolve(Void())
	}
}

private enum InAppPurchaseHandlerTestError: Error {
	case missingProduct(String)
}
