struct EnvironmentSettings {
	let environment: Environment
	let apiToken: String

	init(
		prefixedApiToken: String,
		serverUrl: URL?
	) {
		if let serverUrl {
			environment = Environment(url: serverUrl)
		} else {
			environment = Environment()
		}

		let sandbox = "sandbox-"
		if prefixedApiToken.hasPrefix(sandbox) {
			apiToken = String(prefixedApiToken.suffix(from: sandbox.endIndex))
		} else {
			let prod = "prod-"
			apiToken = prefixedApiToken.hasPrefix(prod) ? String(prefixedApiToken.suffix(from: prod.endIndex)) : prefixedApiToken
		}
	}
}
