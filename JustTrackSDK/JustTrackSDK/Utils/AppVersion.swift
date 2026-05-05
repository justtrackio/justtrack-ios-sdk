import Foundation

/// Protocol representing an application version with code and name.
public protocol AppVersion {
	/// The version code (e.g., build number).
	var code: String { get }
	/// The version name (e.g., marketing version).
	var name: String { get }
}

public extension AppVersion {
	/// Compares this version with another version for equality.
	/// - Parameter version: The version to compare with.
	/// - Returns: true if both code and name are equal, false otherwise.
	func equals(_ version: AppVersion) -> Bool {
		return code == version.code && name == version.name
	}
}

struct AppVersionImpl: AppVersion {
	let code: String
	let name: String
}
