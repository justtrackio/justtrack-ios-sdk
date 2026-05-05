import Foundation

extension [AttributionOutputSdkConfig.Rule] {
	func match(name: String, dimensions: [String: String]) -> MatchResult {
		for rule in self {
			guard name.matchesRegexPattern(pattern: rule.name) else { continue }

			var match = true

			for (key, value) in rule.dimensions {
				guard let dimension = dimensions[key], dimension.matchesRegexPattern(pattern: value) else {
					match = false
					break
				}
			}

			if match {
				return MatchResult(drop: rule.drop, matchedRule: true)
			}
		}

		return MatchResult(drop: false, matchedRule: false)
	}
}

struct MatchResult: Equatable {
	let drop: Bool
	let matchedRule: Bool
}
