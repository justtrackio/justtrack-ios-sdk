@testable import JustTrackSDK

final class MockHttpLogger: HttpLogger {
	func breadcrumb(
		message: String,
		category: String,
		level: String,
		fields: [LoggerFields]
	) {
	}

	func debug(
		_ message: String,
		_ fields: [LoggerFields]
	) {
	}

	func error(
		_ message: String,
		_ exception: Error,
		_ fields: [LoggerFields]
	) {
	}

	func error(
		_ message: String,
		_ fields: [LoggerFields]
	) {
	}

	func getFallback() -> Logger {
		self
	}

	func info(
		_ message: String,
		_ fields: [LoggerFields]
	) {
	}

	func publishMetric(
		_ metric: Metric,
		_ value: Double,
		_ dimensions: [LoggerFields]
	) {
	}

	func sendToServer() {
	}

	func set(
		installId: StringID
	) {
	}

	func setRules(
		logConfig: AttributionOutputSdkConfig.Log?,
		metricConfig: AttributionOutputSdkConfig.Metric?
	) {
	}

	func warn(
		_ message: String,
		_ fields: [LoggerFields]
	) {
	}
}
