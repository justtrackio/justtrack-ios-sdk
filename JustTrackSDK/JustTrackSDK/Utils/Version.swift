import Foundation

public protocol Version: Equatable {
	var major: UInt32 { get }
	var minor: UInt32 { get }
	var patch: UInt32 { get }
	var name: String { get }
	func compare(_ other: any Version) -> ComparisonResult
}

struct VersionImpl: Version, Comparable {
	let major: UInt32
	let minor: UInt32
	let patch: UInt32
	let name: String

	func compare(_ other: any Version) -> ComparisonResult {
		if major > other.major {
			return .orderedDescending
		}
		if major < other.major {
			return .orderedAscending
		}
		if minor > other.minor {
			return .orderedDescending
		}
		if minor < other.minor {
			return .orderedAscending
		}
		if patch > other.patch {
			return .orderedDescending
		}
		if patch < other.patch {
			return .orderedAscending
		}
		return name.compare(other.name)
	}

	static func == (lhs: VersionImpl, rhs: VersionImpl) -> Bool {
		return lhs.compare(rhs) == .orderedSame
	}

	static func < (lhs: VersionImpl, rhs: VersionImpl) -> Bool {
		return lhs.compare(rhs) == .orderedAscending
	}
}

func readAppVersion(from bundle: Bundle = .main) -> AppVersion {
	let bundleVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
	let bundleShortVersionString = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
	return AppVersionImpl(code: bundleVersion, name: bundleShortVersionString)
}

func currentSdkVersion() -> any Version {
	return VersionImpl(major: 8, minor: 0, patch: 0, name: "8.0.0")
}
