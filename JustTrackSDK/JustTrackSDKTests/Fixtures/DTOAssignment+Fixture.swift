@testable import JustTrackSDK

extension DTOAssignment {
	static func fixture(
		experiment: String = "Test Experiment",
		variant: String = "control",
		experimentId: String = "550e8430-e29b-41d4-a716-446655443000",
		variantId: String = "660e8430-e29b-41d4-a716-446655443000",
		configKey: String = "test_config_key",
		configValue: String = "test_value",
		pending: Bool? = true
	) -> DTOAssignment {
		DTOAssignment(
			experiment: experiment,
			variant: variant,
			experimentId: experimentId,
			variantId: variantId,
			configKey: configKey,
			configValue: configValue,
			pending: pending
		)
	}
}
