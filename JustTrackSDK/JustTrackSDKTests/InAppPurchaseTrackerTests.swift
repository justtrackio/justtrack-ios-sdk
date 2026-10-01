import Foundation
import XCTest

@testable import JustTrackSDK

final class InAppPurchaseTrackerTests: XCTestCase {
	// MARK: - init / convenience init

	func testConvenienceInitCreatesRealTracker() {
		let logger = MockLogger()
		let sut = InAppPurchaseTrackerImpl(logger: logger)
		// Sanity-check: object is constructed and conforms to the protocol.
		XCTAssertTrue((sut as Any) is InAppPurchaseTracker)
	}

	func testDesignatedInitDoesNotStartObserver() {
		let logger = MockLogger()
		let fake = FakeJTInAppPurchaseTracker()
		let sut = InAppPurchaseTrackerImpl(logger: logger, tracker: fake)
		XCTAssertFalse(fake.didAddObserver)
		_ = sut  // keep alive until end of scope
	}

	// MARK: - deinit

	func testDeinitRemovesTransactionObserver() {
		let logger = MockLogger()
		let fake = FakeJTInAppPurchaseTracker()
		do {
			_ = InAppPurchaseTrackerImpl(logger: logger, tracker: fake)
		}
		XCTAssertTrue(fake.didRemoveObserver)
	}

	// MARK: - start

	func testStartRegistersTransactionObserver() {
		let logger = MockLogger()
		let fake = FakeJTInAppPurchaseTracker()
		let sut = InAppPurchaseTrackerImpl(logger: logger, tracker: fake)
		let handler = makeHandler()

		sut.start(handler: handler)

		XCTAssertTrue(fake.didAddObserver)
		XCTAssertNotNil(fake.transactionHandler)
		XCTAssertNotNil(fake.missingProductHandler)
	}

	func testStartMissingProductHandlerLogsWarning() {
		let logger = MockLogger()
		let fake = FakeJTInAppPurchaseTracker()
		let sut = InAppPurchaseTrackerImpl(logger: logger, tracker: fake)
		sut.start(handler: makeHandler())

		fake.missingProductHandler?("com.example.missing")

		let entry = logger.entries.first { $0.level == .warn && $0.message == "Failed to find product" }
		XCTAssertNotNil(entry)
		XCTAssertEqual(entry?.fields.first?["productId"], "com.example.missing")
	}

	// MARK: - handle (via captured closure)

	func testHandleDoesNothingWhenDisabled() {
		let logger = MockLogger()
		let fake = FakeJTInAppPurchaseTracker()
		let spy = SpyTrackingSdk()
		let handler = InAppPurchaseHandler(sdk: spy, logger: logger)
		let sut = InAppPurchaseTrackerImpl(logger: logger, tracker: fake)
		sut.start(handler: handler)
		// enabled defaults to false

		fake.transactionHandler?("p1", "t1", 1, NSDecimalNumber(string: "9.99"), "USD", false)

		XCTAssertTrue(spy.events.isEmpty)
	}

	func testHandleForwardsProductPurchaseWhenEnabled() {
		let logger = MockLogger()
		let fake = FakeJTInAppPurchaseTracker()
		let spy = SpyTrackingSdk()
		let handler = InAppPurchaseHandler(sdk: spy, logger: logger)
		let sut = InAppPurchaseTrackerImpl(logger: logger, tracker: fake)
		sut.start(handler: handler)
		sut.set(enabled: true)

		fake.transactionHandler?("p1", "t1", 2, NSDecimalNumber(string: "1.50"), "EUR", false)

		let event = try? XCTUnwrap(spy.events.first).build(sessionId: "s")
		XCTAssertEqual(event?.name, JtPurchaseInternalEvent.name)
		XCTAssertEqual(event?.dimensions[Dimension.jtProductId.rawValue], "p1")
		XCTAssertEqual(event?.dimensions[Dimension.jtProductType.rawValue], "purchase")
		XCTAssertEqual(event?.dimensions[Dimension.jtToken.rawValue], "t1")
		XCTAssertEqual(event?.value ?? 0, 3.0, accuracy: 0.0001)
		XCTAssertEqual(event?.currency, "EUR")
	}

