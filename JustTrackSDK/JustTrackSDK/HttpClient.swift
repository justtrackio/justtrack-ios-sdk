import Compression
import Foundation

enum NetworkError: Error, LocalizedError {
	case badUrl(String)
	case networkError(Error)
	case badResponseType(URLResponse?)
	case unexpectedResponse(Int, String?)
	case missingResponseData

	var errorDescription: String? {
		switch self {
		case let .badUrl(url):
			return "NetworkError.badUrl(\(url))"
		case let .networkError(error):
			return "NetworkError.networkError(\(error.justTrackGetErrorDescription()))"
		case let .badResponseType(response):
			return "NetworkError.badResponseType(\(response?.debugDescription ?? "nil response"))"
		case let .unexpectedResponse(statusCode, responseBody):
			if statusCode == 401 {
				return "NetworkError.unexpectedResponse(\(statusCode))\n\n\(formatInvalidToken(responseBody: responseBody))"
			}
			return "NetworkError.unexpectedResponse(\(statusCode))"
		case .missingResponseData:
			return "NetworkError.missingResponseData"
		}
	}

	func formatInvalidToken(responseBody: String?) -> String {
		var lines = [
			"Request could not be authenticated. Is the API token correct?",
			"See https://docs.justtrack.io/sdk/latest/overview/find-your-justtrack-token how to get an API token.",
			"",
		]

		if var responseBody = responseBody {
			if responseBody.count > 64 {
				responseBody = responseBody.prefix(64) + "..."
			}
			lines.append("Response Body: \(responseBody)")
		}

		return formatBoxed(lines: lines)
	}

	func formatBoxed(lines: [String]) -> String {
		var longest = 0
		for line in lines {
			longest = max(longest, line.count)
		}

		let stars = String(repeating: "*", count: longest + 4)
		var output = [stars]
		for line in lines {
			output.append("* \(line)\(String(repeating: " ", count: longest - line.count)) *")
		}
		output.append(stars)

		return output.joined(separator: "\n")
	}
}

enum ErrorClassification {
	case unrecoverable
	case recoverable(TimeInterval)
	case retryDefault
}

protocol ErrorClassifier {
	func classify(error: NetworkError) -> ErrorClassification?
}

struct CompositeErrorClassifier: ErrorClassifier {
	private let classifiers: [ErrorClassifier]
	private let defaultClassification: ErrorClassification

	init(classifiers: [ErrorClassifier], defaultClassification: ErrorClassification = .retryDefault) {
		self.classifiers = classifiers
		self.defaultClassification = defaultClassification
	}

	func classify(error: NetworkError) -> ErrorClassification? {
		for classifier in classifiers {
			if let classification = classifier.classify(error: error) {
				return classification
			}
		}
		return defaultClassification
	}
}

struct AttributionErrorClassifier: ErrorClassifier {
	func classify(error: NetworkError) -> ErrorClassification? {
		switch error {
		case let .unexpectedResponse(code, _):
			if code >= 400 && code < 500 {
				// something from our request was wrong, no point in retrying, the backend needs to be fixed
				return .unrecoverable
			}

			if code >= 500 {
				// the backend is having problems right now, so we wait up to 5 minutes before retrying.
				// while this is harsh, there is no point in bombarding the backend, most users will
				// have quit the app by then.
				let minutes = Double.random(in: 0...5)
				return .recoverable(minutes * 60)
			}

			return .retryDefault
		case .badUrl:
			return .unrecoverable
		case .missingResponseData:
			return .retryDefault
		case .badResponseType:
			return .retryDefault
		case .networkError:
			return .retryDefault
		}
	}
}

struct PaymentLimitErrorClassifier: ErrorClassifier {
	func classify(error: NetworkError) -> ErrorClassification? {
		switch error {
		case let .unexpectedResponse(code, _):
			if code == 402 {
				// Payment required - account limit reached, no point in retrying
				return .unrecoverable
			}
			return nil  // Let other classifiers handle this
		default:
			return nil  // Let other classifiers handle this
		}
	}
}

struct FetchClaimErrorClassifier: ErrorClassifier {
	func classify(error: NetworkError) -> ErrorClassification? {
		if Self.isUnreachableError(error) {
			// no need to retry requests for a protocol we don't support
			return .unrecoverable
		}

		return TrackingEventErrorClassifier().classify(error: error)
	}

