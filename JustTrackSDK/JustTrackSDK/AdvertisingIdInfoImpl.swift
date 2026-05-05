struct AdvertisingIdInfoImpl: AdvertiserIdInfo {
	let advertiserId: String?

	init(advertiserId: String?) {
		self.advertiserId = advertiserId
	}

	var isLimitedAdTracking: Bool {
		advertiserId == nil
	}
}
