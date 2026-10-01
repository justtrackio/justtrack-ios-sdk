import Foundation
import XCTest

@testable import JustTrackSDK

@available(iOS 13.0, *)
final class RemoteConfigTests: XCTestCase {
	private var mockRemoteConfigApi: MockRemoteConfigApi!
	private var userDefaults: UserDefaults!
	private var store: RemoteConfigStore!
	private var remoteConfig: RemoteConfigImpl!

	private let testInstallId = StringID(value: UUID().uuidString)!
	private let testIdfa = "test-idfa"
	private let testUserId = StringID(value: UUID().uuidString)!

	override func setUpWithError() throws {
		mockRemoteConfigApi = MockRemoteConfigApi()
		userDefaults = UserDefaults(suiteName: "io.justtrack.test.remoteconfig.impl")!
		userDefaults.dictionaryRepresentation().keys.forEach { key in
			userDefaults.removeObject(forKey: key)
		}
		store = RemoteConfigStore(userDefaults: userDefaults)

		remoteConfig = createRemoteConfig()
	}

	override func tearDownWithError() throws {
		store.clearAssignments()
		mockRemoteConfigApi = nil
		userDefaults = nil
		store = nil
		remoteConfig = nil
	}

	private func createRemoteConfig(
		store: RemoteConfigStore? = nil,
		isRunning: @escaping () -> Bool = { true }
	) -> RemoteConfigImpl {
		let remoteConfig = RemoteConfigImpl(
			remoteConfigApi: mockRemoteConfigApi,
			logger: LoggerImpl(),
			store: store ?? self.store,
			sdkVersion: VersionImpl(major: 1, minor: 0, patch: 0, name: "1.0.0"),
			appVersion: AppVersionImpl(code: "1", name: "1.0.0"),
			getInstallId: { [testInstallId] in testInstallId },
			getAdIds: { [testIdfa, testUserId] in
				FutureImpl<AdIds>().resolve(AdIds(idfa: StringID(testIdfa), userId: testUserId))
			},
			getDeviceInfo: { DeviceInfo(model: "iPhone", type: .phone, osVersion: "17.0") },
			getAttributionTimestamp: { Date(timeIntervalSince1970: 1_000_000) },
			getFirstSdkInitTimestamp: { Date(timeIntervalSince1970: 1_000_000) },
			getInstallTimestamp: { Date(timeIntervalSince1970: 1_000_000) }
		)
		remoteConfig.isRunning = isRunning
		return remoteConfig
	}

	private func createAssignmentsResponseData(_ assignments: [DTOAssignment]) -> Data {
		let response = [
			"assignments": assignments.map { assignment in
				[
					"experiment": assignment.experiment,
					"variant": assignment.variant,
					"experimentId": assignment.experimentId,
					"variantId": assignment.variantId,
					"configKey": assignment.configKey,
					"configValue": assignment.configValue,
					"pending": assignment.pending ?? false,
				] as [String: Any]
			}
		]
		return try! JSONSerialization.data(withJSONObject: response)
	}

	private func createEnrollmentResponseData(_ assignments: [DTOAssignment]) -> Data {
		let response = [
			"enrolledAssignments": assignments.map { assignment in
				[
					"experiment": assignment.experiment,
					"variant": assignment.variant,
					"experimentId": assignment.experimentId,
					"variantId": assignment.variantId,
					"configKey": assignment.configKey,
					"configValue": assignment.configValue,
					"pending": assignment.pending ?? false,
				] as [String: Any]
			}
		]
		return try! JSONSerialization.data(withJSONObject: response)
	}

	// MARK: fetch

	func testFetchCallsHttpClient() async throws {
		let assignments = [DTOAssignment.fixture()]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)

		try await remoteConfig.fetch()

