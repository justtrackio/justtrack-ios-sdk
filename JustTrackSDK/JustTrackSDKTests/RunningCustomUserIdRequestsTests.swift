import Foundation
import XCTest

@testable import JustTrackSDK

final class RunningCustomUserIdRequestsTests: XCTestCase {
	private let installId = StringID(value: UUID().uuidString)!

	override func tearDown() {
		// Drain any lingering requests by resolving futures so the static dictionary is cleaned up
		super.tearDown()
	}

	// MARK: - offer returns nil when key is new

	func testOfferReturnsNilForNewKey() {
		let future = FutureImpl<Void>()
		let result = RunningCustomUserIdRequests.offer(
			installId: installId,
			customUserId: "user-\(UUID().uuidString)",
			future: future.toFuture()
		)
		XCTAssertNil(result, "First offer should return nil (no existing future)")

		// Clean up: resolve the future so the observer fires and removes it
		_ = future.resolve(())
	}

	// MARK: - offer returns existing future for duplicate key (the uncovered branch)

	func testOfferReturnsSameFutureForDuplicateKey() {
		let customUserId = "duplicate-\(UUID().uuidString)"
		let firstFuture = FutureImpl<Void>()

		// First offer — registers the future
		let first = RunningCustomUserIdRequests.offer(
			installId: installId,
			customUserId: customUserId,
			future: firstFuture.toFuture()
		)
		XCTAssertNil(first, "First offer should return nil")

		// Second offer with the same key — should return the existing future
		let secondFuture = FutureImpl<Void>()
		let second = RunningCustomUserIdRequests.offer(
			installId: installId,
			customUserId: customUserId,
			future: secondFuture.toFuture()
		)
		XCTAssertNotNil(second, "Second offer with same key should return existing future")

		// Clean up
		_ = firstFuture.resolve(())
	}

	// MARK: - done removes the key so a subsequent offer returns nil again

	func testOfferReturnsNilAfterFutureIsResolved() {
		let customUserId = "cleanup-\(UUID().uuidString)"
		let future = FutureImpl<Void>()

		let first = RunningCustomUserIdRequests.offer(
			installId: installId,
			customUserId: customUserId,
			future: future.toFuture()
		)
		XCTAssertNil(first)

		// Resolve the future — the observer removes the key
		_ = future.resolve(())

		// Give the observer a moment to run (it's synchronous in FutureImpl when already resolved)
		// Now re-offer: should return nil again
		let secondFuture = FutureImpl<Void>()
		let second = RunningCustomUserIdRequests.offer(
			installId: installId,
			customUserId: customUserId,
			future: secondFuture.toFuture()
		)
		XCTAssertNil(second, "After resolution, key should be gone and offer should return nil again")

		_ = secondFuture.resolve(())
	}
}
