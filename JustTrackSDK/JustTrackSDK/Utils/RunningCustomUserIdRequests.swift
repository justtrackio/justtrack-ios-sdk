import Foundation

enum RunningCustomUserIdRequests {
	private static let lock = NSObject()
	private static var runningRequests: [String: Future<Void>] = [:]

	static func offer(installId: StringID, customUserId: String, future: Future<Void>) -> Future<Void>? {
		objc_sync_enter(Self.lock)
		defer { objc_sync_exit(Self.lock) }

		let key = keyFor(installId: installId, customUserId: customUserId)
		if let existingFuture = Self.runningRequests[key] {
			return existingFuture
		}

		Self.runningRequests[key] = future

		future.observe(using: { _ in
			Self.done(forKey: key)
		})

		return nil
	}

	private static func done(forKey key: String) {
		objc_sync_enter(Self.lock)
		defer { objc_sync_exit(Self.lock) }

		Self.runningRequests.removeValue(forKey: key)
	}

	private static func keyFor(installId: StringID, customUserId: String) -> String {
		return "\(installId.value):\(customUserId)"
	}
}