	static func isUnreachableError(_ error: Error) -> Bool {
		var error = error
		if let wrappedError = error as? JustTrackErrorWrapper {
			error = wrappedError.error
		}
		guard let error = error as? NetworkError else {
			return false
		}
		switch error {
		case let .networkError(error):
			let error = error as NSError
			return error.domain == NSURLErrorDomain && error.code == NSURLErrorCannotFindHost
		default:
			return false
		}
	}

}

struct TrackingEventErrorClassifier: ErrorClassifier {
	func classify(error: NetworkError) -> ErrorClassification? {
		switch error {
		case .unexpectedResponse:
			// the backend seems to be having problems. Better not to overload it with too many requests,
			// we will retry later anyway
			return .unrecoverable
		case .badUrl:
			return .unrecoverable
		case .missingResponseData:
			return .retryDefault
		case .badResponseType:
			return .retryDefault
		case .networkError:
			return .retryDefault
		}
	}
}

struct UserData: Equatable {
	var providesIdfa: Bool {
		idfa != nil
	}

	let idfa: StringID?
	let userId: StringID
	let installId: StringID
}

struct AssignmentsResponse {
	let data: Data
	let retryAfterSeconds: Int?
}

struct GetAssignmentsParameters {
	let sdkVersion: any Version
	let appVersion: AppVersion
	let osVersion: String
	let deviceType: DeviceType
	let deviceModel: String
	let countryIso2: String?
	let deviceTimestamp: Int
	let attributionTimestamp: Int?
	let firstSdkInitTimestamp: Int?
	let installTimestamp: Int?
}

protocol HttpClient {
	func sendAnonymizeRequest(request: DTOAnonymizeRequest, userData: UserData) -> Future<Data>
	func sendAttributionRequest(request: DTOAttributionRequest, userData: UserData) -> Future<Data>
	func sendUserEvents(events: DTOUserEvent, userData: UserData) -> Future<Data>
	func sendCustomUserId(request: DTOPublishCustomUserIdRequest, userData: UserData) -> Future<Data>
	func sendFirebaseAppInstanceId(request: DTOPublishFirebaseAppInstanceIdRequest, userData: UserData) -> Future<Data>
	func sendLogs(input: DTOLogInput, userData: UserData) -> Future<Data>
	func getSignedIpClaim(ipProtocol: IPProtocol, userData: UserData) -> Future<Data>
	func sendSetExperimentVariant(request: DTOSetExperimentVariantRequest, userData: UserData) -> Future<Data>
	func setRules(eventConfig: AttributionOutputSdkConfig.Event)
	func getAssignments(parameters: GetAssignmentsParameters, userData: UserData) -> Future<AssignmentsResponse>
	func postEnrollments(request: DTOPostEnrollmentRequest, userData: UserData) -> Future<Data>
}

final class HttpClientImpl: HttpClient {
	private typealias Headers = [String: String]
	static let getAttributionRequestName = "GetAttribution"
	static let sendUserEventsRequestName = "SendUserEvents"
	static let sendCustomUserIdRequestName = "SendCustomUserId"
	static let sendFirebaseAppInstanceIdRequestName = "SendFirebaseAppInstanceId"
	static let sendLogsRequestName = "SendLogs"
	static let signIpv4RequestName = "SignIPv4"
	static let signIpv6RequestName = "SignIPv6"
	static let sendAnonymizeRequestName = "SendAnonymize"
	static let sendSetExperimentVariantRequestName = "SendSetExperimentVariant"
	static let getAssignmentsRequestName = "GetAssignments"
	static let postEnrollmentsRequestName = "PostEnrollments"
	private static let requestFailuresMetric = Metric(metric: "RequestFailures")

	private let environment: Environment
	private let platformType: PlatformType
	private let appName: String?
	private let appVersion: String
	private let apiToken: String
	private let retryConfig: RetryConfig
	private let logger: Logger
	private let urlSession: UrlSession
	private let clientId: String
	private let isConsoleLoggingEnabled: Bool
	private var eventConfig: AttributionOutputSdkConfig.Event?

