final class AdIdsProviderWrapper {
	weak var adIdsProvider: AdIdsProvider?

	func provideAdIds() -> Future<AdIds> {
		if let adIdsProvider {
			return adIdsProvider.getAdIds()
		}
		return FutureImpl<AdIds>().reject(AdIdsProviderWrapperError.noAdIdsProvider)
	}
}

protocol AdIdsProvider: AnyObject {
	func getAdIds() -> Future<AdIds>
}

enum AdIdsProviderWrapperError: Error {
	case noAdIdsProvider
}
