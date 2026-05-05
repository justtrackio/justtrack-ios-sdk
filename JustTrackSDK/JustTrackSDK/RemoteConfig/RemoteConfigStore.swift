import Foundation

final class RemoteConfigStore {
	static let assignmentsKey = "io.justtrack.remoteConfig.assignments"

	private static let version: Int = 1

	private let userDefaults: UserDefaults
	private(set) var retryAfterSeconds: Int?

	init(userDefaults: UserDefaults = .standard) {
		self.userDefaults = userDefaults
	}

	func setRetryAfterSeconds(_ seconds: Int?) {
		self.retryAfterSeconds = seconds
	}

	func storeAssignments(_ assignments: [DTOAssignment], fetchedAt: Date) {
		var dict = [String: Any]()
		dict["version"] = Self.version
		dict["fetchedAt"] = formatDateSeconds(fetchedAt)

		if let assignmentsData = try? JSONEncoder().encode(assignments) {
			dict["assignments"] = assignmentsData
		}

		userDefaults.setValue(dict, forKey: Self.assignmentsKey)
	}

	func getStoredAssignments() -> (assignments: [DTOAssignment], fetchedAt: Date)? {
		guard let dict = userDefaults.dictionary(forKey: Self.assignmentsKey) else { return nil }
		guard let version = dict["version"] as? Int else { return nil }
		if version != Self.version { return nil }

		guard let fetchedAtString = dict["fetchedAt"] as? String else { return nil }
		guard let fetchedAt = parseDate(fetchedAtString) else { return nil }

		guard let assignmentsData = dict["assignments"] as? Data else { return nil }
		guard let assignments = try? JSONDecoder().decode([DTOAssignment].self, from: assignmentsData) else { return nil }

		return (assignments, fetchedAt)
	}

	func shouldFetch(minFetchIntervalInSec: TimeInterval) -> Bool {
		guard let stored = getStoredAssignments() else {
			return true
		}

		let effectiveInterval: TimeInterval
		if let retryAfter = retryAfterSeconds {
			effectiveInterval = min(TimeInterval(retryAfter), minFetchIntervalInSec)
		} else {
			effectiveInterval = minFetchIntervalInSec
		}

		let timeSinceLastFetch = Date().timeIntervalSince(stored.fetchedAt)
		return timeSinceLastFetch >= effectiveInterval
	}

	func clearAssignments() {
		userDefaults.removeObject(forKey: Self.assignmentsKey)
	}
}
