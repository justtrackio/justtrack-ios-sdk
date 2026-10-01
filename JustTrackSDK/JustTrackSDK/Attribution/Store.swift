import Foundation

struct Store {
	static let attributionKey = "io.justtrack.attribution"
	static let timestampsKey = "io.justtrack.attribution.timestamps"
	static let appVersionAtInstallKey = "io.justtrack.appVersion.atInstall"
	static let currentAppVersionKey = "io.justtrack.appVersion.current"
	static let firstSdkInitTimestampKey = "io.justtrack.firstSdkInitTimestamp"
	static let postbackConversionValueSetKey = "io.justtrack.postback.conversionValueSetKey"
	private static let version: Int = 4

	private let userDefaults: UserDefaults

	init(userDefaults: UserDefaults = .standard) {
		self.userDefaults = userDefaults
		migrateStoredAttribution()
	}

	private func migrateStoredAttribution() {
		guard let stored = userDefaults.dictionary(forKey: Self.attributionKey) else { return }
		guard stored["version"] as? Int == 3 else { return }

		var migrated: [String: Any] = ["version": Self.version]
		if let value = stored["userId"] as? String, let userId = StringID(value: value) {
			migrated["userId"] = userId.value
		}
		if let value = stored["installId"] as? String, let installId = StringID(value: value) {
			migrated["installId"] = installId.value
		}

		userDefaults.setValue(migrated, forKey: Self.attributionKey)
	}

	func storeAttribution(attribution attributionOutput: AttributionOutput) {
		var dict = [String: Any]()

		let now = Date()
		let firstAttributedAt = getFirstAttributedAt() ?? now

		dict["firstAttributedAt"] = formatDateSeconds(firstAttributedAt)
		dict["lastAttributedAt"] = formatDateSeconds(now)
		dict["lastOpenAt"] = formatDateSeconds(now)

		userDefaults.setValue(dict, forKey: Self.timestampsKey)

		let attribution = attributionOutput.completeAttributionResponse
		dict = [String: Any]()
		dict["version"] = Self.version
		dict["userId"] = attribution.userId.value
		dict["installId"] = attributionOutput.completeAttributionResponse.installId.value
		dict["userType"] = attribution.userType
		dict["redownload"] = attribution.isRedownload
		dict["campaignExternalId"] = attribution.campaign.id
		dict["campaignName"] = attribution.campaign.name
		dict["campaignType"] = attribution.campaign.type
		dict["campaignOrganic"] = attribution.campaign.isOrganic
		dict["channelId"] = attribution.channel.id
		dict["channelName"] = attribution.channel.name
		dict["channelIncent"] = attribution.channel.isIncent
		dict["networkId"] = attribution.partner.id
		dict["networkName"] = attribution.partner.name
		dict["createdAt"] = formatDateSeconds(attribution.createdAt)
		if let sourceId = attribution.sourceId {
			dict["sourceId"] = sourceId
		}
		if let sourceBundleId = attribution.sourceBundleId {
			dict["sourceBundleId"] = sourceBundleId
		}
		if let sourcePlacement = attribution.sourcePlacement {
			dict["sourcePlacement"] = sourcePlacement
		}
		if let adsetId = attribution.adsetId {
			dict["adsetId"] = adsetId
		}

		userDefaults.setValue(dict, forKey: Self.attributionKey)
	}

	private func getFirstAttributedAt() -> Date? {
		guard let dict = userDefaults.dictionary(forKey: Self.timestampsKey) else {
			return nil
		}

		guard let firstAttributedAt = dict["firstAttributedAt"] as? String else {
			return nil
		}

		return parseDate(firstAttributedAt)
	}

	func getUserId(bundleId: String, uniqueId: String) -> StringID {
		if let userId = tryGetUserId() {
			return userId
		}

		let userId = computeUserId(bundleId: bundleId, uniqueId: uniqueId)
		set(userId: userId)

		return userId
	}