		XCTAssertEqual(mockRemoteConfigApi.calls.count, 1)
		if case .getAssignments = mockRemoteConfigApi.calls.first {
			// Success
		} else {
			XCTFail("Expected getAssignments call")
		}
	}

	func testFetchUpdatesAssignments() async throws {
		let assignments = [
			DTOAssignment.fixture(experimentId: "exp-1", configKey: "key1", configValue: "value1"),
			DTOAssignment.fixture(experimentId: "exp-2", configKey: "key2", configValue: "42"),
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)

		try await remoteConfig.fetch()

		XCTAssertEqual(remoteConfig.allAssignments.count, 2)
		XCTAssertEqual(remoteConfig.allAssignments[0].experimentId, "exp-1")
		XCTAssertEqual(remoteConfig.allAssignments[0].configKey, "key1")
		XCTAssertEqual(remoteConfig.allAssignments[0].stringValue, "value1")
		XCTAssertEqual(remoteConfig.allAssignments[1].experimentId, "exp-2")
		XCTAssertEqual(remoteConfig.allAssignments[1].intValue, 42)
	}

	func testFetchHandlesNullAssignments() async throws {
		let jsonData = "{\"assignments\": null}".data(using: .utf8)!
		mockRemoteConfigApi.getAssignmentsResponseData = jsonData

		try await remoteConfig.fetch()

		XCTAssertEqual(remoteConfig.allAssignments.count, 0)
	}

	func testFetchStoresAssignmentsInCache() async throws {
		let assignments = [DTOAssignment.fixture(experimentId: "exp-1")]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)

		try await remoteConfig.fetch()

		let stored = store.getStoredAssignments()
		XCTAssertNotNil(stored)
		XCTAssertEqual(stored?.assignments.count, 1)
		XCTAssertEqual(stored?.assignments.first?.experimentId, "exp-1")
	}

	func testFetchReturnsCachedWhenWithinInterval() async throws {
		let cachedAssignment = DTOAssignment.fixture(experimentId: "cached-exp")
		store.storeAssignments([cachedAssignment], fetchedAt: Date())

		let freshAssignment = DTOAssignment.fixture(experimentId: "fresh-exp")
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData([freshAssignment])

		let newRemoteConfig = createRemoteConfig(store: store)
		try await newRemoteConfig.fetch()

		XCTAssertEqual(newRemoteConfig.allAssignments.count, 1)
		XCTAssertEqual(newRemoteConfig.allAssignments.first?.experimentId, "cached-exp")
		XCTAssertEqual(mockRemoteConfigApi.calls.count, 0)
	}

	func testFetchCallsServerWhenIntervalElapsed() async throws {
		let cachedAssignment = DTOAssignment.fixture(experimentId: "cached-exp")
		store.storeAssignments([cachedAssignment], fetchedAt: Date().addingTimeInterval(-90000))

		let freshAssignment = DTOAssignment.fixture(experimentId: "fresh-exp")
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData([freshAssignment])

		let newRemoteConfig = createRemoteConfig(store: store)
		try await newRemoteConfig.fetch()

		XCTAssertEqual(newRemoteConfig.allAssignments.count, 1)
		XCTAssertEqual(newRemoteConfig.allAssignments.first?.experimentId, "fresh-exp")
		XCTAssertEqual(mockRemoteConfigApi.calls.count, 1)
	}

	func testFetchRespectsCustomMinFetchInterval() async throws {
		let cachedAssignment = DTOAssignment.fixture(experimentId: "cached-exp")
		store.storeAssignments([cachedAssignment], fetchedAt: Date().addingTimeInterval(-10))

		let freshAssignment = DTOAssignment.fixture(experimentId: "fresh-exp")
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData([freshAssignment])

		let newRemoteConfig = createRemoteConfig(store: store)
		newRemoteConfig.setConfig(JusttrackRemoteConfigSettings(minFetchIntervalInSec: 5))

		try await newRemoteConfig.fetch()

		XCTAssertEqual(newRemoteConfig.allAssignments.first?.experimentId, "fresh-exp")
		XCTAssertEqual(mockRemoteConfigApi.calls.count, 1)
	}

	// MARK: get(configKey:)

	func testGetReturnsCorrectAssignment() async throws {
		let assignments = [
			DTOAssignment.fixture(configKey: "feature_enabled", configValue: "true"),
			DTOAssignment.fixture(configKey: "max_items", configValue: "100"),
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)

		try await remoteConfig.fetch()

		let featureAssignment = remoteConfig.get(configKey: "feature_enabled")
		XCTAssertNotNil(featureAssignment)
		XCTAssertEqual(featureAssignment?.boolValue, true)

		let maxItemsAssignment = remoteConfig.get(configKey: "max_items")
		XCTAssertNotNil(maxItemsAssignment)
		XCTAssertEqual(maxItemsAssignment?.intValue, 100)
	}

	func testGetReturnsNilForUnknownKey() async throws {
		let assignments = [DTOAssignment.fixture(configKey: "known_key")]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)

		try await remoteConfig.fetch()

		XCTAssertNil(remoteConfig.get(configKey: "unknown_key"))
	}

	// MARK: activate

	func testActivateCallsHttpClientWithExperimentIds() async throws {
		let assignments = [
			DTOAssignment.fixture(experimentId: "exp-1"),
			DTOAssignment.fixture(experimentId: "exp-2"),
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)
		mockRemoteConfigApi.postEnrollmentsResponseData = createEnrollmentResponseData(
			assignments.map { DTOAssignment.fixture(experimentId: $0.experimentId, pending: false) }
		)

		try await remoteConfig.fetch()
		try await remoteConfig.activate(remoteConfig.allAssignments)

		XCTAssertEqual(mockRemoteConfigApi.calls.count, 2)
		if case let .postEnrollments(request, _) = mockRemoteConfigApi.calls.last {
			XCTAssertEqual(request.experimentIds.count, 2)
			XCTAssertTrue(request.experimentIds.contains("exp-1"))
			XCTAssertTrue(request.experimentIds.contains("exp-2"))
		} else {
			XCTFail("Expected postEnrollments call")
		}
	}

	func testActivateUpdatesIsPendingOnAssignments() async throws {
		let assignments = [
			DTOAssignment.fixture(experimentId: "exp-1", pending: true),
			DTOAssignment.fixture(experimentId: "exp-2", pending: true),
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)
		mockRemoteConfigApi.postEnrollmentsResponseData = createEnrollmentResponseData(
			[DTOAssignment.fixture(experimentId: "exp-1", pending: false)]
		)

		try await remoteConfig.fetch()
		let assignmentsBeforeActivate = remoteConfig.allAssignments
		XCTAssertTrue(assignmentsBeforeActivate[0].isPending)
		XCTAssertTrue(assignmentsBeforeActivate[1].isPending)

		try await remoteConfig.activate(assignmentsBeforeActivate)

		XCTAssertFalse(assignmentsBeforeActivate[0].isPending)
		XCTAssertTrue(assignmentsBeforeActivate[1].isPending)
	}

	func testActivateDoesNothingForEmptyArray() async throws {
		try await remoteConfig.activate([])

		XCTAssertEqual(mockRemoteConfigApi.calls.count, 0)
	}

	func testActivateSkipsNonPendingAssignments() async throws {
		let assignments = [
			DTOAssignment.fixture(experimentId: "exp-1", pending: false),
			DTOAssignment.fixture(experimentId: "exp-2", pending: false),
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)

		try await remoteConfig.fetch()
		try await remoteConfig.activate(remoteConfig.allAssignments)

		XCTAssertEqual(mockRemoteConfigApi.calls.count, 1)
		if case .getAssignments = mockRemoteConfigApi.calls.first {
			// Only fetch call, no postEnrollments
		} else {
			XCTFail("Expected only getAssignments call")
		}
	}

	// MARK: activate(experimentIds:)

	func testActivateByExperimentIdsCallsHttpClient() async throws {
		let assignments = [
			DTOAssignment.fixture(experimentId: "exp-1"),
			DTOAssignment.fixture(experimentId: "exp-2"),
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)
		mockRemoteConfigApi.postEnrollmentsResponseData = createEnrollmentResponseData(
			assignments.map { DTOAssignment.fixture(experimentId: $0.experimentId, pending: false) }
		)

		try await remoteConfig.fetch()
		try await remoteConfig.activate(experimentIds: ["exp-1", "exp-2"])

		XCTAssertEqual(mockRemoteConfigApi.calls.count, 2)
		if case let .postEnrollments(request, _) = mockRemoteConfigApi.calls.last {
			XCTAssertEqual(request.experimentIds.count, 2)
			XCTAssertTrue(request.experimentIds.contains("exp-1"))
			XCTAssertTrue(request.experimentIds.contains("exp-2"))
		} else {
			XCTFail("Expected postEnrollments call")
		}
	}

	func testActivateByExperimentIdsFiltersAssignmentsCorrectly() async throws {
		let assignments = [
			DTOAssignment.fixture(experimentId: "exp-1", pending: true),
			DTOAssignment.fixture(experimentId: "exp-2", pending: true),
			DTOAssignment.fixture(experimentId: "exp-3", pending: true),
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)
		mockRemoteConfigApi.postEnrollmentsResponseData = createEnrollmentResponseData(
			[DTOAssignment.fixture(experimentId: "exp-1", pending: false)]
		)

		try await remoteConfig.fetch()
		try await remoteConfig.activate(experimentIds: ["exp-1"])

		if case let .postEnrollments(request, _) = mockRemoteConfigApi.calls.last {
			XCTAssertEqual(request.experimentIds, ["exp-1"])
		} else {
			XCTFail("Expected postEnrollments call")
		}
	}

	func testActivateByExperimentIdsDoesNothingForEmptyArray() async throws {
		let assignments = [DTOAssignment.fixture(experimentId: "exp-1")]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)

		try await remoteConfig.fetch()
		try await remoteConfig.activate(experimentIds: [])

		XCTAssertEqual(mockRemoteConfigApi.calls.count, 1)
	}

	func testActivateByExperimentIdsDoesNothingForUnknownIds() async throws {
		let assignments = [DTOAssignment.fixture(experimentId: "exp-1")]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)

		try await remoteConfig.fetch()
		try await remoteConfig.activate(experimentIds: ["unknown-exp"])

		XCTAssertEqual(mockRemoteConfigApi.calls.count, 1)
	}

	func testActivateUpdatesCache() async throws {
		let assignment = DTOAssignment.fixture(experimentId: "exp-1", pending: true)
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData([assignment])
		mockRemoteConfigApi.postEnrollmentsResponseData = createEnrollmentResponseData(
			[DTOAssignment.fixture(experimentId: "exp-1", pending: false)]
		)

		try await remoteConfig.fetch()
		try await remoteConfig.activate(remoteConfig.allAssignments)

		let stored = store.getStoredAssignments()
		XCTAssertEqual(stored?.assignments.first?.pending, false)
	}

	// MARK: fetchAndActivate

	func testFetchAndActivateFetchesAndActivatesPending() async throws {
		let assignments = [
			DTOAssignment.fixture(experimentId: "exp-1", pending: true),
			DTOAssignment.fixture(experimentId: "exp-2", pending: false),
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)
		mockRemoteConfigApi.postEnrollmentsResponseData = createEnrollmentResponseData(
			[DTOAssignment.fixture(experimentId: "exp-1", pending: false)]
		)

		try await remoteConfig.fetchAndActivate()

		XCTAssertEqual(mockRemoteConfigApi.calls.count, 2)
		XCTAssertFalse(remoteConfig.allAssignments[0].isPending)
		XCTAssertFalse(remoteConfig.allAssignments[1].isPending)

		if case let .postEnrollments(request, _) = mockRemoteConfigApi.calls.last {
			XCTAssertEqual(request.experimentIds, ["exp-1"])
		} else {
			XCTFail("Expected postEnrollments call")
		}
	}

	func testFetchAndActivateSkipsActivateWhenNoPending() async throws {
		let assignments = [
			DTOAssignment.fixture(experimentId: "exp-1", pending: false),
			DTOAssignment.fixture(experimentId: "exp-2", pending: false),
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)

		try await remoteConfig.fetchAndActivate()

		XCTAssertEqual(mockRemoteConfigApi.calls.count, 1)
		if case .getAssignments = mockRemoteConfigApi.calls.first {
			// Success
		} else {
			XCTFail("Expected only getAssignments call")
		}
	}

	// MARK: getValue convenience methods

	func testGetString() async throws {
		let assignments = [
			DTOAssignment.fixture(configKey: "greeting", configValue: "hello world")
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)

		try await remoteConfig.fetch()

		XCTAssertEqual(remoteConfig.getString(configKey: "greeting"), "hello world")
		XCTAssertNil(remoteConfig.getString(configKey: "unknown"))
	}

	func testGetInt() async throws {
		let assignments = [
			DTOAssignment.fixture(experimentId: "1", configKey: "valid_int", configValue: "42"),
			DTOAssignment.fixture(experimentId: "2", configKey: "invalid_int", configValue: "not a number"),
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)

		try await remoteConfig.fetch()

		XCTAssertEqual(remoteConfig.getInt(configKey: "valid_int"), 42)
		XCTAssertNil(remoteConfig.getInt(configKey: "invalid_int"))
		XCTAssertNil(remoteConfig.getInt(configKey: "unknown"))
	}

	func testGetDouble() async throws {
		let assignments = [
			DTOAssignment.fixture(experimentId: "1", configKey: "valid_double", configValue: "3.14"),
			DTOAssignment.fixture(experimentId: "2", configKey: "invalid_double", configValue: "pi"),
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)

		try await remoteConfig.fetch()

		XCTAssertEqual(remoteConfig.getDouble(configKey: "valid_double"), 3.14)
		XCTAssertNil(remoteConfig.getDouble(configKey: "invalid_double"))
		XCTAssertNil(remoteConfig.getDouble(configKey: "unknown"))
	}

	func testGetBool() async throws {
		let assignments = [
			DTOAssignment.fixture(experimentId: "1", configKey: "true_val", configValue: "true"),
			DTOAssignment.fixture(experimentId: "2", configKey: "false_val", configValue: "false"),
			DTOAssignment.fixture(experimentId: "3", configKey: "TRUE_val", configValue: "TRUE"),
			DTOAssignment.fixture(experimentId: "4", configKey: "invalid_bool", configValue: "yes"),
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)

		try await remoteConfig.fetch()

		XCTAssertEqual(remoteConfig.getBool(configKey: "true_val"), true)
		XCTAssertEqual(remoteConfig.getBool(configKey: "false_val"), false)
		XCTAssertEqual(remoteConfig.getBool(configKey: "TRUE_val"), true)
		XCTAssertNil(remoteConfig.getBool(configKey: "invalid_bool"))
		XCTAssertNil(remoteConfig.getBool(configKey: "unknown"))
	}

	// MARK: Error handling

	func testFetchThrowsOnHttpError() async {
		mockRemoteConfigApi.getAssignmentsError = NSError(domain: "test", code: 500)

		do {
			try await remoteConfig.fetch()
			XCTFail("Expected error to be thrown")
		} catch {
			// Success
		}
	}

	func testActivateThrowsOnHttpError() async throws {
		let assignments = [DTOAssignment.fixture()]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)
		mockRemoteConfigApi.postEnrollmentsError = NSError(domain: "test", code: 500)

		try await remoteConfig.fetch()

		do {
			try await remoteConfig.activate(remoteConfig.allAssignments)
			XCTFail("Expected error to be thrown")
		} catch {
			// Success
		}
	}

	func testFetchThrowsWhenSdkStopped() async {
		let stoppedRemoteConfig = createRemoteConfig(isRunning: { false })

		do {
			try await stoppedRemoteConfig.fetch()
			XCTFail("Expected error to be thrown")
		} catch let error as JustTrackError {
			XCTAssertEqual(error, .stopped)
		} catch {
			XCTFail("Expected JustTrackError.stopped")
		}
	}

	func testActivateThrowsWhenSdkStopped() async {
		let stoppedRemoteConfig = createRemoteConfig(isRunning: { false })
		let assignment = JusttrackExperimentAssignment(
			experimentId: "exp-1",
			experimentName: "Test",
			variant: "A",
			configKey: "key",
			configValue: "value",
			isPending: true
		)

		do {
			try await stoppedRemoteConfig.activate([assignment])
			XCTFail("Expected error to be thrown")
		} catch let error as JustTrackError {
			XCTAssertEqual(error, .stopped)
		} catch {
			XCTFail("Expected JustTrackError.stopped")
		}
	}
}

