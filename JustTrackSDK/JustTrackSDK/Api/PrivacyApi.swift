import Foundation

protocol PrivacyApi {
	func sendAnonymizeRequest(request: DTOAnonymizeRequest, userData: UserData) -> Future<Data>
}

final class PrivacyApiImpl: PrivacyApi {
	private static let sendAnonymizeRequestName = "SendAnonymize"

	private let httpClient: HttpClient
	private let requestFactory: RequestFactory

	init(httpClient: HttpClient, requestFactory: RequestFactory) {
		self.httpClient = httpClient
		self.requestFactory = requestFactory
	}

	func sendAnonymizeRequest(request: DTOAnonymizeRequest, userData: UserData) -> Future<Data> {
		do {
			let headers = requestFactory.getHeadersV2(userData: userData)
			let url = requestFactory.getUrl(route: .privacy, idfaProvided: userData.providesIdfa)
			return httpClient.execute(
				requestName: PrivacyApiImpl.sendAnonymizeRequestName,
				urlString: url,
				headers: headers,
				body: try request.json(),
				retries: 3,
				classifier: AttributionErrorClassifier()
			)
		} catch {
			return FutureImpl<Data>().reject(error)
		}
	}
}
