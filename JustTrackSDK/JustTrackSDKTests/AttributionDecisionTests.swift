import Foundation
import XCTest

@testable import JustTrackSDK

final class AttributionDecisionTests: XCTestCase {
	func testFetchFirstAttributionProperties() {
		let decision = AttributionDecision.fetchFirstAttribution
		XCTAssertTrue(decision.shouldFetchAttribution)
		XCTAssertFalse(decision.isFetchRetargetingAttribution())
		XCTAssertTrue(decision.isFastClaimsTimeout())
	}

	func testFetchRetargetingAttributionProperties() {
		let decision = AttributionDecision.fetchRetargetingAttribution
		XCTAssertTrue(decision.shouldFetchAttribution)
		XCTAssertTrue(decision.isFetchRetargetingAttribution())
		XCTAssertTrue(decision.isFastClaimsTimeout())
	}

	func testFetchRetargetingAttributionDelayedProperties() {
		let decision = AttributionDecision.fetchRetargetingAttributionDelayed
		XCTAssertTrue(decision.shouldFetchAttribution)
		XCTAssertFalse(decision.isFetchRetargetingAttribution())
		XCTAssertTrue(decision.isFastClaimsTimeout())
	}

	func testUseStoredAttributionProperties() {
		let decision = AttributionDecision.useStoredAttribution
		XCTAssertFalse(decision.shouldFetchAttribution)
		XCTAssertFalse(decision.isFetchRetargetingAttribution())
	}

	func testFetchAttributionAfterGettingIdfaProperties() {
		let decision = AttributionDecision.fetchAttributionAfterGettingIdfa
		XCTAssertTrue(decision.shouldFetchAttribution)
		XCTAssertFalse(decision.isFetchRetargetingAttribution())
	}

	func testWithSlowClaimsTimeout() {
		let decision = AttributionDecision.fetchFirstAttribution.withSlowClaimsTimeout()
		XCTAssertFalse(decision.isFastClaimsTimeout())
		XCTAssertEqual(decision.getClaimsTimeout(), ClaimsProviderImpl.claimTimeoutSlow)
		XCTAssertTrue(decision.shouldFetchAttribution)
	}

	func testGetClaimsTimeout() {
		let fast = AttributionDecision.fetchFirstAttribution
		XCTAssertEqual(fast.getClaimsTimeout(), ClaimsProviderImpl.claimTimeoutFast)

		let slow = fast.withSlowClaimsTimeout()
		XCTAssertEqual(slow.getClaimsTimeout(), ClaimsProviderImpl.claimTimeoutSlow)
	}

	func testMergeBothShouldFetch() {
		let a = AttributionDecision.fetchFirstAttribution
		let b = AttributionDecision.fetchRetargetingAttribution
		let merged = a.merge(b)
		XCTAssertTrue(merged.shouldFetchAttribution)
	}

	func testMergeFirstNotFetchSecondFetch() {
		let a = AttributionDecision.useStoredAttribution
		let b = AttributionDecision.fetchFirstAttribution
		let merged = a.merge(b)
		XCTAssertTrue(merged.shouldFetchAttribution)
	}

	func testMergeFirstFetchSecondNotFetch() {
		let a = AttributionDecision.fetchFirstAttribution
		let b = AttributionDecision.useStoredAttribution
		let merged = a.merge(b)
		XCTAssertTrue(merged.shouldFetchAttribution)
	}

	func testMergeNeitherFetch() {
		let a = AttributionDecision.useStoredAttribution
		let b = AttributionDecision.useStoredAttribution
		let merged = a.merge(b)
		XCTAssertFalse(merged.shouldFetchAttribution)
	}

	func testMergeSlowTimeoutWins() {
		let a = AttributionDecision.fetchFirstAttribution
		let b = AttributionDecision.fetchFirstAttribution.withSlowClaimsTimeout()
		let merged = a.merge(b)
		XCTAssertFalse(merged.isFastClaimsTimeout())
	}

	func testMergeTwoRetargeting() {
		let a = AttributionDecision.fetchRetargetingAttribution
		let b = AttributionDecision.fetchRetargetingAttribution
		let merged = a.merge(b)
		XCTAssertTrue(merged.isFetchRetargetingAttribution())
	}

	func testMergeRetargetingWithNonRetargeting() {
		let a = AttributionDecision.fetchRetargetingAttribution
		let b = AttributionDecision.fetchFirstAttribution
		let merged = a.merge(b)
		XCTAssertFalse(merged.isFetchRetargetingAttribution())
	}

	func testMergeRetargetingWithStoredFallsBackToOtherRetargeting() {
		let a = AttributionDecision.fetchRetargetingAttribution
		let b = AttributionDecision.useStoredAttribution
		let merged = a.merge(b)
		XCTAssertTrue(merged.shouldFetchAttribution)
		XCTAssertTrue(merged.isFetchRetargetingAttribution())
	}

	func testMergeNotFetchWithRetargetingUsesOtherRetargeting() {
		let a = AttributionDecision.useStoredAttribution
		let b = AttributionDecision.fetchRetargetingAttribution
		let merged = a.merge(b)
		XCTAssertTrue(merged.shouldFetchAttribution)
		XCTAssertTrue(merged.isFetchRetargetingAttribution())
	}

	func testMergeNotFetchWithNonRetargetingUsesOtherRetargeting() {
		let a = AttributionDecision.useStoredAttribution
		let b = AttributionDecision.fetchFirstAttribution
		let merged = a.merge(b)
		XCTAssertTrue(merged.shouldFetchAttribution)
		XCTAssertFalse(merged.isFetchRetargetingAttribution())
	}

	func testMergeNonRetargetingFetchWithRetargetingFetch() {
		let a = AttributionDecision.fetchFirstAttribution
		let b = AttributionDecision.fetchRetargetingAttribution
		let merged = a.merge(b)
		XCTAssertFalse(merged.isFetchRetargetingAttribution())
	}

	func testMergeRefreshWithRetargeting() {
		let a = AttributionDecision.fetchRetargetingAttributionDelayed
		let b = AttributionDecision.fetchRetargetingAttribution
		let merged = a.merge(b)
		XCTAssertTrue(merged.shouldFetchAttribution)
		XCTAssertTrue(merged.isFetchRetargetingAttribution())
	}
}
