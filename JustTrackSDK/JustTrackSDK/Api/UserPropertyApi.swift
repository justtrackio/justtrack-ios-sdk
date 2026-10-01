import Foundation

protocol UserPropertyApi {
	func sendCustomUserId(request: DTOPublishCustomUserIdRequest, userData: UserData) -> Future<Data>
	func sendFirebaseAppInstanceId(request: DTOPublishFirebaseAppInstanceIdRequest, userData: UserData) -> Future<Data>
}

final class UserPropertyApiImpl: UserPropertyApi {
	private static let sendCustomUserIdRequestName = "SendCustomUserId"
	private static let sendFirebaseAppInstanceIdRequestName = "SendFirebaseAppInstanceId"

	private let httpClient: HttpClient
	private let requestFactory: RequestFactory

	init(httpClient: HttpClient, requestFactory: RequestFactory) {
		self.httpClient = httpClient
		self.requestFactory = requestFactory
	}

	func sendCustomUserId(request: DTOPublishCustomUserIdRequest, userData: UserData) -> Future<Data> {
		do {
			let headers = requestFactory.getHeaders(userData: userData)
			let url = requestFactory.getUrl(route: .publishCustomUserId, idfaProvided: userData.providesIdfa)
			return httpClient.execute(
				requestName: UserPropertyApiImpl.sendCustomUserIdRequestName,
				urlString: url,
				headers: headers,
				body: try request.json(),
				retryDelaySeconds: [10, 20, 30],
				classifier: AttributionErrorClassifier()
			)
		} catch {
			return FutureImpl<Data>().reject(error)
		}
	}

	func sendFirebaseAppInstanceId(request: DTOPublishFirebaseAppInstanceIdRequest, userData: UserData) -> Future<Data> {
		do {
			let headers = requestFactory.getHeaders(userData: userData)
			let url = requestFactory.getUrl(route: .publishFirebaseAppInstanceId, idfaProvided: userData.providesIdfa)
			return httpClient.execute(
				requestName: UserPropertyApiImpl.sendFirebaseAppInstanceIdRequestName,
				urlString: url,
				headers: headers,
				body: try request.json(),
				retryDelaySeconds: [10, 20, 30],
				classifier: AttributionErrorClassifier()
			)
		} catch {
			return FutureImpl<Data>().reject(error)
		}
	}
}
