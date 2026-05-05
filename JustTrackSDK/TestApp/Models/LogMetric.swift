import JustTrackSDK
import SwiftUI

final class LogMetric: ObservableObject {
	@Published var metric: String = "Metric_1"
	@Published var value: Double = 0.1
	@Published var unit: Unit = .count
	@Published var dimensions: [String: String] = [:]
}

extension LogMetric {
	enum Unit: String, CaseIterable {
		case count
		case seconds
		case milliseconds
		case countAverage
		case countMaximum
		case countMinimum
		case secondsAverage
		case secondsMaximum
		case secondsMinimum
		case millisecondsAverage
		case millisecondsMaximum
		case millisecondsMinimum

		func getUnit() -> String {
			switch self {
			case .count:
				return "Count"
			case .seconds:
				return "Seconds"
			case .milliseconds:
				return "Milliseconds"
			case .countAverage:
				return "UnitCountAverage"
			case .countMaximum:
				return "UnitCountMaximum"
			case .countMinimum:
				return "UnitCountMinimum"
			case .secondsAverage:
				return "UnitSecondsAverage"
			case .secondsMaximum:
				return "UnitSecondsMaximum"
			case .secondsMinimum:
				return "UnitSecondsMinimum"
			case .millisecondsAverage:
				return "UnitMillisecondsAverage"
			case .millisecondsMaximum:
				return "UnitMillisecondsMaximum"
			case .millisecondsMinimum:
				return "UnitMillisecondsMinimum"
			}
		}
	}
}
