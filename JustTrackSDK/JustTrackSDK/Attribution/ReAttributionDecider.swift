import Foundation

struct AttributionTimestamps {
	let firstAttributedAt: Date
	let lastAttributedAt: Date
	let lastOpenAt: Date
}

protocol ReAttributionDecider {
	func needsReAttribution(attributionTimestamps: AttributionTimestamps?) -> AttributionDecision
}

struct ChainedReAttributionDecider: ReAttributionDecider {
	private let deciders: [ReAttributionDecider]

	init(_ deciders: ReAttributionDecider...) {
		self.deciders = deciders
	}

	func needsReAttribution(attributionTimestamps: AttributionTimestamps?) -> AttributionDecision {
		var result = AttributionDecision.useStoredAttribution

		for decider in deciders {
			result = result.merge(decider.needsReAttribution(attributionTimestamps: attributionTimestamps))
		}

		return result
	}
}

struct ResolveOrganicAttributionDecider: ReAttributionDecider {
	private static let oldAttributionAge: TimeInterval = 15 * 60

	func needsReAttribution(attributionTimestamps: AttributionTimestamps?) -> AttributionDecision {
		guard let attributionTimestamps = attributionTimestamps else {
			return AttributionDecision.fetchFirstAttribution
		}

		let attributionAge = attributionTimestamps.lastAttributedAt.timeIntervalSince(attributionTimestamps.firstAttributedAt)

		// we need to attribute a user again (because a new postback could have arrived) should
		// the last attribution we have (if any) be not older than 15 minutes of the first attribution
		// we performed
		if attributionAge <= Self.oldAttributionAge {
			return AttributionDecision.fetchFirstAttribution
		} else {
			return AttributionDecision.useStoredAttribution
		}
	}
}

struct TimeBasedReAttributionDecider: ReAttributionDecider {
	private let inactivityTimeFrame: TimeInterval
	private let reAttributionTimeFrame: TimeInterval

	init(inactivityTimeFrameHours: Int, reAttributionTimeFrameDays: Int) {
		self.inactivityTimeFrame = 3600 * TimeInterval(inactivityTimeFrameHours)
		self.reAttributionTimeFrame = 3600 * 24 * TimeInterval(reAttributionTimeFrameDays)
	}

	func needsReAttribution(attributionTimestamps: AttributionTimestamps?) -> AttributionDecision {
		guard let attributionTimestamps = attributionTimestamps else {
			// user was never attributed before
			return AttributionDecision.fetchFirstAttribution
		}

		let now = Date()
		let attributeAfterAppOpen = attributionTimestamps.lastOpenAt + inactivityTimeFrame
		let attributeAfterAttribution = attributionTimestamps.lastAttributedAt + reAttributionTimeFrame

		if now >= attributeAfterAppOpen || now >= attributeAfterAttribution {
			return AttributionDecision.fetchRetargetingAttribution
		} else {
			return AttributionDecision.useStoredAttribution
		}
	}
}
