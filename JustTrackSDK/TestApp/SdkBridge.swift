#if !DEBUG
	struct SdkBridge {
		let sdkLowerLogPercentage: Double = -1

		func sendLogMessage(
			level: String,
			message: String,
			fields: [String: String]
		) {}

		func sendLogMetric(
			metric: String,
			value: Double,

			unit: String,
			dimensions: [String: String]
		) {}
	}

	var sdkBridge: SdkBridge? = SdkBridge()
#endif
