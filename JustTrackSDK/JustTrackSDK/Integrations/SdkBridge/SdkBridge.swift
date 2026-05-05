#if DEBUG
	/// Bridge for SDK testing and debugging purposes.
	public struct SdkBridge {
		private weak var sdk: JustTrackSdkImpl?

		private let httpLogger: HttpLogger

		private let getAdIdsResult: FutureImpl<AdIds>

		init(
			sdk: JustTrackSdkImpl? = nil,
			httpLogger: HttpLogger,
			getAdIdsResult: FutureImpl<AdIds>
		) {
			self.sdk = sdk
			self.httpLogger = httpLogger
			self.getAdIdsResult = getAdIdsResult
		}

		/// Sends a log message through the HTTP logger.
		/// - Parameters:
		///   - level: The log level (debug, info, warn, error).
		///   - message: The log message.
		///   - fields: Additional fields to include with the log.
		public func sendLogMessage(
			level: String,
			message: String,
			fields: [String: String]
		) {
			switch level {
			case "debug":
				httpLogger.debug(message, LoggerFieldsImpl(fields: fields))
			case "info":
				httpLogger.info(message, LoggerFieldsImpl(fields: fields))
			case "warn":
				httpLogger.warn(message, LoggerFieldsImpl(fields: fields))
			case "error":
				httpLogger.error(message, LoggerFieldsImpl(fields: fields))
			default:
				fatalError("Unknown message level.")
			}
		}

		/// Sends a metric through the HTTP logger.
		/// - Parameters:
		///   - metric: The metric name.
		///   - value: The metric value.
		///   - unit: The unit of measurement.
		///   - dimensions: Additional dimensions for the metric.
		public func sendLogMetric(
			metric: String,
			value: Double,
			unit: String,
			dimensions: [String: String]
		) {
			httpLogger.publishMetric(
				Metric(
					metric: metric,
					unit: MetricUnit(rawValue: unit) ?? .count
				),
				value,
				LoggerFieldsImpl(fields: dimensions)
			)
		}

		/// Sends test internal events for manual testing purposes.
		public func sendInternalEvents() {
			let events = [
				JtAdInternalEvent(
					jtAction: "manual_testing_start",
					jtAdBundleId: "manual_testing_bundle_id_2",
					jtAdInstanceName: "manual_testing_instance_name_2",
					jtAdNetwork: "manual_testing_network_2",
					jtAdPlacement: "manual_testing_placement_2",
					jtAdSdk: "manual_testing_sdk_2",
					jtAdSegment: "manual_testing_segment_2",
					jtAdUnit: "manual_testing_banner",
					jtAdTestGroup: "manual_testing_test_group_2",
					revenue: Money(value: 41, currency: "USD"),
					happenedAt: Date()
				),
				JtPurchaseInternalEvent(
					jtAction: "manual_testing_purchase",
					jtProductId: "manual_testing_product_2",
					jtToken: "manual_testing_token_2",
					jtProductType: "manual_testing_purchase",
					revenue: Money(value: 10, currency: "EUR"),
					happenedAt: Date()
				),
				JtSessionTrackingEvent(
					sessionId: "manual_testing_session_1",
					jtAction: "manual_testing_end",
					duration: 10_000,
					unit: .milliseconds,
					happenedAt: Date()
				),
				JtAppOpenEvent(
					sessionId: "manual_testing_session_2",
					duration: 10,
					unit: .seconds,
					happenedAt: Date()
				),
				JtAppInstallEvent(
					sessionId: "manual_testing_session_2",
					duration: 5,
					unit: .seconds,
					happenedAt: Date()
				),
				JtDeeplinkHandledEvent(
					sessionId: "manual_testing_session_3",
					jtUrl: "https://google.com",
					happenedAt: Date()
				),
				JtDeeplinkNotHandledEvent(
					sessionId: "manual_testing_session_1",
					jtUrl: "https://www.swift.org",
					happenedAt: Date()
				),
				JtTrackingPermissionEvent(
					jtAction: "manual_testing_authorized",
					happenedAt: Date()
				),
			]

			for event in events {
				sdk?.track(event: event)
			}
		}

		/// Gets the user ID from the SDK.
		/// - Returns: A future that resolves to the user ID string.
		public func getUserId() -> Future<String> {
			let result = FutureImpl<String>()
			getAdIdsResult.toFuture().observe { adIdsResult in
				switch adIdsResult {
				case let .failure(error):
					result.reject(error)
				case let .success(adIds):
					result.resolve(adIds.userId.value)
				}
			}
			return result.toFuture()
		}

		/// Puts the SDK to sleep for testing purposes.
		/// - Parameter time: The sleep duration in seconds, or nil for default.
		public func sleep(
			for time: UInt32? = nil
		) {
			guard let time else {
				while true {}
				return
			}

			Darwin.sleep(time)
		}

		/// Performs an action on the SDK.
		/// - Parameter action: The action to perform.
		public func perform(
			action: @escaping () -> Void
		) {
			action()
		}
	}

	/// Global SDK bridge instance for testing purposes. Only available in DEBUG builds.
	public internal(set) var sdkBridge: SdkBridge?
#endif
