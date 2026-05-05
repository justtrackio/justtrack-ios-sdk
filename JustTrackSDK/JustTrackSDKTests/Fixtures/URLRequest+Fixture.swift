@testable import JustTrackSDK

extension URLRequest {
	static func fixture(
		httpMethod: String = "POST",
		url: String = "https://marketing-sandbox.info",
		httpHeaders: [String: String?] = [:],
		timeoutInterval: TimeInterval = 30,
		cachePolicy: CachePolicy = .useProtocolCachePolicy
	) -> URLRequest {
		var request = URLRequest(url: URL(string: url)!)
		request.httpMethod = httpMethod
		request.allHTTPHeaderFields = httpHeaders.compactMapValues { $0 }
		request.timeoutInterval = timeoutInterval
		request.cachePolicy = cachePolicy
		return request
	}

	func equals(
		_ other: URLRequest
	) -> Bool {
		httpMethod == other.httpMethod && url == other.url && allHTTPHeaderFields == other.allHTTPHeaderFields && timeoutInterval == other.timeoutInterval && cachePolicy == other.cachePolicy
	}

	func equals<B: Decodable & Equatable>(
		_ other: URLRequest,
		with body: B,
		prepareBodyData: (Data) -> Data = { $0 }
	) -> Bool {
		guard
			equals(other),
			let httpBody = httpBody,
			let decodedBody = try? JSONDecoder().decode(B.self, from: prepareBodyData(httpBody))
		else {
			return false
		}

		return decodedBody == body
	}
}