	init(
		environment: Environment = Environment(),
		platformType: PlatformType,
		appName: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
		appVersion: String = readAppVersion().name,
		apiToken: String,
		retryConfig: RetryConfig,
		urlSession: UrlSession,
		clientId: String = Bundle.main.bundleIdentifier ?? "",
		isConsoleLoggingEnabled: Bool = true
	) {
		self.environment = environment
		self.platformType = platformType
		self.appName = appName
		self.appVersion = appVersion
		self.apiToken = apiToken
		self.retryConfig = retryConfig
		self.logger = isConsoleLoggingEnabled ? LoggerImpl() : IdleLogger()  // just log to console, we don't want to publish logs about HTTP requests with an HTTP request
		self.urlSession = urlSession
		self.clientId = clientId
		self.isConsoleLoggingEnabled = isConsoleLoggingEnabled
	}

	func sendAnonymizeRequest(request: DTOAnonymizeRequest, userData: UserData) -> Future<Data> {
		do {
			let headers = getHeadersV2(userData: userData)
			let url = environment.getUrl(route: .privacy, idfaProvided: userData.providesIdfa)
			return executeAsyncRequestWithRetry(
				retries: 3,
				logger: logger,
				requestName: HttpClientImpl.sendAnonymizeRequestName,
				classifier: AttributionErrorClassifier(),
				urlString: url,
				headers: headers,
				body: try request.json()
			)
		} catch {
			return FutureImpl<Data>().reject(error)
		}
	}

	func sendAttributionRequest(request: DTOAttributionRequest, userData: UserData) -> Future<Data> {
		do {
			let headers = getHeadersV2(userData: userData)
			let url = environment.getUrl(route: .attribution, idfaProvided: userData.providesIdfa)
			return executeAsyncRequestWithRetry(
				retries: retryConfig.attributionRequestRetries,
				logger: self.logger,
				requestName: HttpClientImpl.getAttributionRequestName,
				classifier: AttributionErrorClassifier(),
				urlString: url,
				headers: headers,
				body: try request.json()
			)
		} catch {
			return FutureImpl<Data>().reject(error)
		}
	}

	func sendUserEvents(events: DTOUserEvent, userData: UserData) -> Future<Data> {
		do {
			let filteredEvents = filterEventsIfNeeded(events.events)

			if filteredEvents.isEmpty {
				return FutureImpl<Data>().resolve(Data())
			}

			let appEvent = DTOUserEvent(
				appVersion: events.appVersion,
				sdkVersion: events.sdkVersion,
				user: events.user,
				device: events.device,
				events: filteredEvents
			)

			let headers = getHeadersV2(userData: userData)
			let url = environment.getUrl(route: .trackEvent, idfaProvided: userData.providesIdfa)
			let f = executeAsyncRequestWithRetry(
				retries: retryConfig.publishEventsRetries,
				logger: self.logger,
				requestName: HttpClientImpl.sendUserEventsRequestName,
				classifier: TrackingEventErrorClassifier(),
				urlString: url,
				headers: headers,
				body: try appEvent.json()
			)
			f.observe { result in
				switch result {
				case let .failure(error):
					for event in events.events {
						self.logger.error(
							"Event failed to publish",
							LoggerFieldsImpl()
								.with("id", event.id)
								.with("event", event.name)
								.with("error", error)
						)
					}
				case .success:
					break
				}
			}
			return f
		} catch {
			return FutureImpl<Data>().reject(error)
		}
	}

	private func filterEventsIfNeeded(_ events: [DTOUserEventEvent]) -> [DTOUserEventEvent] {
		guard let eventConfig else { return events }

		return events.filter { event in
			let drop = eventConfig.rules.match(name: event.name, dimensions: event.dimensions).drop

			if drop {
				logger.debug("Dropping event", LoggerFieldsImpl().with("id", event.id).with("event", event.name))
			}

			return !drop
		}
	}

	func sendCustomUserId(request: DTOPublishCustomUserIdRequest, userData: UserData) -> Future<Data> {
		do {
			let headers = getHeaders(userData: userData)
			let url = environment.getUrl(route: .publishCustomUserId, idfaProvided: userData.providesIdfa)
			return executeAsyncRequestWithRetry(
				retryDelaySeconds: [10, 20, 30],
				logger: self.logger,
				requestName: HttpClientImpl.sendCustomUserIdRequestName,
				classifier: AttributionErrorClassifier(),
				urlString: url,
				headers: headers,
				body: try request.json()
			)
		} catch {
			return FutureImpl<Data>().reject(error)
		}
	}

