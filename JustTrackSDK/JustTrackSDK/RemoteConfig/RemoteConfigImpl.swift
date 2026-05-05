import Foundation

final class RemoteConfigImpl: JusttrackRemoteConfig {
	private let httpClient: HttpClient
	private let logger: Logger
	private let store: RemoteConfigStore
	private let sdkVersion: any Version
	private let appVersion: AppVersion
	private let getInstallId: () -> StringID
	private let getAdIds: () -> Future<AdIds>
	private let getDeviceInfo: () -> DeviceInfo
	private let getAttributionTimestamp: () -> Date?
	private let getFirstSdkInitTimestamp: () -> Date?
	private let getInstallTimestamp: () -> Date?

	var isRunning: () -> Bool = { true }

	private var minFetchIntervalInSec: TimeInterval = JusttrackRemoteConfigSettings.defaultMinFetchIntervalInSec
	private var cachedDTOAssignments: [DTOAssignment] = []
	private(set) var allAssignments: [JusttrackExperimentAssignment] = []
	private var assignmentsByKey: [String: JusttrackExperimentAssignment] = [:]

	init(
		httpClient: HttpClient,
		logger: Logger,
		store: RemoteConfigStore = RemoteConfigStore(),
		sdkVersion: any Version,
		appVersion: AppVersion,
		getInstallId: @escaping () -> StringID,
		getAdIds: @escaping () -> Future<AdIds>,
		getDeviceInfo: @escaping () -> DeviceInfo,
		getAttributionTimestamp: @escaping () -> Date?,
		getFirstSdkInitTimestamp: @escaping () -> Date?,
		getInstallTimestamp: @escaping () -> Date?
	) {
		self.httpClient = httpClient
		self.logger = logger
		self.store = store
		self.sdkVersion = sdkVersion
		self.appVersion = appVersion
		self.getInstallId = getInstallId
		self.getAdIds = getAdIds
		self.getDeviceInfo = getDeviceInfo
		self.getAttributionTimestamp = getAttributionTimestamp
		self.getFirstSdkInitTimestamp = getFirstSdkInitTimestamp
		self.getInstallTimestamp = getInstallTimestamp

		if let stored = store.getStoredAssignments() {
			updateAssignments(from: stored.assignments)
		}
	}

	func setConfig(_ settings: JusttrackRemoteConfigSettings) {
		self.minFetchIntervalInSec = settings.minFetchIntervalInSec
	}

	func get(configKey: String) -> JusttrackExperimentAssignment? {
		assignmentsByKey[configKey]
	}

	func getString(configKey: String) -> String? {
		get(configKey: configKey)?.stringValue
	}

	func getBool(configKey: String) -> Bool? {
		get(configKey: configKey)?.boolValue
	}

	func getInt(configKey: String) -> Int? {
		get(configKey: configKey)?.intValue
	}

	func getDouble(configKey: String) -> Double? {
		get(configKey: configKey)?.doubleValue
	}

	func fetch(completion: @escaping (Error?) -> Void) {
		guard isRunning() else {
			completion(JustTrackError.stopped)
			return
		}

		if !store.shouldFetch(minFetchIntervalInSec: minFetchIntervalInSec) && !allAssignments.isEmpty {
			logger.debug("RemoteConfig: Using cached assignments", LoggerFieldsImpl())
			completion(nil)
			return
		}

		logger.debug("RemoteConfig: Fetching assignments from server", LoggerFieldsImpl())

		getAdIds().observe { [weak self] result in
			guard let self = self else {
				completion(JustTrackError.stopped)
				return
			}

			switch result {
			case let .failure(error):
				completion(error)
			case let .success(adIds):
				let installId = self.getInstallId()
				let userData = UserData(idfa: adIds.idfa, userId: adIds.userId, installId: installId)

				let deviceInfo = self.getDeviceInfo()

				let parameters = GetAssignmentsParameters(
					sdkVersion: self.sdkVersion,
					appVersion: self.appVersion,
					osVersion: deviceInfo.osVersion,
					deviceType: deviceInfo.type,
					deviceModel: deviceInfo.model,
					countryIso2: getCurrentCountry(),
					deviceTimestamp: Int(Date().timeIntervalSince1970),
					attributionTimestamp: self.getAttributionTimestamp().map { Int($0.timeIntervalSince1970) },
					firstSdkInitTimestamp: self.getFirstSdkInitTimestamp().map { Int($0.timeIntervalSince1970) },
					installTimestamp: self.getInstallTimestamp().map { Int($0.timeIntervalSince1970) }
				)

				self.httpClient.getAssignments(
					parameters: parameters,
					userData: userData
				).observe { [weak self] result in
					guard let self else {
						completion(JustTrackError.stopped)
						return
					}

					switch result {
					case let .failure(error):
						completion(error)
					case let .success(response):
						do {
							let assignmentsResponse = try DTOGetAssignmentsResponse(data: response.data)
							self.store.storeAssignments(assignmentsResponse.assignments, fetchedAt: Date())
							self.store.setRetryAfterSeconds(response.retryAfterSeconds)
							self.updateAssignments(from: assignmentsResponse.assignments)
							completion(nil)
						} catch {
							completion(error)
						}
					}
				}
			}
		}
	}

