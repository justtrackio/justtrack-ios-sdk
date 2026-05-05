import Foundation

struct Store {
	static let attributionKey = "io.justtrack.attribution"
	static let timestampsKey = "io.justtrack.attribution.timestamps"
	static let appVersionAtInstallKey = "io.justtrack.appVersion.atInstall"
	static let currentAppVersionKey = "io.justtrack.appVersion.current"
	static let firstSdkInitTimestampKey = "io.justtrack.firstSdkInitTimestamp"
	static let testGroupIdKey = "io.justtrack.testGroupId"
	static let postbackConversionValueSetKey = "io.justtrack.postback.conversionValueSetKey"
	private static let version: Int = 3
	private static let noTestGroup: Int = -1

	private let userDefaults: UserDefaults

	init(userDefaults: UserDefaults = .standard) {
		self.userDefaults = userDefaults
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
		dict["campaignId"] = attribution.campaign.id
		dict["campaignName"] = attribution.campaign.name
		dict["campaignType"] = attribution.campaign.type
		dict["campaignOrganic"] = attribution.campaign.isOrganic
		dict["type"] = attribution.type
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

		dict["testGroup"] = attributionOutput.testGroup ?? Self.noTestGroup

		if let sdkConfig = attributionOutput.sdkConfig, let sdkConfigData = try? JSONEncoder().encode(sdkConfig) {
			dict["sdkConfig"] = sdkConfigData
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
		guard let campaignId = dict["campaignId"] as? Int else { return nil }
		guard let campaignName = dict["campaignName"] as? String else { return nil }
		guard let campaignType = dict["campaignType"] as? String else { return nil }
		guard let campaignOrganic = dict["campaignOrganic"] as? Bool else { return nil }
		guard let type = dict["type"] as? String else { return nil }
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
				id: campaignId,
				name: campaignName,
				type: campaignType,
				organic: campaignOrganic
			),
			type: type,
			channel: Channel(id: channelId, name: channelName, incent: channelIncent),
			partner: Partner(id: partnerId, name: partnerName),
			sourceId: sourceId,
			sourceBundleId: sourceBundleId,
			sourcePlacement: sourcePlacement,
			adsetId: adsetId,
			createdAt: createdAt
		)
		var testGroup = dict["testGroup"] as? Int
		if testGroup == Self.noTestGroup {
			testGroup = nil
		}

		var sdkConfig: AttributionOutputSdkConfig?
		if let sdkConfigData = dict["sdkConfig"] as? Data {
			sdkConfig = try? JSONDecoder().decode(AttributionOutputSdkConfig.self, from: sdkConfigData)
		}

		return AttributionOutput(
			completeAttributionResponse: response,
			retargetingParameters: nil,
			testGroup: testGroup,
			claimsTimedOut: false,
			sdkConfig: sdkConfig
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

	func getTestGroupId(idfv: String) -> (Int?, Bool)? {
		if let attribution = getStoredOutput() {
			return (attribution.testGroup, true)
		}

		guard let dict = userDefaults.dictionary(forKey: Self.testGroupIdKey) else {
			return nil
		}

		guard let storedIdfv = dict["idfv"] as? String else { return nil }
		guard let storedTestGroupId = dict["testGroupId"] as? Int else { return nil }

		return (storedTestGroupId, storedIdfv != idfv)
	}

	func setTestGroupId(idfv: String, testGroupId: Int?) {
		let data: [String: Any] = [
			"idfv": idfv,
			"testGroupId": testGroupId ?? -1,
		]
		userDefaults.set(data, forKey: Self.testGroupIdKey)
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