	func sendFirebaseAppInstanceId(request: DTOPublishFirebaseAppInstanceIdRequest, userData: UserData) -> Future<Data> {
		do {
			let headers = getHeaders(userData: userData)
			let url = environment.getUrl(route: .publishFirebaseAppInstanceId, idfaProvided: userData.providesIdfa)
			return executeAsyncRequestWithRetry(
				retryDelaySeconds: [10, 20, 30],
				logger: self.logger,
				requestName: HttpClientImpl.sendFirebaseAppInstanceIdRequestName,
				classifier: AttributionErrorClassifier(),
				urlString: url,
				headers: headers,
				body: try request.json()
			)
		} catch {
			return FutureImpl<Data>().reject(error)
		}
	}

	func sendLogs(input: DTOLogInput, userData: UserData) -> Future<Data> {
		do {
			let headers = getHeaders(userData: userData)
			let url = environment.getUrl(route: .log, idfaProvided: userData.providesIdfa)
			return executeAsyncRequestWithRetry(
				retries: 3,
				logger: self.logger,
				requestName: HttpClientImpl.sendLogsRequestName,
				classifier: AttributionErrorClassifier(),
				urlString: url,
				headers: headers,
				body: try input.json()
			)
		} catch {
			return FutureImpl<Data>().reject(error)
		}
	}

	func getSignedIpClaim(ipProtocol: IPProtocol, userData: UserData) -> Future<Data> {
		let headers = getHeaders(userData: userData)
		let url = environment.getUrl(route: ipProtocol.route, idfaProvided: userData.providesIdfa)
		return executeAsyncRequestWithRetry(
			retries: retryConfig.fetchClaimRetries,
			logger: self.logger,
			requestName: ipProtocol.requestName,
			classifier: FetchClaimErrorClassifier(),
			urlString: url,
			headers: headers,
			body: nil
		)
	}

	func sendSetExperimentVariant(request: DTOSetExperimentVariantRequest, userData: UserData) -> Future<Data> {
		do {
			let headers = getHeadersV2(userData: userData)
			let url = environment.getUrl(route: .testAssignment, idfaProvided: userData.providesIdfa)
			let classifier = CompositeErrorClassifier(
				classifiers: [
					PaymentLimitErrorClassifier(),
					AttributionErrorClassifier(),
				]
			)
			return executeAsyncRequestWithRetry(
				retries: 3,
				logger: self.logger,
				requestName: HttpClientImpl.sendSetExperimentVariantRequestName,
				classifier: classifier,
				urlString: url,
				headers: headers,
				body: try request.json()
			)
		} catch {
			return FutureImpl<Data>().reject(error)
		}
	}

	func setRules(eventConfig: AttributionOutputSdkConfig.Event) {
		self.eventConfig = eventConfig
	}

