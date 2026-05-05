@testable import JustTrackSDK

final class MockUrlSession: UrlSession {
	enum Call {
		case dataTask(request: URLRequest, completionHandler: (Data?, URLResponse?, Error?) -> Void)
	}

	var calls = [Call]()

	var nextDataTask = MockUrlSessionDataTask()
	var nextData: Data?
	var nextError: Error?

	var dataTaskWithRequest = MockUrlSessionDataTask()

	func dataTask(
		with request: URLRequest,
		completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
	) -> UrlSessionDataTask {
		calls.append(.dataTask(request: request, completionHandler: completionHandler))
		return dataTaskWithRequest
	}
}

final class MockUrlSessionDataTask: UrlSessionDataTask {
	private(set) var resumeWasCalled = false

	func resume() {
		resumeWasCalled = true
	}
}

extension MockUrlSession.Call: Equatable {
	static func == (lhs: MockUrlSession.Call, rhs: MockUrlSession.Call) -> Bool {
		switch (lhs, rhs) {
		case let (.dataTask(lhsRequest, _), .dataTask(rhsRequest, _)):
			return lhsRequest == rhsRequest
		}
	}
}