	func testHandleForwardsSubscriptionPurchaseWhenEnabled() {
		let logger = MockLogger()
		let fake = FakeJTInAppPurchaseTracker()
		let spy = SpyTrackingSdk()
		let handler = InAppPurchaseHandler(sdk: spy, logger: logger)
		let sut = InAppPurchaseTrackerImpl(logger: logger, tracker: fake)
		sut.start(handler: handler)
		sut.set(enabled: true)

		fake.transactionHandler?("sub1", "tx-sub", 1, NSDecimalNumber(string: "4.99"), "USD", true)

		let event = try? XCTUnwrap(spy.events.first).build(sessionId: "s")
		XCTAssertEqual(event?.name, JtPurchaseInternalEvent.name)
		XCTAssertEqual(event?.dimensions[Dimension.jtProductId.rawValue], "sub1")
		XCTAssertEqual(event?.dimensions[Dimension.jtProductType.rawValue], "subscription")
		XCTAssertEqual(event?.dimensions[Dimension.jtToken.rawValue], "tx-sub")
		XCTAssertEqual(event?.value ?? 0, 4.99, accuracy: 0.0001)
		XCTAssertEqual(event?.currency, "USD")
	}

	func testHandleHandlesNilTransactionIdAsProduct() {
		let logger = MockLogger()
		let fake = FakeJTInAppPurchaseTracker()
		let spy = SpyTrackingSdk()
		let handler = InAppPurchaseHandler(sdk: spy, logger: logger)
		let sut = InAppPurchaseTrackerImpl(logger: logger, tracker: fake)
		sut.start(handler: handler)
		sut.set(enabled: true)

		fake.transactionHandler?("p2", nil, 1, NSDecimalNumber(string: "0.99"), "USD", false)

		XCTAssertEqual(spy.events.count, 1)
	}

	func testHandleDoesNothingWhenHandlerReleased() {
		let logger = MockLogger()
		let fake = FakeJTInAppPurchaseTracker()
		let sut = InAppPurchaseTrackerImpl(logger: logger, tracker: fake)
		// Start with no handler (weak reference will be nil).
		sut.start(handler: nil)
		sut.set(enabled: true)

		// Should not crash; nothing to verify other than no exception.
		fake.transactionHandler?("p3", "t3", 1, NSDecimalNumber(string: "1.00"), "USD", false)
	}

	// MARK: - set(enabled:) toggling

	func testSetEnabledTogglesForwardingState() {
		let logger = MockLogger()
		let fake = FakeJTInAppPurchaseTracker()
		let spy = SpyTrackingSdk()
		let handler = InAppPurchaseHandler(sdk: spy, logger: logger)
		let sut = InAppPurchaseTrackerImpl(logger: logger, tracker: fake)
		sut.start(handler: handler)

		sut.set(enabled: true)
		fake.transactionHandler?("p1", "t1", 1, NSDecimalNumber(string: "1.00"), "USD", false)
		XCTAssertEqual(spy.events.count, 1)

		sut.set(enabled: false)
		fake.transactionHandler?("p1", "t1", 1, NSDecimalNumber(string: "1.00"), "USD", false)
		XCTAssertEqual(spy.events.count, 1, "Disabling should stop forwarding")
	}

	// MARK: - Helpers

	private func makeHandler() -> InAppPurchaseHandler {
		return InAppPurchaseHandler(sdk: SpyTrackingSdk(), logger: MockLogger())
	}
}

// MARK: - Test doubles

private final class FakeJTInAppPurchaseTracker: JTInAppPurchaseTracking {
	private(set) var didAddObserver = false
	private(set) var didRemoveObserver = false
	var transactionHandler: ((String, String?, Int, NSDecimalNumber, String, Bool) -> Void)?
	var missingProductHandler: ((String) -> Void)?

	func addTransactionObserver(
		_ transactionHandler: @escaping (String, String?, Int, NSDecimalNumber, String, Bool) -> Void,
		missingProductHandler: @escaping (String) -> Void
	) {
		self.didAddObserver = true
		self.transactionHandler = transactionHandler
		self.missingProductHandler = missingProductHandler
	}

	func removeTransactionObserver() {
		didRemoveObserver = true
		transactionHandler = nil
		missingProductHandler = nil
	}
}

private final class SpyTrackingSdk: MockJustTrackSdk {
	private(set) var events = [AppEvent]()

	override func track(event: AppEvent) -> Future<Void> {
		events.append(event)
		return FutureImpl<Void>().resolve(Void())
	}
}