	func tryGetUserId() -> StringID? {
		guard let dict = userDefaults.dictionary(forKey: Self.attributionKey) else { return nil }
		guard let version = dict["version"] as? Int else { return nil }
		if version != Self.version { return nil }
		guard let userIdString = dict["userId"] as? String else { return nil }

		return StringID(value: userIdString)
	}

	func getInstallId() -> StringID {
		if let installId = tryGetInstallId() {
			return installId
		}

		let installId = StringID()
		set(installId: installId)

		return installId
	}

	private func tryGetInstallId() -> StringID? {
		guard let dict = userDefaults.dictionary(forKey: Self.attributionKey) else { return nil }
		guard let version = dict["version"] as? Int else { return nil }
		if version != Self.version { return nil }
		guard let installIdString = dict["installId"] as? String else { return nil }

		return StringID(value: installIdString)
	}

	func set(userId: StringID) {
		var dict =
			userDefaults.dictionary(forKey: Self.attributionKey) ?? [
				"version": Self.version
			]
		dict["userId"] = userId.value

		userDefaults.setValue(dict, forKey: Self.attributionKey)
	}

	func set(installId: StringID) {
		var dict =
			userDefaults.dictionary(forKey: Self.attributionKey) ?? [
				"version": Self.version
			]
		dict["installId"] = installId.value

		userDefaults.setValue(dict, forKey: Self.attributionKey)
	}

	func getStoredOutput() -> AttributionOutput? {
		guard let dict = userDefaults.dictionary(forKey: Self.attributionKey) else { return nil }
		guard let version = dict["version"] as? Int else { return nil }
		if version != Self.version { return nil }
		guard let userIdString = dict["userId"] as? String else { return nil }
		guard let userId = StringID(value: userIdString) else { return nil }
		guard let installIdString = dict["installId"] as? String else { return nil }
		guard let installId = StringID(value: installIdString) else { return nil }
		guard let userType = dict["userType"] as? String else { return nil }
		let redownload = dict["redownload"] as? Bool ?? false
		guard let campaignExternalId = dict["campaignExternalId"] as? String else { return nil }
		guard let campaignName = dict["campaignName"] as? String else { return nil }
		guard let campaignType = dict["campaignType"] as? String else { return nil }
		guard let campaignOrganic = dict["campaignOrganic"] as? Bool else { return nil }
		guard let channelId = dict["channelId"] as? Int else { return nil }
		guard let channelName = dict["channelName"] as? String else { return nil }
		guard let channelIncent = dict["channelIncent"] as? Bool else { return nil }
		guard let partnerId = dict["networkId"] as? Int else { return nil }
		guard let partnerName = dict["networkName"] as? String else { return nil }
		guard let createdAtString = dict["createdAt"] as? String else { return nil }
		guard let createdAt = parseDate(createdAtString) else { return nil }
		let sourceId = dict["sourceId"] as? String
		let sourceBundleId = dict["sourceBundleId"] as? String
		let sourcePlacement = dict["sourcePlacement"] as? String
		let adsetId = dict["adsetId"] as? String

		let response = AttributionResponseImpl(
			userId: userId,
			installId: installId,
			userType: userType,
			redownload: redownload,
			campaign: Campaign(
				id: campaignExternalId,
				name: campaignName,
				type: campaignType,
				organic: campaignOrganic
			),
			channel: Channel(id: channelId, name: channelName, incent: channelIncent),
			partner: Partner(id: partnerId, name: partnerName),
			sourceId: sourceId,
			sourceBundleId: sourceBundleId,
			sourcePlacement: sourcePlacement,
			adsetId: adsetId,
			createdAt: createdAt
		)

		return AttributionOutput(
			completeAttributionResponse: response,
			retargetingParameters: nil,
			claimsTimedOut: false
		)
	}