	@available(iOS 13.0, *)
	func fetch() async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			fetch { error in
				if let error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume()
				}
			}
		}
	}

	func activate(_ assignments: [JusttrackExperimentAssignment], completion: @escaping (Error?) -> Void) {
		guard isRunning() else {
			completion(JustTrackError.stopped)
			return
		}

		if assignments.isEmpty {
			logger.debug("RemoteConfig: No assignments to activate", LoggerFieldsImpl())
			completion(nil)
			return
		}

		let experimentIds = assignments.map { $0.experimentId }
		logger.debug("RemoteConfig: Activating \(experimentIds.count) assignments", LoggerFieldsImpl())

		getAdIds().observe { [weak self] result in
			guard let self else {
				completion(JustTrackError.stopped)
				return
			}

			switch result {
			case let .failure(error):
				completion(error)
			case let .success(adIds):
				let installId = self.getInstallId()
				let userData = UserData(idfa: adIds.idfa, userId: adIds.userId, installId: installId)

				let request = DTOPostEnrollmentRequest(
					installId: installId,
					experimentIds: experimentIds
				)

				self.httpClient.postEnrollments(
					request: request,
					userData: userData
				).observe { [weak self] result in
					guard let self else {
						completion(JustTrackError.stopped)
						return
					}

					switch result {
					case let .failure(error):
						completion(error)
					case let .success(data):
						do {
							let response = try DTOPostEnrollmentResponse(data: data)

							let enrolledIds = Set(response.enrolledAssignments.map { $0.experimentId })
							for assignment in assignments where enrolledIds.contains(assignment.experimentId) {
								assignment.isPending = false
							}

							var updatedAssignments = self.cachedDTOAssignments
							for enrolled in response.enrolledAssignments {
								if let index = updatedAssignments.firstIndex(where: { $0.experimentId == enrolled.experimentId }) {
									updatedAssignments[index] = enrolled
								}
							}

							self.store.storeAssignments(updatedAssignments, fetchedAt: Date())
							self.updateAssignments(from: updatedAssignments)

							self.logger.debug("RemoteConfig: Activated \(response.enrolledAssignments.count) assignments", LoggerFieldsImpl())
							completion(nil)
						} catch {
							completion(error)
						}
					}
				}
			}
		}
	}

	@available(iOS 13.0, *)
	func activate(_ assignments: [JusttrackExperimentAssignment]) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			activate(assignments) { error in
				if let error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume()
				}
			}
		}
	}

	func activate(experimentIds: [String], completion: @escaping (Error?) -> Void) {
		let experimentIdSet = Set(experimentIds)
		let assignments = allAssignments.filter { experimentIdSet.contains($0.experimentId) }
		activate(assignments, completion: completion)
	}

	@available(iOS 13.0, *)
	func activate(experimentIds: [String]) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			activate(experimentIds: experimentIds) { error in
				if let error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume()
				}
			}
		}
	}

	func fetchAndActivate(completion: @escaping (Error?) -> Void) {
		fetch { [weak self] error in
			if let error {
				completion(error)
				return
			}

			guard let self else {
				completion(JustTrackError.stopped)
				return
			}

			let pendingAssignments = self.allAssignments.filter { $0.isPending }
			self.activate(pendingAssignments, completion: completion)
		}
	}

	@available(iOS 13.0, *)
	func fetchAndActivate() async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			fetchAndActivate { error in
				if let error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume()
				}
			}
		}
	}

	private func updateAssignments(from dtoAssignments: [DTOAssignment]) {
		cachedDTOAssignments = dtoAssignments
		allAssignments = dtoAssignments.map { dto in
			JusttrackExperimentAssignment(
				experimentId: dto.experimentId,
				experimentName: dto.experiment,
				variant: dto.variant,
				configKey: dto.configKey,
				configValue: dto.configValue,
				isPending: dto.pending ?? false
			)
		}

		var dict = [String: JusttrackExperimentAssignment]()
		for assignment in allAssignments {
			dict[assignment.configKey] = assignment
		}
		assignmentsByKey = dict
	}
}
