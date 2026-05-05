@testable import JustTrackSDK

extension DTOLogMetric {
	static func fixture(
		metric: String = "metric_1",
		dimensions: [String: String] = [:],
		value: Double = 1,
		unit: MetricUnit = .count,
		timestamp: Date = Date(timeIntervalSince1970: 41)
	) -> DTOLogMetric {
		DTOLogMetric(
			metric,
			dimensions,
			value,
			unit.getUnit(),
			timestamp
		)
	}
}
