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

typealias LogErrorClassifier = AttributionErrorClassifier

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

protocol HttpClient {
	func execute(
		requestName: String,
		urlString: String,
		headers: [String: String],
		body: Data?,
		retries: Int,
		classifier: ErrorClassifier
	) -> Future<Data>

	func execute<T>(
		requestName: String,
		urlString: String,
		headers: [String: String],
		body: Data?,
		retries: Int,
		classifier: ErrorClassifier,
		transform: @escaping (Data, HTTPURLResponse) -> T
	) -> Future<T>

	func execute(
		requestName: String,
		urlString: String,
		headers: [String: String],
		body: Data,
		retryDelaySeconds: [TimeInterval],
		classifier: ErrorClassifier
	) -> Future<Data>
}

final class HttpClientImpl: HttpClient {
	private static let requestFailuresMetric = Metric(metric: "RequestFailures")

	let retryConfig: RetryConfig
	let logger: Logger
	private let urlSession: UrlSession
	private let isConsoleLoggingEnabled: Bool

	init(
		retryConfig: RetryConfig,
		urlSession: UrlSession,
		isConsoleLoggingEnabled: Bool = true
	) {
		self.retryConfig = retryConfig
		self.logger = isConsoleLoggingEnabled ? LoggerImpl() : IdleLogger()
		self.urlSession = urlSession
		self.isConsoleLoggingEnabled = isConsoleLoggingEnabled
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
			return " \(escapeUserAgentField(appName))/\(escapeUserAgentField(appVersion)) (\(platformType))"
		}()
		let cfNetworkVersion = HttpClientImpl.getCfNetworkVersion() ?? "unknown"
		let darwinVersion = DeviceInfo.getDarwinVersion()

		// be careful with the format - the backend parses this to extract some information
		return
			"JustTrackSDK/\(sdkVersion) (\(product); \(device); \(cpu) CPU; \(os) \(osVersion); \(locale); Build/\(buildName))\(appAndPlatform) CFNetwork/\(cfNetworkVersion) Darwin/\(darwinVersion)"
	}

	/// The set of characters left unescaped, chosen to match Android's `Uri.encode(value, " ")` byte
	/// for byte: alphanumerics plus `_-!.~'()*` from its fixed unreserved set, plus the space.
	///
	/// The set is built explicitly from ASCII characters rather than from something like
	/// `CharacterSet.alphanumerics`, which is unicode-aware and would treat CJK characters as
	/// alphanumeric and leave them unescaped.
	private static let userAgentFieldAllowedCharacters = CharacterSet(
		charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-!.~'()* "
	)

	/// Percent-escapes a single user agent field so the resulting header stays valid and parseable.
	///
	/// Escapes everything outside ``userAgentFieldAllowedCharacters``, which covers the cases that
	/// matter: bytes outside US-ASCII (header values must be ASCII), `%` so a single decode round trip
	/// is unambiguous, `;` which would add an extra attribute to the device block, and `/` which would
	/// split an app name into name and version.
	///
	/// The space is allowed through, so values that are already plain ASCII stay byte for byte
	/// identical and the header remains readable. Parentheses are also allowed through, matching
	/// Android; the backend handles parentheses inside a field.
	private static func escapeUserAgentField(_ value: String) -> String {
		return value.addingPercentEncoding(withAllowedCharacters: userAgentFieldAllowedCharacters) ?? value
	}

	private static func getCfNetworkVersion() -> String? {
		guard
			let bundle = Bundle(identifier: "com.apple.CFNetwork"),
			let versionAny = bundle.infoDictionary?[kCFBundleVersionKey as String],
			let version = versionAny as? String
		else { return nil }

		return version
	}

	// MARK: - HttpClient Protocol

	func execute(
		requestName: String,
		urlString: String,
		headers: [String: String],
		body: Data?,
		retries: Int,
		classifier: ErrorClassifier
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

	func execute<T>(
		requestName: String,
		urlString: String,
		headers: [String: String],
		body: Data?,
		retries: Int,
		classifier: ErrorClassifier,
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

	func execute(
		requestName: String,
		urlString: String,
		headers: [String: String],
		body: Data,
		retryDelaySeconds: [TimeInterval],
		classifier: ErrorClassifier
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

	private func executeAsyncRequest(requestName: String, urlString: String, headers: [String: String], body: Data?) -> Future<Data> {
		return executeAsyncRequest(requestName: requestName, urlString: urlString, headers: headers, body: body) { data, _ in data }
	}

	private func executeAsyncRequest<T>(
		requestName: String,
		urlString: String,
		headers: [String: String],
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
					self.logger.warn("HTTP request failed with network error", LoggerFieldsImpl().with("url", urlString).with("error", error))
					let dimensions = LoggerFieldsImpl()
						.with("Request", requestName)
						.with("Network", connectionType.stringValue)
						.with("Reason", "NetworkProblem")
					self.logger.publishMetric(HttpClientImpl.requestFailuresMetric, 1, dimensions)

					throw JustTrackErrorWrapper(NetworkError.networkError(error))
				}

				guard let httpResponse = response as? HTTPURLResponse else {
					self.logger.warn("HTTP request failed with bad response type", LoggerFieldsImpl().with("url", urlString))
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
					self.logger.warn(
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
					self.logger.warn("HTTP request failed with missing response data", LoggerFieldsImpl().with("url", urlString))
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
			logger.debug(log)
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
			logger.debug(log)
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