	func getAssignments(parameters: GetAssignmentsParameters, userData: UserData) -> Future<AssignmentsResponse> {
		let headers = getHeadersV2(userData: userData)
		let baseUrl = environment.getUrl(route: .assignments, idfaProvided: userData.providesIdfa)

		guard var components = URLComponents(string: baseUrl) else {
			return FutureImpl<AssignmentsResponse>().reject(JustTrackErrorWrapper(NetworkError.badUrl(baseUrl)))
		}

		var queryItems = [
			URLQueryItem(name: "installInstanceId", value: userData.installId.value),
			URLQueryItem(name: "deviceTimestamp", value: String(parameters.deviceTimestamp)),
			URLQueryItem(name: "osVersion", value: parameters.osVersion),
			URLQueryItem(name: "deviceType", value: parameters.deviceType.stringValue),
			URLQueryItem(name: "deviceModel", value: parameters.deviceModel),
			URLQueryItem(name: "appVersionCode", value: parameters.appVersion.code),
			URLQueryItem(name: "appVersionName", value: parameters.appVersion.name),
			URLQueryItem(name: "sdkVersionMajor", value: String(parameters.sdkVersion.major)),
			URLQueryItem(name: "sdkVersionMinor", value: String(parameters.sdkVersion.minor)),
			URLQueryItem(name: "sdkVersionPatch", value: String(parameters.sdkVersion.patch)),
			URLQueryItem(name: "sdkVersionName", value: parameters.sdkVersion.name),
			URLQueryItem(name: "sdkVersionPlatform", value: "ios"),
		]

		if let countryIso2 = parameters.countryIso2 {
			queryItems += [
				URLQueryItem(name: "countryIso2", value: countryIso2)
			]
		}

		if let attributionTimestamp = parameters.attributionTimestamp {
			queryItems += [
				URLQueryItem(name: "attributionTimestamp", value: String(attributionTimestamp))
			]
		}

		if let firstSdkInitTimestamp = parameters.firstSdkInitTimestamp {
			queryItems += [
				URLQueryItem(name: "firstSdkInitTimestamp", value: String(firstSdkInitTimestamp))
			]
		}

		if let installTimestamp = parameters.installTimestamp {
			queryItems += [
				URLQueryItem(name: "installTimestamp", value: String(installTimestamp))
			]
		}

		components.queryItems = queryItems

		guard let urlString = components.string else {
			return FutureImpl<AssignmentsResponse>().reject(JustTrackErrorWrapper(NetworkError.badUrl(baseUrl)))
		}

		let classifier = CompositeErrorClassifier(
			classifiers: [
				PaymentLimitErrorClassifier(),
				AttributionErrorClassifier(),
			]
		)

		return executeAsyncRequestWithRetry(
			retries: 3,
			logger: self.logger,
			requestName: HttpClientImpl.getAssignmentsRequestName,
			classifier: classifier,
			urlString: urlString,
			headers: headers,
			body: nil
		) { data, httpResponse in
			var retryAfterSeconds: Int?
			if let retryAfterValue = httpResponse.allHeaderFields["Retry-After"] as? String {
				retryAfterSeconds = Int(retryAfterValue)
			}
			return AssignmentsResponse(data: data, retryAfterSeconds: retryAfterSeconds)
		}
	}

	func postEnrollments(request: DTOPostEnrollmentRequest, userData: UserData) -> Future<Data> {
		do {
			let headers = getHeadersV2(userData: userData)
			let url = environment.getUrl(route: .assignments, idfaProvided: userData.providesIdfa)
			let classifier = CompositeErrorClassifier(
				classifiers: [
					PaymentLimitErrorClassifier(),
					AttributionErrorClassifier(),
				]
			)
			return executeAsyncRequestWithRetry(
				retries: 3,
				logger: self.logger,
				requestName: HttpClientImpl.postEnrollmentsRequestName,
				classifier: classifier,
				urlString: url,
				headers: headers,
				body: try request.json()
			)
		} catch {
			return FutureImpl<Data>().reject(error)
		}
	}

	private func getHeaders(userData: UserData) -> Headers {
		var headers = Headers()
		headers["X-CLIENT-ID"] = clientId
		headers["X-CLIENT-TOKEN"] = apiToken
		headers["X-ADVERTISER-ID"] = userData.idfa?.value ?? "missing"
		headers["X-USER-ID"] = userData.userId.value
		headers["X-INSTALL-ID"] = userData.installId.value

		// no need to set accept-encoding as the client we are using is already supporting that
		headers["Content-Type"] = "application/json; charset=utf-8"
		headers["User-Agent"] = HttpClientImpl.getUserAgent(platformType: platformType, appName: appName, appVersion: appVersion)

		return headers
	}

	private func getHeadersV2(userData: UserData) -> Headers {
		var headers = Headers()
		headers["X-APP-BUNDLE-ID"] = clientId
		headers["X-APP-TOKEN"] = apiToken
		headers["X-ADVERTISER-ID"] = userData.idfa?.value ?? "missing"
		headers["X-USER-ID"] = userData.userId.value
		headers["X-INSTALL-ID"] = userData.installId.value

		// no need to set accept-encoding as the client we are using is already supporting that
		headers["Content-Type"] = "application/json; charset=utf-8"
		headers["User-Agent"] = HttpClientImpl.getUserAgent(platformType: platformType, appName: appName, appVersion: appVersion)

		return headers
	}