	func getAttributionTimestamps() -> AttributionTimestamps? {
		guard let dict = userDefaults.dictionary(forKey: Self.timestampsKey) else {
			return nil
		}

		guard let firstAttributedAtString = dict["firstAttributedAt"] as? String else {
			return nil
		}
		guard let firstAttributedAt = parseDate(firstAttributedAtString) else {
			return nil
		}

		let lastAttributedAt: Date
		if let lastAttributedAtString = dict["lastAttributedAt"] as? String {
			lastAttributedAt = parseDate(lastAttributedAtString) ?? firstAttributedAt
		} else {
			lastAttributedAt = firstAttributedAt
		}

		let lastOpenAt: Date
		if let lastOpenAtString = dict["lastOpenAt"] as? String {
			lastOpenAt = parseDate(lastOpenAtString) ?? firstAttributedAt
		} else {
			lastOpenAt = firstAttributedAt
		}

		return AttributionTimestamps(firstAttributedAt: firstAttributedAt, lastAttributedAt: lastAttributedAt, lastOpenAt: lastOpenAt)
	}

	func setLastOpen() {
		var dict = userDefaults.dictionary(forKey: Self.timestampsKey) ?? [:]
		dict["lastOpenAt"] = formatDateSeconds(Date())

		userDefaults.setValue(dict, forKey: Self.timestampsKey)
	}

	func readAppVersionAtInstall(currentVersion: AppVersion) -> AppVersion {
		if let oldVersion = readStoredAppVersion(key: Self.appVersionAtInstallKey) {
			return oldVersion
		}

		setAppVersion(currentVersion: currentVersion, key: Self.appVersionAtInstallKey)

		return currentVersion
	}

	func getFirstSdkInitTimestamp() -> Date? {
		let timestamp = userDefaults.double(forKey: Self.firstSdkInitTimestampKey)
		guard timestamp > 0 else { return nil }
		return Date(timeIntervalSince1970: timestamp)
	}

	func setFirstSdkInitTimestamp(_ date: Date) {
		if getFirstSdkInitTimestamp() != nil {
			return  // Already set, don't overwrite
		}
		userDefaults.set(date.timeIntervalSince1970, forKey: Self.firstSdkInitTimestampKey)
	}

	private func readStoredAppVersion(key: String) -> AppVersion? {
		guard let dict = userDefaults.dictionary(forKey: key) else { return nil }
		if let code = dict["code"] as? String, let name = dict["name"] as? String {
			return AppVersionImpl(code: code, name: name)
		} else if let major = dict["major"] as? UInt32, let minor = dict["minor"] as? UInt32 {
			return AppVersionImpl(code: "\(major).\(minor).0", name: dict["name"] as? String ?? "")
		}
		return nil
	}

	private func setAppVersion(currentVersion: AppVersion, key: String) {
		var dict = [String: Any]()
		dict["code"] = currentVersion.code
		dict["name"] = currentVersion.name
		userDefaults.setValue(dict, forKey: key)
	}

	func getAppVersionUpdateInfo(currentVersion: AppVersion) -> AppVersionUpdateInfo {
		guard let atInstall = readStoredAppVersion(key: Self.appVersionAtInstallKey) else {
			setAppVersion(currentVersion: currentVersion, key: Self.appVersionAtInstallKey)
			setAppVersion(currentVersion: currentVersion, key: Self.currentAppVersionKey)

			return AppVersionUpdateInfo(lastAppVersion: currentVersion, kind: .installedApp)
		}

		let lastAppVersion = readStoredAppVersion(key: Self.currentAppVersionKey) ?? atInstall
		setAppVersion(currentVersion: currentVersion, key: Self.currentAppVersionKey)

		if lastAppVersion.equals(currentVersion) {
			return AppVersionUpdateInfo(lastAppVersion: lastAppVersion, kind: .noChange)
		}

		return AppVersionUpdateInfo(lastAppVersion: lastAppVersion, kind: .updatedApp)
	}
}

struct AppVersionUpdateInfo {
	let lastAppVersion: AppVersion
	let kind: AppVersionUpdateKind

	fileprivate init(lastAppVersion: AppVersion, kind: AppVersionUpdateKind) {
		self.lastAppVersion = lastAppVersion
		self.kind = kind
	}
}

enum AppVersionUpdateKind {
	case installedApp
	case updatedApp
	case noChange
}
