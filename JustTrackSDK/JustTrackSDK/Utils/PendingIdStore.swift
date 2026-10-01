import Foundation

enum PendingIdStoreKey {
	static let customUserIdKey = "io.justtrack.attribution.customUserId"
	static let firebaseAppInstanceIdKey = "io.justtrack.attribution.firebaseAppInstanceId"
}

final class PendingIdStore {
	let version: Int
	let key: String

	fileprivate let keyDataVersion = "version"
	fileprivate let keyInstallId = "installId"
	fileprivate let keyPendingId = "pendingId"
	fileprivate let keyStoredId = "storedId"

	init(key: String, version: Int = 1) {
		self.key = key
		self.version = version
	}

	func storeNewId(installId: StringID?, newId: String) -> Bool {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		let state = loadState()
		if let installId {
			if state.storedId == newId && state.installId == installId {
				return false
			}
		}

		state.storePending(installId: installId, pendingId: newId)

		return true
	}

	func getPendingId() -> String? {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		let state = loadState()
		if let pendingId = state.pendingId {
			if pendingId != state.storedId {
				return pendingId
			}
		}

		return nil
	}

	func setStoredAtBackend(installId: StringID, storedId: String) {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		loadState().storeConfirmed(installId: installId, storedId: storedId)
	}

	func getPendingWithNewInstallId(installId: StringID) -> String? {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		let state = loadState()
		guard let nextId = state.pendingId ?? state.storedId else {
			return nil
		}

		if installId == state.installId {
			return nil
		}

		state.clearStorage()

		return nextId
	}

	private func loadState() -> PendingIdState {
		return PendingIdState(pendingIdStore: self)
	}
}

private final class PendingIdState {
	private let userDefaults: UserDefaults
	private let pendingIdStore: PendingIdStore
	fileprivate var installId: StringID?
	fileprivate var pendingId: String?
	fileprivate var storedId: String?

	fileprivate init(pendingIdStore: PendingIdStore) {
		self.pendingIdStore = pendingIdStore
		self.userDefaults = .standard

		let storedData = userDefaults.dictionary(forKey: pendingIdStore.key) ?? [:]
		if storedData[pendingIdStore.keyDataVersion] as? Int != pendingIdStore.version {
			if storedData[pendingIdStore.keyDataVersion] as? Int != nil {  // swiftlint:disable:this prefer_type_checking
				userDefaults.removeObject(forKey: pendingIdStore.key)
			}
			installId = nil
			pendingId = nil
			storedId = nil

			return
		}

		installId = StringID(value: storedData[pendingIdStore.keyInstallId] as? String ?? "")
		pendingId = storedData[pendingIdStore.keyPendingId] as? String
		storedId = storedData[pendingIdStore.keyStoredId] as? String
	}

	fileprivate func storePending(installId: StringID?, pendingId: String) {
		self.installId = installId
		self.pendingId = pendingId
		save()
	}

	fileprivate func storeConfirmed(installId: StringID, storedId: String) {
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
		var newData: [String: Any] = [pendingIdStore.keyDataVersion: pendingIdStore.version]

		if let installId {
			newData[pendingIdStore.keyInstallId] = installId.value
		}

		if let pendingId {
			newData[pendingIdStore.keyPendingId] = pendingId
		}

		if let storedId {
			newData[pendingIdStore.keyStoredId] = storedId
		}

		userDefaults.setValue(newData, forKey: pendingIdStore.key)
	}
}