// MARK: - iOS 12 Callback-based API Tests

final class RemoteConfigCallbackTests: XCTestCase {
	private var mockRemoteConfigApi: MockRemoteConfigApi!
	private var userDefaults: UserDefaults!
	private var store: RemoteConfigStore!
	private var remoteConfig: RemoteConfigImpl!

	private let testInstallId = StringID(value: UUID().uuidString)!
	private let testIdfa = "test-idfa"
	private let testUserId = StringID(value: UUID().uuidString)!

	override func setUpWithError() throws {
		mockRemoteConfigApi = MockRemoteConfigApi()
		userDefaults = UserDefaults(suiteName: "io.justtrack.test.remoteconfig.callback")!
		userDefaults.dictionaryRepresentation().keys.forEach { key in
			userDefaults.removeObject(forKey: key)
		}
		store = RemoteConfigStore(userDefaults: userDefaults)

		remoteConfig = createRemoteConfig()
	}

	override func tearDownWithError() throws {
		store.clearAssignments()
		mockRemoteConfigApi = nil
		userDefaults = nil
		store = nil
		remoteConfig = nil
	}

	private func createRemoteConfig(
		store: RemoteConfigStore? = nil,
		isRunning: @escaping () -> Bool = { true }
	) -> RemoteConfigImpl {
		let remoteConfig = RemoteConfigImpl(
			remoteConfigApi: mockRemoteConfigApi,
			logger: LoggerImpl(),
			store: store ?? self.store,
			sdkVersion: VersionImpl(major: 1, minor: 0, patch: 0, name: "1.0.0"),
			appVersion: AppVersionImpl(code: "1", name: "1.0.0"),
			getInstallId: { [testInstallId] in testInstallId },
			getAdIds: { [testIdfa, testUserId] in
				FutureImpl<AdIds>().resolve(AdIds(idfa: StringID(testIdfa), userId: testUserId))
			},
			getDeviceInfo: { DeviceInfo(model: "iPhone", type: .phone, osVersion: "17.0") },
			getAttributionTimestamp: { Date(timeIntervalSince1970: 1_000_000) },
			getFirstSdkInitTimestamp: { Date(timeIntervalSince1970: 1_000_000) },
			getInstallTimestamp: { Date(timeIntervalSince1970: 1_000_000) }
		)
		remoteConfig.isRunning = isRunning
		return remoteConfig
	}

