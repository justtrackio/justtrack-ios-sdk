import StoreKit

protocol SkAdNetwork {
	@available(iOS 11.3, *)
	static func registerAppForAdNetworkAttribution()

	@available(iOS 15.4, *)
	static func updatePostbackConversionValue(_ conversionValue: Int, completionHandler completion: ((Error?) -> Void)?)
}

@available(iOS 11.3, *)
extension SKAdNetwork: SkAdNetwork {}
