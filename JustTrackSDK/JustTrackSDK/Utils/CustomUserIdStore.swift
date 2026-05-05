import Foundation

enum CustomUserIdStore {
	fileprivate static let version: Int = 1
	internal static let key = "io.justtrack.attribution.customUserId"

	fileprivate static let keyDataVersion = "version"
	fileprivate static let keyInstallId = "installId"
	fileprivate static let keyPendingId = "pendingId"
	fileprivate static let keyStoredId = "storedId"

	static func storeNewId(installId: StringID?, customUserId: String) -> Bool {
		let state = CustomUserIdState()
		if let installId {
			if state.storedId == customUserId && state.installId == installId {
				return false
			}
		}

		state.store(installId: installId, pendingId: customUserId)

		return true
	}

	static func getPendingId() -> String? {
		let state = CustomUserIdState()
		if let pendingId = state.pendingId {
			if pendingId != state.storedId {
				return pendingId
			}
		}

		return nil
	}

	static func setStoredAtBackend(installId: StringID, customUserId storedCustomUserId: String) {
		CustomUserIdState().store(installId: installId, storedId: storedCustomUserId)
	}

	static func getPendingWithNewInstallId(installId: StringID) -> String? {
		let state = CustomUserIdState()
		guard let nextId = state.pendingId ?? state.storedId else {
			return nil
		}

		if installId == state.installId {
			return nil
		}

		state.clearStorage()

		return nextId
	}
}

private class CustomUserIdState {
	private let userDefaults: UserDefaults
	fileprivate var installId: StringID?
	fileprivate var pendingId: String?
	fileprivate var storedId: String?

	fileprivate init() {
		self.userDefaults = .standard

		let storedData = userDefaults.dictionary(forKey: CustomUserIdStore.key) ?? [:]
		if storedData[CustomUserIdStore.keyDataVersion] as? Int != CustomUserIdStore.version {
			if storedData[CustomUserIdStore.keyDataVersion] as? Int != nil {  // swiftlint:disable:this prefer_type_checking
				userDefaults.removeObject(forKey: CustomUserIdStore.key)
			}
			installId = nil
			pendingId = nil
			storedId = nil

			return
		}

		installId = StringID(value: storedData[CustomUserIdStore.keyInstallId] as? String ?? "")
		pendingId = storedData[CustomUserIdStore.keyPendingId] as? String
		storedId = storedData[CustomUserIdStore.keyStoredId] as? String
	}

	fileprivate func store(installId: StringID?, pendingId: String) {
		self.installId = installId
		self.pendingId = pendingId
		save()
	}

	fileprivate func store(installId: StringID, storedId: String) {
		self.installId = installId
		self.storedId = storedId
		save()
	}

	fileprivate func clearStorage() {
		self.installId = nil
		self.pendingId = self.pendingId ?? self.storedId
		self.storedId = nil
		save()
	}

	private func save() {
		var newData: [String: Any] = [CustomUserIdStore.keyDataVersion: CustomUserIdStore.version]

		if let installId {
			newData[CustomUserIdStore.keyInstallId] = installId.value
		}

		if let pendingId {
			newData[CustomUserIdStore.keyPendingId] = pendingId
		}

		if let storedId {
			newData[CustomUserIdStore.keyStoredId] = storedId
		}

		userDefaults.setValue(newData, forKey: CustomUserIdStore.key)
	}
}
