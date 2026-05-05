/// A set of params to configure the justtrack SDK.
struct JustTrackSdkConfig {
	var trackingInfo: TrackingInfo?
	private(set) var userId: String?

	init(
		trackingInfo: TrackingInfo? = nil
	) {
		self.trackingInfo = trackingInfo
		self.userId = nil
	}

	mutating func set(userId: String?) throws {
		guard let userId else {
			self.userId = nil
			return
		}

		if !isValid(customUserId: userId) {
			throw InvalidFieldError(name: "userId", value: userId, maxLength: 4096, encoding: "ASCII")
		}

		self.userId = userId
	}
}

extension JustTrackSdkConfig {
	struct TrackingInfo {
		let id: String
		let provider: String

		init?(id: String, provider: String) throws {
			if !isValid(trackingId: id) {
				throw InvalidFieldError(name: "id", value: id, maxLength: 4096, encoding: "ASCII")
			}

			if !isValid(trackingProvider: provider) {
				throw InvalidFieldError(name: "provider", value: provider, maxLength: 4096, encoding: "ASCII")
			}

			if id != "" && provider != "" {
				self.id = id
				self.provider = provider
			} else {
				return nil
			}
		}
	}
}

extension JustTrackSdkConfig {
	static let `default` = JustTrackSdkConfig()
}
