import Foundation

struct PublishingSdkVersionKey: Hashable {
	static func == (lhs: PublishingSdkVersionKey, rhs: PublishingSdkVersionKey) -> Bool {
		lhs.version.name == rhs.version.name
	}

	let version: any Version

	var hashValue: Int {  // swiftlint:disable:this legacy_hashing
		version.name.hashValue
	}

	func hash(into hasher: inout Hasher) {
		version.name.hash(into: &hasher)
	}
}
