import Foundation

struct DTOAttributionRequest: Codable, Equatable, DTO {
	let appVersion: DTOAppVersion
	let sdkVersion: DTOSdkVersion
	let user: DTOAttributionRequestUser
	let device: DTOAttributionRequestDevice
	let claims: [String]
	let parameters: [String: String]

	func json() throws -> Data {
		return try JSONEncoder().encode(self)
	}
}

struct DTOAttributionRequestUser: Codable, Equatable {
	let userId: String
	let installInstanceId: String
	let deviceId: String
	let advertiserId: String?
	let hasLimitedAdTracking: Bool
	let trackingId: String
	let trackingProvider: String
	let countryIso: String?

	init(
		userId: StringID,
		installInstanceId: StringID,
		idfv: StringID?,
		idfa: StringID?,
		hasLimitedAdTracking: Bool,
		trackingId: String?,
		trackingProvider: String?,
		countryIso: String?
	) {
		self.userId = userId.value
		self.installInstanceId = installInstanceId.value
		self.deviceId = idfv?.value ?? ""
		self.advertiserId = idfa?.value ?? ""
		self.hasLimitedAdTracking = hasLimitedAdTracking
		self.trackingId = trackingId ?? ""
		self.trackingProvider = trackingProvider ?? ""
		self.countryIso = countryIso
	}
}

func getUniqueId(advertiserId: String, trackingId: String, deviceId: String) -> String {
	if !advertiserId.isEmpty {
		return advertiserId
	}

	if !trackingId.isEmpty {
		return trackingId
	}

	return deviceId
}

func computeUserId(bundleId: String, uniqueId: String) -> StringID {
	let input = "\(LocalCredentials.userIdSalt)-\(bundleId.lowercased())-\(uniqueId.lowercased())"
	let hashed = input.sha256()

	var uuid: uuid_t = (
		hashed[0] ^ hashed[1],
		hashed[2] ^ hashed[3],
		hashed[4] ^ hashed[5],
		hashed[6] ^ hashed[7],
		hashed[8] ^ hashed[9],
		hashed[10] ^ hashed[11],
		hashed[12] ^ hashed[13],
		hashed[14] ^ hashed[15],
		hashed[16] ^ hashed[17],
		hashed[18] ^ hashed[19],
		hashed[20] ^ hashed[21],
		hashed[22] ^ hashed[23],
		hashed[24] ^ hashed[25],
		hashed[26] ^ hashed[27],
		hashed[28] ^ hashed[29],
		hashed[30] ^ hashed[31]
	)

	// set version and variant
	uuid.6 = (uuid.6 & 0x0F) | 0x40
	uuid.8 = (uuid.8 & 0x3F) | 0x80

	return StringID(value: uuid)
}

struct DTOAttributionRequestDevice: Codable, Equatable {
	let name: String
	let model: String
	let product: String
	let type: String
	let os: DTOAttributionRequestDeviceOS
	let display: DTOAttributionRequestDeviceDisplay

	init(
		name: String,
		model: String,
		product: String,
		type: DeviceType,
		os: DTOAttributionRequestDeviceOS,
		display: DTOAttributionRequestDeviceDisplay
	) {
		self.name = name
		self.model = model
		self.product = product
		self.type = type.stringValue
		self.os = os
		self.display = display
	}
}

struct DTOAttributionRequestDeviceOS: Codable, Equatable {
	let version: String
	let name: String
}

struct DTOAttributionRequestDeviceDisplay: Codable, Equatable {
	let width: Int
	let height: Int
}

class DTOAttributionResponse: AttributionResponseImpl {
	let retargetingParameters: RetargetingParameters?
	let userTestGroup: Int?

	init(userId: StringID, data: Data, wasAlreadyInstalled: Bool) throws {
		guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
			throw DTODecodingError("failed to parse json as object")
		}

		guard let userObject = json["user"] as? [String: Any] else {
			throw DTODecodingError("failed to decode user object")
		}
		guard let installIdString = userObject["installId"] as? String else {
			throw DTODecodingError("failed to decode install id string")
		}
		guard let installId = StringID(value: installIdString) else {
			throw DTODecodingError("invalid install id string: " + installIdString)
		}
		guard let userType = userObject["type"] as? String else {
			throw DTODecodingError("failed to decode user type string")
		}
		guard let redownload = userObject["redownload"] as? Bool else {
			throw DTODecodingError("failed to decode redownload boolean")
		}

		guard let attributionObject = json["attribution"] as? [String: Any] else {
			throw DTODecodingError("failed to decode attribution object")
		}
		guard let campaignObject = attributionObject["campaign"] as? [String: Any] else {
			throw DTODecodingError("failed to decode campaign object")
		}
		guard let campaignId = campaignObject["id"] as? Int else {
			throw DTODecodingError("failed to decode campaign id")
		}
		guard let campaignName = campaignObject["name"] as? String else {
			throw DTODecodingError("failed to decode campaign name")
		}
		guard let campaignType = campaignObject["type"] as? String else {
			throw DTODecodingError("failed to decode campaign name")
		}
		guard let campaignOrganic = campaignObject["organic"] as? Bool else {
			throw DTODecodingError("failed to decode campaign organic flag")
		}
		guard let type = attributionObject["type"] as? String else {
			throw DTODecodingError("failed to decode attribution type")
		}
		guard let channelObject = attributionObject["channel"] as? [String: Any] else {
			throw DTODecodingError("failed to decode channel object")
		}
		guard let channelId = channelObject["id"] as? Int else {
			throw DTODecodingError("failed to decode channel id")
		}
		guard let channelName = channelObject["name"] as? String else {
			throw DTODecodingError("failed to decode channel name")
		}
		guard let channelIncent = channelObject["incent"] as? Bool else {
			throw DTODecodingError("failed to decode channel incent flag")
		}
		guard let networkObject = attributionObject["network"] as? [String: Any] else {
			throw DTODecodingError("failed to decode network object")
		}
		guard let partnerId = networkObject["id"] as? Int else {
			throw DTODecodingError("failed to decode network id")
		}
		guard let partnerName = networkObject["name"] as? String else {
			throw DTODecodingError("failed to decode network name")
		}
		let sourceId = attributionObject["sourceId"] as? String
		let sourceBundleId = attributionObject["sourceBundleId"] as? String
		let sourcePlacement = attributionObject["sourcePlacement"] as? String
		let adsetId = attributionObject["adsetId"] as? String
		guard let attributedAt = attributionObject["attributedAt"] as? String else {
			throw DTODecodingError("failed to decode attributed at")
		}
		guard let createdAt = parseDate(attributedAt) else {
			throw DTODecodingError("failed to parse attributed at")
		}

		if let retargetingObject = json["retargeting"] as? [String: Any] {
			let url: URL?
			if let urlString = retargetingObject["url"] as? String {
				url = URL(string: urlString)
			} else {
				url = nil
			}
			var attributes: [String: String] = [:]
			if let attributesObject = retargetingObject["attributes"] as? [String: Any] {
				for attribute in attributesObject {
					if let value = attribute.value as? String {
						attributes[attribute.key] = value
					}
				}
			}

			self.retargetingParameters = RetargetingParametersImpl(wasAlreadyInstalled: wasAlreadyInstalled, url: url, parameters: attributes)
		} else {
			self.retargetingParameters = nil
		}

		self.userTestGroup = userObject["testGroup"] as? Int

		super.init(
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
	}
}
