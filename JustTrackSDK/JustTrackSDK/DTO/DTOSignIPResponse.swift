import Foundation

struct DTOSignIPResponse: JsonSerializable {
	let ip: String
	let type: String
	let token: String

	init(data: Data) throws {
		guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
			throw DTODecodingError("failed to parse json as object")
		}

		guard let ip = json["ip"] as? String else {
			throw DTODecodingError("failed to decode ip as String")
		}

		guard let type = json["type"] as? String else {
			throw DTODecodingError("failed to decode type as String")
		}

		guard let token = json["token"] as? String else {
			throw DTODecodingError("failed to decode token as String")
		}

		self.ip = ip
		self.type = type
		self.token = token
	}
}
