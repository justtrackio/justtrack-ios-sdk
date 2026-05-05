protocol UrlSessionDataTask {
	func resume()
}

extension URLSessionDataTask: UrlSessionDataTask {
}

protocol UrlSession {
	func dataTask(
		with request: URLRequest,
		completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
	) -> UrlSessionDataTask
}

extension URLSession: UrlSession {
	func dataTask(
		with request: URLRequest,
		completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
	) -> UrlSessionDataTask {
		(dataTask(with: request, completionHandler: completionHandler) as URLSessionDataTask) as UrlSessionDataTask
	}
}