	private func createAssignmentsResponseData(_ assignments: [DTOAssignment]) -> Data {
		let response = [
			"assignments": assignments.map { assignment in
				[
					"experiment": assignment.experiment,
					"variant": assignment.variant,
					"experimentId": assignment.experimentId,
					"variantId": assignment.variantId,
					"configKey": assignment.configKey,
					"configValue": assignment.configValue,
					"pending": assignment.pending ?? false,
				] as [String: Any]
			}
		]
		return try! JSONSerialization.data(withJSONObject: response)
	}

	private func createEnrollmentResponseData(_ assignments: [DTOAssignment]) -> Data {
		let response = [
			"enrolledAssignments": assignments.map { assignment in
				[
					"experiment": assignment.experiment,
					"variant": assignment.variant,
					"experimentId": assignment.experimentId,
					"variantId": assignment.variantId,
					"configKey": assignment.configKey,
					"configValue": assignment.configValue,
					"pending": assignment.pending ?? false,
				] as [String: Any]
			}
		]
		return try! JSONSerialization.data(withJSONObject: response)
	}

	// MARK: fetch(completion:)

	func testFetchWithCompletionCallsHttpClient() {
		let expectation = expectation(description: "fetch completion")
		let assignments = [DTOAssignment.fixture()]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)

