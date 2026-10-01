import XCTest

@testable import JustTrackSDK

final class ReAttributionDeciderTests: XCTestCase {
	// MARK: - ResolveOrganicAttributionDecider

	func testResolveOrganicReturnsFirstAttributionWhenNoTimestamps() {
		let decider = ResolveOrganicAttributionDecider()
		let decision = decider.needsReAttribution(attributionTimestamps: nil)
		XCTAssertTrue(decision.shouldFetchAttribution)
	}

	func testResolveOrganicReturnsFetchWhenAttributionAgeWithin15Minutes() {
		// lastAttributedAt is only 5 minutes after firstAttributedAt — within the 15-min window
		let first = Date(timeIntervalSinceNow: -600)
		let last = Date(timeIntervalSinceNow: -300)  // 5 min after first
		let timestamps = AttributionTimestamps(firstAttributedAt: first, lastAttributedAt: last, lastOpenAt: last)

		let decider = ResolveOrganicAttributionDecider()
		let decision = decider.needsReAttribution(attributionTimestamps: timestamps)

		XCTAssertTrue(decision.shouldFetchAttribution)
	}

	func testResolveOrganicReturnsUseStoredWhenAttributionAgeOver15Minutes() {
		// lastAttributedAt is 20 minutes after firstAttributedAt — outside the window
		let first = Date(timeIntervalSinceNow: -3600)
		let last = Date(timeIntervalSinceNow: -2400)  // 20 min after first
		let timestamps = AttributionTimestamps(firstAttributedAt: first, lastAttributedAt: last, lastOpenAt: last)

		let decider = ResolveOrganicAttributionDecider()
		let decision = decider.needsReAttribution(attributionTimestamps: timestamps)

		XCTAssertFalse(decision.shouldFetchAttribution)
	}

	func testResolveOrganicReturnsFetchWhenFirstAndLastAttributedAtAreEqual() {
		// Exactly 0 seconds apart — within the 15-min window
		let now = Date()
		let timestamps = AttributionTimestamps(firstAttributedAt: now, lastAttributedAt: now, lastOpenAt: now)

		let decider = ResolveOrganicAttributionDecider()
		let decision = decider.needsReAttribution(attributionTimestamps: timestamps)

		XCTAssertTrue(decision.shouldFetchAttribution)
	}

	// MARK: - TimeBasedReAttributionDecider

	func testTimeBasedReturnsFirstAttributionWhenNoTimestamps() {
		let decider = TimeBasedReAttributionDecider(inactivityTimeFrameHours: 24, reAttributionTimeFrameDays: 7)
		let decision = decider.needsReAttribution(attributionTimestamps: nil)
		XCTAssertTrue(decision.shouldFetchAttribution)
	}

	func testTimeBasedReturnsUseStoredWhenBothTimeFramesNotExceeded() {
		// lastOpenAt was 1 hour ago (inactivity = 24h) — not triggered
		// lastAttributedAt was 1 day ago (reAttribution = 7 days) — not triggered
		let lastOpen = Date(timeIntervalSinceNow: -3600)
		let lastAttributed = Date(timeIntervalSinceNow: -86400)
		let first = Date(timeIntervalSinceNow: -86400)
		let timestamps = AttributionTimestamps(
			firstAttributedAt: first,
			lastAttributedAt: lastAttributed,
			lastOpenAt: lastOpen
		)

		let decider = TimeBasedReAttributionDecider(inactivityTimeFrameHours: 24, reAttributionTimeFrameDays: 7)
		let decision = decider.needsReAttribution(attributionTimestamps: timestamps)

		XCTAssertFalse(decision.shouldFetchAttribution)
	}

	func testTimeBasedReturnsFetchWhenInactivityTimeFrameExceeded() {
		// lastOpenAt was 25 hours ago (inactivity = 24h) — triggered
		let lastOpen = Date(timeIntervalSinceNow: -(25 * 3600))
		let lastAttributed = Date(timeIntervalSinceNow: -3600)
		let first = Date(timeIntervalSinceNow: -3600)
		let timestamps = AttributionTimestamps(
			firstAttributedAt: first,
			lastAttributedAt: lastAttributed,
			lastOpenAt: lastOpen
		)

		let decider = TimeBasedReAttributionDecider(inactivityTimeFrameHours: 24, reAttributionTimeFrameDays: 7)
		let decision = decider.needsReAttribution(attributionTimestamps: timestamps)

		XCTAssertTrue(decision.shouldFetchAttribution)
		XCTAssertTrue(decision.isFetchRetargetingAttribution())
	}

