import Foundation

protocol LogApi {
	func sendLogs(input: DTOLogInput, userData: UserData) -> Future<Data>
}

final class LogApiImpl: LogApi {
	private static let sendLogsRequestName = "SendLogs"

	private let httpClient: HttpClient
	private let requestFactory: RequestFactory

	init(httpClient: HttpClient, requestFactory: RequestFactory) {
		self.httpClient = httpClient
		self.requestFactory = requestFactory
	}

	func sendLogs(input: DTOLogInput, userData: UserData) -> Future<Data> {
		do {
			let headers = requestFactory.getHeaders(userData: userData)
			let url = requestFactory.getUrl(route: .log, idfaProvided: userData.providesIdfa)
			return httpClient.execute(
				requestName: LogApiImpl.sendLogsRequestName,
				urlString: url,
				headers: headers,
				body: try input.json(),
				retries: 3,
				classifier: LogErrorClassifier()
			)
		} catch {
			return FutureImpl<Data>().reject(error)
		}
	}
}
