import Foundation

@objc public class AdjoeIntegration: NSObject {
	fileprivate static var forwardCallback: ((String, String, String, String) -> Void)?
	fileprivate static var reportingCallback: ((String, String?) -> Void)?
	fileprivate static var successCallback: ((String) -> Void)?
	fileprivate static var initIntegration: (() -> Void)?

	@objc public static func registerWithSDK(callback: @escaping () -> Void) {
		Self.initIntegration = callback
	}

	@objc public static func impressionDidSucceed(_ adFormat: String, adNetwork: String, placement: String, appId: String) {
		forwardCallback?(adFormat, adNetwork, placement, appId)
	}

	@objc public static func integrationFailed(_ message: String, version: String?) {
		reportingCallback?(message, version)
	}

	@objc public static func integrationSucceeded(_ version: String) {
		successCallback?(version)
	}

	static func performIntegration(
		_ forwardCallback: @escaping (String, String, String, String) -> Void,
		_ reportingCallback: @escaping (String, String?) -> Void,
		_ successCallback: @escaping (String) -> Void
	) {
		Self.forwardCallback = forwardCallback
		Self.reportingCallback = reportingCallback
		Self.successCallback = successCallback
		Self.initIntegration?()
	}
}