	func testTimeBasedReturnsFetchWhenReAttributionTimeFrameExceeded() {
		// lastAttributedAt was 8 days ago (reAttribution = 7 days) — triggered
		let lastOpen = Date(timeIntervalSinceNow: -3600)
		let lastAttributed = Date(timeIntervalSinceNow: -(8 * 24 * 3600))
		let first = Date(timeIntervalSinceNow: -(8 * 24 * 3600))
		let timestamps = AttributionTimestamps(
			firstAttributedAt: first,
			lastAttributedAt: lastAttributed,
			lastOpenAt: lastOpen
		)

		let decider = TimeBasedReAttributionDecider(inactivityTimeFrameHours: 24, reAttributionTimeFrameDays: 7)
		let decision = decider.needsReAttribution(attributionTimestamps: timestamps)

		XCTAssertTrue(decision.shouldFetchAttribution)
		XCTAssertTrue(decision.isFetchRetargetingAttribution())
	}

	func testTimeBasedReturnsFetchWhenBothTimeFramesExceeded() {
		let lastOpen = Date(timeIntervalSinceNow: -(25 * 3600))
		let lastAttributed = Date(timeIntervalSinceNow: -(8 * 24 * 3600))
		let first = Date(timeIntervalSinceNow: -(8 * 24 * 3600))
		let timestamps = AttributionTimestamps(
			firstAttributedAt: first,
			lastAttributedAt: lastAttributed,
			lastOpenAt: lastOpen
		)

		let decider = TimeBasedReAttributionDecider(inactivityTimeFrameHours: 24, reAttributionTimeFrameDays: 7)
		let decision = decider.needsReAttribution(attributionTimestamps: timestamps)

		XCTAssertTrue(decision.shouldFetchAttribution)
	}

	// MARK: - ChainedReAttributionDecider

	func testChainedWithNoDecidersReturnsUseStored() {
		let chained = ChainedReAttributionDecider()
		let decision = chained.needsReAttribution(attributionTimestamps: nil)
		// With no deciders, result stays at the initial .useStoredAttribution
		XCTAssertFalse(decision.shouldFetchAttribution)
	}

	func testChainedPropagatesFirstAttributionWhenAnyDeciderRequiresIt() {
		// One decider returns useStored, another returns fetchFirst
		let alwaysFetch = AlwaysFetchDecider()
		let alwaysStore = AlwaysStoreDecider()
		let chained = ChainedReAttributionDecider(alwaysStore, alwaysFetch)

		let decision = chained.needsReAttribution(attributionTimestamps: nil)

		XCTAssertTrue(decision.shouldFetchAttribution)
	}

	func testChainedAllUseStoredReturnsUseStored() {
		let chained = ChainedReAttributionDecider(AlwaysStoreDecider(), AlwaysStoreDecider())
		let decision = chained.needsReAttribution(attributionTimestamps: nil)
		XCTAssertFalse(decision.shouldFetchAttribution)
	}

	func testChainedWithTimeBasedAndResolveOrganic() {
		// Organic decider: timestamps nil → fetchFirst
		// TimeBased: timestamps nil → fetchFirst
		// Combined: should fetch
		let organic = ResolveOrganicAttributionDecider()
		let timeBased = TimeBasedReAttributionDecider(inactivityTimeFrameHours: 24, reAttributionTimeFrameDays: 7)
		let chained = ChainedReAttributionDecider(organic, timeBased)

		let decision = chained.needsReAttribution(attributionTimestamps: nil)

		XCTAssertTrue(decision.shouldFetchAttribution)
	}
}

// MARK: - Helpers

private struct AlwaysFetchDecider: ReAttributionDecider {
	func needsReAttribution(attributionTimestamps: AttributionTimestamps?) -> AttributionDecision {
		.fetchFirstAttribution
	}
}

private struct AlwaysStoreDecider: ReAttributionDecider {
	func needsReAttribution(attributionTimestamps: AttributionTimestamps?) -> AttributionDecision {
		.useStoredAttribution
	}
}
