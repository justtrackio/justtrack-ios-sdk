import Foundation
import XCTest

@testable import JustTrackSDK

final class SubscriptionManagerTests: XCTestCase {
	func testSubscribeSimple() {
		var lastValue: Int = 0
		let manager: SubscriptionManager<Int> = SubscriptionManager()
		let expectation = self.expectation(description: #function)
		let subscription = manager.subscribe(listener: {
			lastValue = $0
			expectation.fulfill()
		})
		manager.call(value: 1)
		waitForExpectations(timeout: 10)
		XCTAssertEqual(lastValue, 1)
		subscription.unsubscribe()
		let nextExpectation = self.expectation(description: #function)
		manager.call(value: 2)
		DispatchQueue.main.async {
			nextExpectation.fulfill()
		}
		waitForExpectations(timeout: 10)
		XCTAssertEqual(lastValue, 1)
	}

	func testSubscriptionMany() {
		var values: [Int] = [0, 0, 0, 0, 0]
		let manager: SubscriptionManager<Int> = SubscriptionManager()
		let expectation = self.expectation(description: #function)
		_ = manager.subscribe(listener: {
			values[0] = $0
		})
		_ = manager.subscribe(listener: {
			values[1] = $0 + 1
		})
		_ = manager.subscribe(listener: {
			values[2] = $0 + 2
		})
		_ = manager.subscribe(listener: {
			values[3] = $0 + 3
		})
		_ = manager.subscribe(listener: {
			values[4] = $0 + 4
			expectation.fulfill()
		})
		manager.call(value: 10)
		waitForExpectations(timeout: 10)
		XCTAssertEqual(values, [10, 11, 12, 13, 14])
	}
}
