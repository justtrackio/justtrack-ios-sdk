import Foundation

protocol EventApi {
	func sendUserEvents(events: DTOUserEvent, userData: UserData) -> Future<Data>
}

final class EventApiImpl: EventApi {
	private static let sendUserEventsRequestName = "SendUserEvents"

	private let httpClient: HttpClient
	private let requestFactory: RequestFactory
	private let retryConfig: RetryConfig
	private let logger: Logger

	init(httpClient: HttpClient, requestFactory: RequestFactory, retryConfig: RetryConfig, logger: Logger) {
		self.httpClient = httpClient
		self.requestFactory = requestFactory
		self.retryConfig = retryConfig
		self.logger = logger
	}

	func sendUserEvents(events: DTOUserEvent, userData: UserData) -> Future<Data> {
		do {
			let headers = requestFactory.getHeadersV2(userData: userData)
			let url = requestFactory.getUrl(route: .trackEvent, idfaProvided: userData.providesIdfa)
			return httpClient.execute(
				requestName: EventApiImpl.sendUserEventsRequestName,
				urlString: url,
				headers: headers,
				body: try events.json(),
				retries: retryConfig.publishEventsRetries,
				classifier: TrackingEventErrorClassifier()
			)
		} catch {
			return FutureImpl<Data>().reject(error)
		}
	}
}
