import Foundation

protocol HttpLogger: Logger {
	func getFallback() -> Logger
	func set(installId: StringID)
	func sendToServer()
}

class HttpLoggerImpl: HttpLogger {
	var sdkIsRunning: () -> Bool = { true }

	private static let errorMetric = Metric(metric: "Errors")
	private static let warningMetric = Metric(metric: "Warnings")

	private let fallback: Logger
	private let logApi: LogApi
	private let logAggregator: LogAggregator
	private var installId: StringID
	private var sendLogsResults = [String: Future<Data>]()
	private let sendLogsResultsQueue = DispatchQueue(label: "io.justtrack.HttpLoggerImpl.sendLogsResultsQueue", qos: .userInitiated)
	private let adIdsProvider: () -> Future<AdIds>
	private let dateProvider: () -> Date
	private let appVersionProvider: () -> AppVersion
	private let sdkVersionProvider: () -> any Version

	init(
		fallback: Logger,
		logApi: LogApi,
		logAggregator: LogAggregator,
		installId: StringID,
		adIdsProvider: @escaping () -> Future<AdIds>,
		dateProvider: @escaping () -> Date = Date.init,
		appVersionProvider: @escaping () -> AppVersion = { readAppVersion() },
		sdkVersionProvider: @escaping () -> any Version = currentSdkVersion
	) {
		self.fallback = fallback
		self.logApi = logApi
		self.logAggregator = logAggregator
		self.installId = installId
		self.adIdsProvider = adIdsProvider
		self.dateProvider = dateProvider
		self.appVersionProvider = appVersionProvider
		self.sdkVersionProvider = sdkVersionProvider
	}

	func getFallback() -> Logger {
		return fallback
	}

	func set(installId: StringID) {
		self.installId = installId
	}

	func debug(_ message: String, _ fields: [LoggerFields]) {
		guard sdkIsRunning() else { return }

		fallback.debug(message, fields)

		// we don't send debug-level logs to the backend
	}

	func info(_ message: String, _ fields: [LoggerFields]) {
		guard sdkIsRunning() else { return }

		fallback.info(message, fields)
		writeLog("info", message, fields)
	}

	func warn(_ message: String, _ fields: [LoggerFields]) {
		guard sdkIsRunning() else { return }

		fallback.warn(message, fields)
		writeLog("warn", message, fields)
		publishMetric(HttpLoggerImpl.warningMetric, 1)
	}

	func error(_ message: String, _ fields: [LoggerFields]) {
		guard sdkIsRunning() else { return }

		fallback.error(message, fields)
		writeLog("error", message, fields)
		publishMetric(HttpLoggerImpl.errorMetric, 1)
	}

	func error(_ message: String, _ exception: Error, _ fields: [LoggerFields]) {
		guard sdkIsRunning() else { return }

		fallback.error(message, exception, fields)
		writeLog("error", message, fields, exception)
		publishMetric(HttpLoggerImpl.errorMetric, 1)
	}

	func publishMetric(_ metric: Metric, _ value: Double, _ dimensions: [LoggerFields]) {
		guard sdkIsRunning() else { return }

		fallback.publishMetric(metric, value, dimensions)
		writeMetric(metric, value, dimensions)
	}

	func sendToServer() {
		guard sdkIsRunning() else { return }

		logAggregator.sendLogsAndMetrics(self.performServerRequest)
	}

	private func writeLog(_ level: String, _ message: String, _ fields: [LoggerFields], _ exception: Error? = nil) {
		var encodedFields = [String: String]()

		for loggerFields in fields {
			addFields(loggerFields, &encodedFields)
		}

		if let exception {
			addFields(LoggerFieldsImpl().with("exception", exception), &encodedFields)
		}

		logAggregator.addLog(message: DTOLogMessage(level, message, encodedFields, dateProvider()))

		writeBreadcrumb(message: message, category: "logs", level: level)
	}

	private func writeMetric(_ metric: Metric, _ value: Double, _ dimensions: [LoggerFields]) {
		var encodedFields = [String: String]()
		addFields(metric, &encodedFields)
		for loggerFields in dimensions {
			addFields(loggerFields, &encodedFields)
		}

		logAggregator.addLog(metric: DTOLogMetric(metric.metric, encodedFields, value, metric.unit.getUnit(), dateProvider()))

		writeBreadcrumb(message: metric.metric, category: "metrics", level: "debug")
	}

	private func writeBreadcrumb(message: String, category: String, level: String) {
		logAggregator.addLog(
			breadcrumb: Breadcrumb(message: message, category: category, level: level, timestamp: dateProvider())
		)
	}

	private func performServerRequest(_ messages: [DTOLogMessage], _ metrics: [DTOLogMetric]) -> Future<Data> {
		if messages.isEmpty && metrics.isEmpty {
			return FutureImpl<Data>().resolve(Data())
		}

		let appVersion = appVersionProvider()
		let sdkVersion = sdkVersionProvider()
		let input = DTOLogInput(
			messages: messages,
			metrics: metrics,
			appVersion: DTOAppVersion(appVersion),
			sdkVersion: DTOSdkVersion(sdkVersion),
			clientDate: dateProvider()
		)

		let f = FutureImpl<Data>()

		adIdsProvider().observe { adIdsResult in
			switch adIdsResult {
			case let .failure(error):
				_ = f.fulfill(.failure(error))

			case let .success(adIds):
				let sendLogsResultId = StringID()
				let sendLogsResult = self.logApi.sendLogs(
					input: input,
					userData: UserData(
						idfa: adIds.idfa,
						userId: adIds.userId,
						installId: self.installId
					)
				)
				self.saveSendLogsResult(sendLogsResult, withId: sendLogsResultId)
				sendLogsResult.observe { result in
					switch result {
					case let .failure(error):
						_ = f.fulfill(.failure(error))
						self.fallback.warn("Failed to publish \(messages.count) log messages and \(metrics.count) metrics", LoggerFieldsImpl().with("exception", error))
					case let .success(data):
						_ = f.fulfill(.success(data))
						self.fallback.debug("Published \(messages.count) log messages and \(metrics.count) metrics")
					}
					self.removeSendLogsResult(withId: sendLogsResultId)
				}
			}
		}

		return f.toFuture()
	}

	private func saveSendLogsResult(_ result: Future<Data>, withId resultId: StringID) {
		sendLogsResultsQueue.async {
			self.sendLogsResults[resultId.value] = result
		}
	}

	private func removeSendLogsResult(withId resultId: StringID) {
		sendLogsResultsQueue.async {
			self.sendLogsResults[resultId.value] = nil
		}
	}

	private func addFields(_ fields: LoggerFields, _ encodedFields: inout [String: String]) {
		for field in fields.getFields() {
			encodedFields[field.key] = field.value
		}
	}
}
