import Foundation

enum IPProtocol {
	private static let ipv4RequestDurationMetric = Metric(metric: "ClaimDuration", defaultDimensions: ["Protocol": "IPv4"], unit: .seconds)
	private static let ipv6RequestDurationMetric = Metric(metric: "ClaimDuration", defaultDimensions: ["Protocol": "IPv6"], unit: .seconds)

	case ipV4
	case ipV6

	var route: Route {
		switch self {
		case .ipV4: .signIPv4
		case .ipV6: .signIPv6
		}
	}

	var name: String {
		switch self {
		case .ipV4: "IPv4"
		case .ipV6: "IPv6"
		}
	}

	var requestName: String {
		switch self {
		case .ipV4: HttpClientImpl.signIpv4RequestName
		case .ipV6: HttpClientImpl.signIpv6RequestName
		}
	}

	var claimDurationMetric: Metric {
		switch self {
		case .ipV4: IPProtocol.ipv4RequestDurationMetric
		case .ipV6: IPProtocol.ipv6RequestDurationMetric
		}
	}
}

enum Route {
	case attribution
	case trackEvent
	case publishCustomUserId
	case publishFirebaseAppInstanceId
	case log
	case signIPv4
	case signIPv6
	case privacy
	case testAssignment
	case experimentVariantAssignment
	case assignments

	func getUrl(environment: Environment, idfaProvided: Bool) -> String {
		switch self {
		case .attribution: "\(environment.getAttributionDomain(idfaProvided: idfaProvided))/v4/attribute"
		case .trackEvent: "\(environment.getSdkApiDomain(idfaProvided: idfaProvided))/v4/track"
		case .publishCustomUserId: "\(environment.getSdkApiDomain(idfaProvided: idfaProvided))/v0/customUserId/publish"
		case .publishFirebaseAppInstanceId: "\(environment.getSdkApiDomain(idfaProvided: idfaProvided))/v0/firebase/instanceId/publish"
		case .log: "\(environment.getLogsDomain(idfaProvided: idfaProvided))/v2/log"
		case .signIPv4: "\(environment.getIpv4Domain(idfaProvided: idfaProvided))/v0/sign/"
		case .signIPv6: "\(environment.getIpv6Domain(idfaProvided: idfaProvided))/v0/sign/"
		case .privacy: "\(environment.getPrivacyDomain(idfaProvided: idfaProvided))/v1/anonymize"
		case .testAssignment: "\(environment.getSdkApiDomain(idfaProvided: idfaProvided))/ab-test/v0/assignment"
		case .experimentVariantAssignment: "\(environment.getAbTestDomain(idfaProvided: idfaProvided))/v0/assignment"
		case .assignments: "\(environment.getSdkApiDomain(idfaProvided: idfaProvided))/ab-test/v0/assignments"
		}
	}
}

struct Environment {
	private let url: URL

	init(
		url: URL = URL(string: "https://justtrack.io")!  // swiftlint:disable:this force_unwrapping
	) {
		self.url = url
	}

	private var root: String {
		stripScheme(url: url.absoluteString)
	}

	func getUrl(route: Route, idfaProvided: Bool) -> String {
		"https://\(route.getUrl(environment: self, idfaProvided: idfaProvided))"
	}

	fileprivate func getAttributionDomain(idfaProvided: Bool) -> String {
		getDomain(sub: "attribution", idfaProvided: idfaProvided)
	}

	fileprivate func getSdkApiDomain(idfaProvided: Bool) -> String {
		getDomain(sub: "sdk-api", idfaProvided: idfaProvided)
	}

	fileprivate func getLogsDomain(idfaProvided: Bool) -> String {
		getDomain(sub: "justtrack-logs", idfaProvided: idfaProvided)
	}

	fileprivate func getIpv4Domain(idfaProvided: Bool) -> String {
		return "\(idfaProvided ? "4-att" : "ipv4").\(root)"
	}

	fileprivate func getIpv6Domain(idfaProvided: Bool) -> String {
		"\(idfaProvided ? "6-att" : "ipv6").\(root)"
	}

	fileprivate func getPrivacyDomain(idfaProvided: Bool) -> String {
		getDomain(sub: "privacy", idfaProvided: idfaProvided)
	}

	fileprivate func getAbTestDomain(idfaProvided: Bool) -> String {
		getDomain(sub: "sdk-api", idfaProvided: idfaProvided)
	}

	private func getDomain(
		sub: String,
		idfaProvided: Bool
	) -> String {
		idfaProvided ? "\(sub)-att.\(root)" : "\(sub).\(root)"
	}
}

private func stripScheme(url: String) -> String {
	guard let components = URLComponents(string: url) else {
		return url
	}

	var result = ""

	if let host = components.host {
		result += host
	}

	let path = components.percentEncodedPath
	if !path.isEmpty {
		result += path
	}

	if let query = components.percentEncodedQuery {
		result += "?\(query)"
	}

	if let fragment = components.percentEncodedFragment {
		result += "#\(fragment)"
	}

	return result
}
