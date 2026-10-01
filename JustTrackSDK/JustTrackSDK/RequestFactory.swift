protocol RequestFactory {
	func getUrl(route: Route, idfaProvided: Bool) -> String
	func getHeaders(userData: UserData) -> [String: String]
	func getHeadersV2(userData: UserData) -> [String: String]
}

final class RequestFactoryImpl: RequestFactory {
	private let environment: Environment
	private let clientId: String
	private let apiToken: String
	private let platformType: PlatformType
	private let appName: String?
	private let appVersion: String

	init(
		environment: Environment = Environment(),
		platformType: PlatformType,
		appName: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
		appVersion: String = readAppVersion().name,
		apiToken: String,
		clientId: String = Bundle.main.bundleIdentifier ?? ""
	) {
		self.environment = environment
		self.platformType = platformType
		self.appName = appName
		self.appVersion = appVersion
		self.apiToken = apiToken
		self.clientId = clientId
	}

	func getUrl(route: Route, idfaProvided: Bool) -> String {
		environment.getUrl(route: route, idfaProvided: idfaProvided)
	}

	func getHeaders(userData: UserData) -> [String: String] {
		var headers = [String: String]()
		headers["X-CLIENT-ID"] = clientId
		headers["X-CLIENT-TOKEN"] = apiToken
		headers["X-ADVERTISER-ID"] = userData.idfa?.value ?? "missing"
		headers["X-USER-ID"] = userData.userId.value
		headers["X-INSTALL-ID"] = userData.installId.value

		// no need to set accept-encoding as the client we are using is already supporting that
		headers["Content-Type"] = "application/json; charset=utf-8"
		headers["User-Agent"] = HttpClientImpl.getUserAgent(platformType: platformType, appName: appName, appVersion: appVersion)

		return headers
	}

	func getHeadersV2(userData: UserData) -> [String: String] {
		var headers = [String: String]()
		headers["X-APP-BUNDLE-ID"] = clientId
		headers["X-APP-TOKEN"] = apiToken
		headers["X-ADVERTISER-ID"] = userData.idfa?.value ?? "missing"
		headers["X-USER-ID"] = userData.userId.value
		headers["X-INSTALL-ID"] = userData.installId.value

		// no need to set accept-encoding as the client we are using is already supporting that
		headers["Content-Type"] = "application/json; charset=utf-8"
		headers["User-Agent"] = HttpClientImpl.getUserAgent(platformType: platformType, appName: appName, appVersion: appVersion)

		return headers
	}
}