		remoteConfig.fetch { error in
			XCTAssertNil(error)
			XCTAssertEqual(self.mockRemoteConfigApi.calls.count, 1)
			if case .getAssignments = self.mockRemoteConfigApi.calls.first {
				// Success
			} else {
				XCTFail("Expected getAssignments call")
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 1)
	}

	func testFetchWithCompletionUpdatesAssignments() {
		let expectation = expectation(description: "fetch completion")
		let assignments = [
			DTOAssignment.fixture(experimentId: "exp-1", configKey: "key1", configValue: "value1"),
			DTOAssignment.fixture(experimentId: "exp-2", configKey: "key2", configValue: "42"),
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)

		remoteConfig.fetch { error in
			XCTAssertNil(error)
			XCTAssertEqual(self.remoteConfig.allAssignments.count, 2)
			XCTAssertEqual(self.remoteConfig.allAssignments[0].experimentId, "exp-1")
			XCTAssertEqual(self.remoteConfig.allAssignments[1].intValue, 42)
			expectation.fulfill()
		}

		waitForExpectations(timeout: 1)
	}

	func testFetchWithCompletionReturnsErrorOnFailure() {
		let expectation = expectation(description: "fetch completion")
		mockRemoteConfigApi.getAssignmentsError = NSError(domain: "test", code: 500)

		remoteConfig.fetch { error in
			XCTAssertNotNil(error)
			expectation.fulfill()
		}

		waitForExpectations(timeout: 1)
	}

