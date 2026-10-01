import Foundation

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

protocol RemoteConfigApi {
	func sendSetExperimentVariant(request: DTOSetExperimentVariantRequest, userData: UserData) -> Future<Data>
	func getAssignments(parameters: GetAssignmentsParameters, userData: UserData) -> Future<AssignmentsResponse>
	func postEnrollments(request: DTOPostEnrollmentRequest, userData: UserData) -> Future<Data>
}

final class RemoteConfigApiImpl: RemoteConfigApi {
	private static let sendSetExperimentVariantRequestName = "SendSetExperimentVariant"
	private static let getAssignmentsRequestName = "GetAssignments"
	private static let postEnrollmentsRequestName = "PostEnrollments"

	private let httpClient: HttpClient
	private let requestFactory: RequestFactory

	init(httpClient: HttpClient, requestFactory: RequestFactory) {
		self.httpClient = httpClient
		self.requestFactory = requestFactory
	}

	func sendSetExperimentVariant(request: DTOSetExperimentVariantRequest, userData: UserData) -> Future<Data> {
		do {
			let headers = requestFactory.getHeadersV2(userData: userData)
			let url = requestFactory.getUrl(route: .testAssignment, idfaProvided: userData.providesIdfa)
			let classifier = CompositeErrorClassifier(
				classifiers: [
					AttributionErrorClassifier()
				]
			)
			return httpClient.execute(
				requestName: RemoteConfigApiImpl.sendSetExperimentVariantRequestName,
				urlString: url,
				headers: headers,
				body: try request.json(),
				retries: 3,
				classifier: classifier
			)
		} catch {
			return FutureImpl<Data>().reject(error)
		}
	}

	func getAssignments(parameters: GetAssignmentsParameters, userData: UserData) -> Future<AssignmentsResponse> {
		let headers = requestFactory.getHeadersV2(userData: userData)
		let baseUrl = requestFactory.getUrl(route: .assignments, idfaProvided: userData.providesIdfa)

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

		return httpClient.execute(
			requestName: RemoteConfigApiImpl.getAssignmentsRequestName,
			urlString: urlString,
			headers: headers,
			body: nil,
			retries: 3,
			classifier: classifier
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
			let headers = requestFactory.getHeadersV2(userData: userData)
			let url = requestFactory.getUrl(route: .assignments, idfaProvided: userData.providesIdfa)
			let classifier = CompositeErrorClassifier(
				classifiers: [
					PaymentLimitErrorClassifier(),
					AttributionErrorClassifier(),
				]
			)
			return httpClient.execute(
				requestName: RemoteConfigApiImpl.postEnrollmentsRequestName,
				urlString: url,
				headers: headers,
				body: try request.json(),
				retries: 3,
				classifier: classifier
			)
		} catch {
			return FutureImpl<Data>().reject(error)
		}
	}
}
