import Foundation

protocol AttributionApi {
	func sendAttributionRequest(request: DTOAttributionRequest, userData: UserData) -> Future<Data>
	func getSignedIpClaim(ipProtocol: IPProtocol, userData: UserData) -> Future<Data>
}

final class AttributionApiImpl: AttributionApi {
	private static let getAttributionRequestName = "GetAttribution"
	private static let signIpv4RequestName = "SignIPv4"
	private static let signIpv6RequestName = "SignIPv6"

	private let httpClient: HttpClient
	private let requestFactory: RequestFactory
	private let retryConfig: RetryConfig

	init(httpClient: HttpClient, requestFactory: RequestFactory, retryConfig: RetryConfig) {
		self.httpClient = httpClient
		self.requestFactory = requestFactory
		self.retryConfig = retryConfig
	}

	func sendAttributionRequest(request: DTOAttributionRequest, userData: UserData) -> Future<Data> {
		do {
			let headers = requestFactory.getHeadersV2(userData: userData)
			let url = requestFactory.getUrl(route: .attribution, idfaProvided: userData.providesIdfa)
			return httpClient.execute(
				requestName: AttributionApiImpl.getAttributionRequestName,
				urlString: url,
				headers: headers,
				body: try request.json(),
				retries: retryConfig.attributionRequestRetries,
				classifier: AttributionErrorClassifier()
			)
		} catch {
			return FutureImpl<Data>().reject(error)
		}
	}

	func getSignedIpClaim(ipProtocol: IPProtocol, userData: UserData) -> Future<Data> {
		let headers = requestFactory.getHeaders(userData: userData)
		let url = requestFactory.getUrl(route: ipProtocol.route, idfaProvided: userData.providesIdfa)
		return httpClient.execute(
			requestName: {
				switch ipProtocol {
				case .ipV4: AttributionApiImpl.signIpv4RequestName
				case .ipV6: AttributionApiImpl.signIpv6RequestName
				}
			}(),
			urlString: url,
			headers: headers,
			body: nil,
			retries: retryConfig.fetchClaimRetries,
			classifier: FetchClaimErrorClassifier()
		)
	}
}