	static func getUserAgent(
		platformType: PlatformType,
		appName: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
		appVersion: String = readAppVersion().name
	) -> String {
		let sdkVersion = currentSdkVersion().name
		let device = DeviceInfo.getDevice()
		let product = DeviceInfo.getProduct()
		let cpu = DeviceInfo.getMachine()
		let os = DeviceInfo.getSystemName()
		let osVersion = DeviceInfo.getSystemVersion().replacingOccurrences(of: ".", with: "_")
		let buildName = DeviceInfo.getBuild()
		let locale = getCurrentLocale()
		let appAndPlatform: String = {
			guard let appName else { return "" }
			return " \(appName)/\(appVersion) (\(platformType))"
		}()
		let cfNetworkVersion = HttpClientImpl.getCfNetworkVersion() ?? "unknown"
		let darwinVersion = DeviceInfo.getDarwinVersion()

		// be careful with the format - the backend parses this to extract some information
		return
			"JustTrackSDK/\(sdkVersion) (\(product); \(device); \(cpu) CPU; \(os) \(osVersion); \(locale); Build/\(buildName))\(appAndPlatform) CFNetwork/\(cfNetworkVersion) Darwin/\(darwinVersion)"
	}

	private static func getCfNetworkVersion() -> String? {
		guard
			let bundle = Bundle(identifier: "com.apple.CFNetwork"),
			let versionAny = bundle.infoDictionary?[kCFBundleVersionKey as String],
			let version = versionAny as? String
		else { return nil }

		return version
	}

	private func executeAsyncRequestWithRetry(
		retries: Int,
		logger: Logger,
		requestName: String,
		classifier: ErrorClassifier,
		urlString: String,
		headers: Headers,
		body: Data?
	) -> Future<Data> {
		return RetryingFuture(
			retries: retries,
			logger: logger,
			requestName: requestName,
			classifier: classifier,
			for: {
				self.logger.debug("Starting new HTTP request", LoggerFieldsImpl().with("url", urlString))

				return self.executeAsyncRequest(requestName: requestName, urlString: urlString, headers: headers, body: body)
			}
		).toFuture()
	}

	private func executeAsyncRequestWithRetry<T>(
		retries: Int,
		logger: Logger,
		requestName: String,
		classifier: ErrorClassifier,
		urlString: String,
		headers: Headers,
		body: Data?,
		transform: @escaping (Data, HTTPURLResponse) -> T
	) -> Future<T> {
		return RetryingFuture(
			retries: retries,
			logger: logger,
			requestName: requestName,
			classifier: classifier,
			for: {
				self.logger.debug("Starting new HTTP request", LoggerFieldsImpl().with("url", urlString))

				return self.executeAsyncRequest(requestName: requestName, urlString: urlString, headers: headers, body: body, transform: transform)
			}
		).toFuture()
	}

	private func executeAsyncRequestWithRetry(
		retryDelaySeconds: [TimeInterval],
		logger: Logger,
		requestName: String,
		classifier: ErrorClassifier,
		urlString: String,
		headers: Headers,
		body: Data
	) -> Future<Data> {
		return RetryingFuture(
			retryDelaySeconds: retryDelaySeconds,
			logger: logger,
			requestName: requestName,
			classifier: classifier,
			for: {
				self.logger.debug("Starting new HTTP request", LoggerFieldsImpl().with("url", urlString))

				return self.executeAsyncRequest(requestName: requestName, urlString: urlString, headers: headers, body: body)
			}
		).toFuture()
	}

	private func executeAsyncRequest(requestName: String, urlString: String, headers: Headers, body: Data?) -> Future<Data> {
		return executeAsyncRequest(requestName: requestName, urlString: urlString, headers: headers, body: body) { data, _ in data }
	}

