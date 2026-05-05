import Foundation

struct DTOSdkVersion: Codable, Equatable {
	let major: UInt32
	let minor: UInt32
	let patch: UInt32
	let name: String
	let platform: String
	let wrapper: String?

	enum CodingKeys: String, CodingKey {
		case major, minor, patch, name, platform, wrapper
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(major, forKey: .major)
		try container.encode(minor, forKey: .minor)
		try container.encode(patch, forKey: .patch)
		try container.encode(name, forKey: .name)
		try container.encode(platform, forKey: .platform)
		if let wrapper {
			try container.encode(wrapper, forKey: .wrapper)
		}
	}
}
