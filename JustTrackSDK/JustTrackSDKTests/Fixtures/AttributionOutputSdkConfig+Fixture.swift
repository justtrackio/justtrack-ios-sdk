@testable import JustTrackSDK

extension AttributionOutputSdkConfig {
	static func fixture(
		log: AttributionOutputSdkConfig.Log = .fixture(),
		metric: AttributionOutputSdkConfig.Metric = .fixture(),
		event: AttributionOutputSdkConfig.Event = .fixture()
	) -> AttributionOutputSdkConfig {
		AttributionOutputSdkConfig(
			log: log,
			metric: metric,
			event: event
		)
	}
}

extension AttributionOutputSdkConfig.Log {
	static func fixture(
		rules: [AttributionOutputSdkConfig.Rule] = [
			AttributionOutputSdkConfig.Rule(
				name: "attribution_rule_1",
				drop: true,
				dimensions: [
					"dimension_1": "^.*$"
				]
			),
			AttributionOutputSdkConfig.Rule(
				name: "attribution_rule_2",
				drop: false,
				dimensions: [
					"dimension_1": "value_1",
					"dimension_2": "value_2",
				]
			),
		]
	) -> AttributionOutputSdkConfig.Log {
		AttributionOutputSdkConfig.Log(rules: rules)
	}
}

extension AttributionOutputSdkConfig.Metric {
	static func fixture(
		rules: [AttributionOutputSdkConfig.Rule] = [
			AttributionOutputSdkConfig.Rule(
				name: "attribution_rule_3",
				drop: false,
				dimensions: [
					"dimension_1": "^.*$"
				]
			),
			AttributionOutputSdkConfig.Rule(
				name: "attribution_rule_5",
				drop: true,
				dimensions: [
					"dimension_1": "value_1",
					"dimension_2": "value_2",
				]
			),
		]
	) -> AttributionOutputSdkConfig.Metric {
		AttributionOutputSdkConfig.Metric(rules: rules)
	}
}

extension AttributionOutputSdkConfig.Event {
	static func fixture(
		rules: [AttributionOutputSdkConfig.Rule] = [
			AttributionOutputSdkConfig.Rule(
				name: "attribution_rule_6",
				drop: true,
				dimensions: [
					"dimension_1": "^.*$",
					"dimension_2": "value_2",
				]
			),
			AttributionOutputSdkConfig.Rule(
				name: "attribution_rule_6",
				drop: false,
				dimensions: [
					"dimension_2": "value_2"
				]
			),
		]
	) -> AttributionOutputSdkConfig.Event {
		AttributionOutputSdkConfig.Event(rules: rules)
	}
}