	private func executeAsyncRequest<T>(
		requestName: String,
		urlString: String,
		headers: Headers,
		body: Data?,
		transform: @escaping (Data, HTTPURLResponse) -> T
	) -> Future<T> {
		var result = FutureImpl<T>()
		guard let url = URL(string: urlString) else {
			return result.reject(JustTrackErrorWrapper(NetworkError.badUrl(urlString)))
		}

		var request = URLRequest(url: url)
		request.timeoutInterval = 30.0
		for header in headers {
			request.setValue(header.value, forHTTPHeaderField: header.key)
		}
		if let body {
			request.httpMethod = "POST"
			if let compressedBody = body.gziped() {
				request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
				request.httpBody = compressedBody
			} else {
				request.httpBody = body
			}
		} else {
			request.httpMethod = "GET"
		}

		#if DEBUG
			self.log(request: request, originalBody: body)
		#endif

		let connectionType = getNetworkType()
		let task = urlSession.dataTask(with: request) { (data, response, error) in
			#if DEBUG
				self.log(response: response, data: data, error: error)
			#endif
			result = result.fulfillWith({
				if let error {
					self.logger.error("HTTP request failed with network error", LoggerFieldsImpl().with("url", urlString).with("error", error))
					let dimensions = LoggerFieldsImpl()
						.with("Request", requestName)
						.with("Network", connectionType.stringValue)
						.with("Reason", "NetworkProblem")
					self.logger.publishMetric(HttpClientImpl.requestFailuresMetric, 1, dimensions)

					throw JustTrackErrorWrapper(NetworkError.networkError(error))
				}

				guard let httpResponse = response as? HTTPURLResponse else {
					self.logger.error("HTTP request failed with bad response type", LoggerFieldsImpl().with("url", urlString))
					let dimensions = LoggerFieldsImpl()
						.with("Request", requestName)
						.with("Network", connectionType.stringValue)
						.with("Reason", "BadResponse")
					self.logger.publishMetric(HttpClientImpl.requestFailuresMetric, 1, dimensions)

					throw JustTrackErrorWrapper(NetworkError.badResponseType(response))
				}

				if !(200...299).contains(httpResponse.statusCode) {
					var responseBody: String?
					if let data {
						responseBody = String(data: data, encoding: .utf8)
					}
					self.logger.error(
						"HTTP request failed with bad status code",
						LoggerFieldsImpl()
							.with("url", urlString)
							.with("code", httpResponse.statusCode)
					)
					let dimensions = LoggerFieldsImpl()
						.with("Request", requestName)
						.with("Network", connectionType.stringValue)
						.with("Reason", "BadResponse")
					self.logger.publishMetric(HttpClientImpl.requestFailuresMetric, 1, dimensions)

					throw JustTrackErrorWrapper(
						NetworkError.unexpectedResponse(
							httpResponse.statusCode,
							responseBody
						)
					)
				}

				guard let data = data else {
					self.logger.error("HTTP request failed with missing response data", LoggerFieldsImpl().with("url", urlString))
					let dimensions = LoggerFieldsImpl()
						.with("Request", requestName)
						.with("Network", connectionType.stringValue)
						.with("Reason", "BadResponse")
					self.logger.publishMetric(HttpClientImpl.requestFailuresMetric, 1, dimensions)

					throw JustTrackErrorWrapper(NetworkError.missingResponseData)
				}

				self.logger.debug("HTTP request succeeded", LoggerFieldsImpl().with("url", urlString))

				return transform(data, httpResponse)
			})
		}

		task.resume()

		return result.toFuture()
	}

	#if DEBUG
		private func log(request: URLRequest, originalBody: Data?) {
			guard isConsoleLoggingEnabled else { return }

			var log = "\n📤 HTTP REQUEST"
			log += "\n────────────────────────────────────────"
			log += "\n\(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "unknown")"

			if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
				log += "\n\nHeaders:"
				for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
					log += "\n  \(key): \(value)"
				}
			}

			if let body = originalBody {
				log += "\n\nBody:"
				log += "\n\(prettyPrintJSON(body))"
			}

			log += "\n────────────────────────────────────────"
			print(log)
		}

		private func log(response: URLResponse?, data: Data?, error: Error?) {
			guard isConsoleLoggingEnabled else { return }

			var log = "\n📥 HTTP RESPONSE"
			log += "\n────────────────────────────────────────"

			if let error {
				log += "\nError: \(error.localizedDescription)"
			}

			if let httpResponse = response as? HTTPURLResponse {
				log += "\nStatus: \(httpResponse.statusCode)"
				log += "\nURL: \(httpResponse.url?.absoluteString ?? "unknown")"

				if !httpResponse.allHeaderFields.isEmpty {
					log += "\n\nHeaders:"
					for (key, value) in httpResponse.allHeaderFields.sorted(by: { "\($0.key)" < "\($1.key)" }) {
						log += "\n  \(key): \(value)"
					}
				}
			}

			if let data {
				log += "\n\nBody:"
				log += "\n\(prettyPrintJSON(data))"
			}

			log += "\n────────────────────────────────────────"
			print(log)
		}

		private func prettyPrintJSON(_ data: Data) -> String {
			if let json = try? JSONSerialization.jsonObject(with: data, options: []),
				let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
				let prettyString = String(data: prettyData, encoding: .utf8)
			{
				return prettyString
			}
			return String(data: data, encoding: .utf8) ?? "<binary data>"
		}
	#endif
}
