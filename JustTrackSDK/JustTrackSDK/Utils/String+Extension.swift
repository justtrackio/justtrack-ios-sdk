import CommonCrypto
import CryptoKit

extension String {
	static let sdkPackageName = "JustTrackSDK"

	func matchesRegexPattern(pattern: String) -> Bool {
		guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return false }
		let range = NSRange(location: 0, length: utf16.count)
		return regex.firstMatch(in: self, options: [], range: range) != nil
	}

	var isASCII: Bool {
		allSatisfy { $0.isASCII }
	}

	func sha256() -> [UInt8] {
		if #available(iOS 13.0, *) {
			return Array(SHA256.hash(data: Array(self.utf8)))
		} else {
			return sha256Legacy()
		}
	}

	/// CommonCrypto-based SHA-256 implementation used as a fallback on iOS < 13.
	/// Exposed at internal visibility so it can be tested directly even when running on iOS >= 13.
	func sha256Legacy() -> [UInt8] {
		var result = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
		_ = Array(self.utf8).withUnsafeBytes({ CC_SHA256($0.baseAddress, CC_LONG($0.count), &result) })

		return result
	}

	/// Returns `true` when the string contains `JustTrackSDK`, otherwise `false`
	var containsSDK: Bool {
		// Exclude the top two lines of the stack trace as they point to the signal / exception handler defined in the SDK framework.
		let lines = split(separator: "\n", omittingEmptySubsequences: true)
		let modified = lines.dropFirst(2).joined(separator: "\n")
		return modified.contains(String.sdkPackageName)
	}
}