	func testFetchWithCompletionReturnsErrorWhenSdkStopped() {
		let expectation = expectation(description: "fetch completion")
		let stoppedRemoteConfig = createRemoteConfig(isRunning: { false })

		stoppedRemoteConfig.fetch { error in
			XCTAssertNotNil(error)
			if let justTrackError = error as? JustTrackError {
				XCTAssertEqual(justTrackError, .stopped)
			} else {
				XCTFail("Expected JustTrackError.stopped")
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 1)
	}

	// MARK: activate(_:completion:)

	func testActivateWithCompletionCallsHttpClient() {
		let expectation = expectation(description: "activate completion")
		let assignments = [
			DTOAssignment.fixture(experimentId: "exp-1"),
			DTOAssignment.fixture(experimentId: "exp-2"),
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)
		mockRemoteConfigApi.postEnrollmentsResponseData = createEnrollmentResponseData(
			assignments.map { DTOAssignment.fixture(experimentId: $0.experimentId, pending: false) }
		)

		remoteConfig.fetch { _ in
			self.remoteConfig.activate(self.remoteConfig.allAssignments) { error in
				XCTAssertNil(error)
				XCTAssertEqual(self.mockRemoteConfigApi.calls.count, 2)
				if case let .postEnrollments(request, _) = self.mockRemoteConfigApi.calls.last {
					XCTAssertEqual(request.experimentIds.count, 2)
				} else {
					XCTFail("Expected postEnrollments call")
				}
				expectation.fulfill()
			}
		}

		waitForExpectations(timeout: 1)
	}

	func testActivateWithCompletionUpdatesIsPending() {
		let expectation = expectation(description: "activate completion")
		let assignments = [
			DTOAssignment.fixture(experimentId: "exp-1", pending: true)
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)
		mockRemoteConfigApi.postEnrollmentsResponseData = createEnrollmentResponseData(
			[DTOAssignment.fixture(experimentId: "exp-1", pending: false)]
		)

		remoteConfig.fetch { _ in
			let assignmentsBefore = self.remoteConfig.allAssignments
			XCTAssertTrue(assignmentsBefore[0].isPending)

			self.remoteConfig.activate(assignmentsBefore) { error in
				XCTAssertNil(error)
				XCTAssertFalse(assignmentsBefore[0].isPending)
				expectation.fulfill()
			}
		}

		waitForExpectations(timeout: 1)
	}

	func testActivateWithCompletionReturnsErrorWhenSdkStopped() {
		let expectation = expectation(description: "activate completion")
		let stoppedRemoteConfig = createRemoteConfig(isRunning: { false })
		let assignment = JusttrackExperimentAssignment(
			experimentId: "exp-1",
			experimentName: "Test",
			variant: "A",
			configKey: "key",
			configValue: "value",
			isPending: true
		)

		stoppedRemoteConfig.activate([assignment]) { error in
			XCTAssertNotNil(error)
			if let justTrackError = error as? JustTrackError {
				XCTAssertEqual(justTrackError, .stopped)
			} else {
				XCTFail("Expected JustTrackError.stopped")
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 1)
	}

	// MARK: activate(experimentIds:completion:)

	func testActivateByExperimentIdsWithCompletionCallsHttpClient() {
		let expectation = expectation(description: "activate completion")
		let assignments = [
			DTOAssignment.fixture(experimentId: "exp-1"),
			DTOAssignment.fixture(experimentId: "exp-2"),
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)
		mockRemoteConfigApi.postEnrollmentsResponseData = createEnrollmentResponseData(
			assignments.map { DTOAssignment.fixture(experimentId: $0.experimentId, pending: false) }
		)

		remoteConfig.fetch { _ in
			self.remoteConfig.activate(experimentIds: ["exp-1", "exp-2"]) { error in
				XCTAssertNil(error)
				XCTAssertEqual(self.mockRemoteConfigApi.calls.count, 2)
				if case let .postEnrollments(request, _) = self.mockRemoteConfigApi.calls.last {
					XCTAssertEqual(request.experimentIds.count, 2)
					XCTAssertTrue(request.experimentIds.contains("exp-1"))
					XCTAssertTrue(request.experimentIds.contains("exp-2"))
				} else {
					XCTFail("Expected postEnrollments call")
				}
				expectation.fulfill()
			}
		}

		waitForExpectations(timeout: 1)
	}

	func testActivateByExperimentIdsWithCompletionFiltersCorrectly() {
		let expectation = expectation(description: "activate completion")
		let assignments = [
			DTOAssignment.fixture(experimentId: "exp-1", pending: true),
			DTOAssignment.fixture(experimentId: "exp-2", pending: true),
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)
		mockRemoteConfigApi.postEnrollmentsResponseData = createEnrollmentResponseData(
			[DTOAssignment.fixture(experimentId: "exp-1", pending: false)]
		)

		remoteConfig.fetch { _ in
			self.remoteConfig.activate(experimentIds: ["exp-1"]) { error in
				XCTAssertNil(error)
				if case let .postEnrollments(request, _) = self.mockRemoteConfigApi.calls.last {
					XCTAssertEqual(request.experimentIds, ["exp-1"])
				} else {
					XCTFail("Expected postEnrollments call")
				}
				expectation.fulfill()
			}
		}

		waitForExpectations(timeout: 1)
	}

	func testActivateByExperimentIdsWithCompletionDoesNothingForUnknownIds() {
		let expectation = expectation(description: "activate completion")
		let assignments = [DTOAssignment.fixture(experimentId: "exp-1")]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)

		remoteConfig.fetch { _ in
			self.remoteConfig.activate(experimentIds: ["unknown-exp"]) { error in
				XCTAssertNil(error)
				XCTAssertEqual(self.mockRemoteConfigApi.calls.count, 1)
				expectation.fulfill()
			}
		}

		waitForExpectations(timeout: 1)
	}

	// MARK: fetchAndActivate(completion:)

	func testFetchAndActivateWithCompletionFetchesAndActivates() {
		let expectation = expectation(description: "fetchAndActivate completion")
		let assignments = [
			DTOAssignment.fixture(experimentId: "exp-1", pending: true)
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)
		mockRemoteConfigApi.postEnrollmentsResponseData = createEnrollmentResponseData(
			[DTOAssignment.fixture(experimentId: "exp-1", pending: false)]
		)

		remoteConfig.fetchAndActivate { error in
			XCTAssertNil(error)
			XCTAssertEqual(self.mockRemoteConfigApi.calls.count, 2)
			XCTAssertFalse(self.remoteConfig.allAssignments[0].isPending)
			expectation.fulfill()
		}

		waitForExpectations(timeout: 1)
	}

	func testFetchAndActivateWithCompletionSkipsActivateWhenNoPending() {
		let expectation = expectation(description: "fetchAndActivate completion")
		let assignments = [
			DTOAssignment.fixture(experimentId: "exp-1", pending: false)
		]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)

		remoteConfig.fetchAndActivate { error in
			XCTAssertNil(error)
			XCTAssertEqual(self.mockRemoteConfigApi.calls.count, 1)
			if case .getAssignments = self.mockRemoteConfigApi.calls.first {
				// Success
			} else {
				XCTFail("Expected only getAssignments call")
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 1)
	}

	func testFetchAndActivateWithCompletionReturnsErrorOnFetchFailure() {
		let expectation = expectation(description: "fetchAndActivate completion")
		mockRemoteConfigApi.getAssignmentsError = NSError(domain: "test", code: 500)

		remoteConfig.fetchAndActivate { error in
			XCTAssertNotNil(error)
			expectation.fulfill()
		}

		waitForExpectations(timeout: 1)
	}

	// MARK: - updateAssignments: pending == nil → false

	func testFetchWithNilPendingDefaultsToFalse() {
		let expectation = expectation(description: "fetch nil pending")
		// DTOAssignment.fixture uses pending: Bool? — pass nil explicitly
		let assignment = DTOAssignment.fixture(experimentId: "exp-nil-pending", pending: nil)
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData([assignment])

		remoteConfig.fetch { error in
			XCTAssertNil(error)
			XCTAssertEqual(self.remoteConfig.allAssignments.count, 1)
			XCTAssertFalse(self.remoteConfig.allAssignments[0].isPending, "nil pending should default to false")
			expectation.fulfill()
		}

		waitForExpectations(timeout: 1)
	}

	// MARK: - activate error path: postEnrollments failure

	func testActivateWithCompletionReturnsErrorOnPostEnrollmentsFailure() {
		let expectation = expectation(description: "activate failure")
		let assignments = [DTOAssignment.fixture(experimentId: "exp-1", pending: true)]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)
		mockRemoteConfigApi.postEnrollmentsError = NSError(domain: "test", code: 503)

		remoteConfig.fetch { _ in
			self.remoteConfig.activate(self.remoteConfig.allAssignments) { error in
				XCTAssertNotNil(error)
				expectation.fulfill()
			}
		}

		waitForExpectations(timeout: 1)
	}

	// MARK: - fetchAndActivate error path: activate failure after successful fetch

	func testFetchAndActivateWithCompletionReturnsErrorOnActivateFailure() {
		let expectation = expectation(description: "fetchAndActivate activate failure")
		let assignments = [DTOAssignment.fixture(experimentId: "exp-1", pending: true)]
		mockRemoteConfigApi.getAssignmentsResponseData = createAssignmentsResponseData(assignments)
		mockRemoteConfigApi.postEnrollmentsError = NSError(domain: "test", code: 503)

		remoteConfig.fetchAndActivate { error in
			XCTAssertNotNil(error)
			expectation.fulfill()
		}

		waitForExpectations(timeout: 1)
	}
}
