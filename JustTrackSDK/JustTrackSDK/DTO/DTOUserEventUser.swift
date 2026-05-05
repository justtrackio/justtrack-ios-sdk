import Foundation

struct DTOUserEventUser: Codable {
	let installInstanceId: String
	let countryIso: String?
	let localeCode: String?
	let deviceId: String?
	let idfv: String?
	let userId: String?

	enum CodingKeys: String, CodingKey {
		case installInstanceId, countryIso, localeCode, deviceId, idfv, userId
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(installInstanceId, forKey: .installInstanceId)
		if let countryIso {
			try container.encode(countryIso, forKey: .countryIso)
		}
		if let localeCode {
			try container.encode(localeCode, forKey: .localeCode)
		}
		if let deviceId {
			try container.encode(deviceId, forKey: .deviceId)
		}
		if let idfv {
			try container.encode(idfv, forKey: .idfv)
		}
		if let userId {
			try container.encode(userId, forKey: .userId)
		}
	}
}
