import Foundation
import XCTest

@testable import JustTrackSDK

final class PublishEventsQueueTests: XCTestCase {
	private var connectivityManager: MockConnectivityManager!
	private var eventStore: EventStoring!
	private var logger: MockHttpLogger!
	private var publisher: MockEventPublisher!
	private var dispatchQueue: DispatchQueue!
	private var sequenceNumberProvider: SequenceNumberProvider!
	private var sqliteDriver: DefaultSqliteDriver!
	private let sdkVersions = [
		VersionImpl(major: 5, minor: 0, patch: 0, name: "5.0.0"),
		VersionImpl(major: 6, minor: 0, patch: 0, name: "6.0.0"),
		VersionImpl(major: 6, minor: 1, patch: 0, name: "6.1.0"),
	]

	private lazy var queue = PublishEventsQueue(
		connectivityManager: connectivityManager,
		eventStore: eventStore,
		logger: logger,
		publisher: publisher,
		queue: dispatchQueue,
		sequenceNumberProvider: sequenceNumberProvider,
		sqliteDriver: sqliteDriver,
		sdkVersionProvider: provideSdkVersion
	)

	override func setUp() {
		super.setUp()
		JustTrack.resetForTesting(clearStorage: true)

		connectivityManager = MockConnectivityManager()
		eventStore = EventStore()
		logger = MockHttpLogger()
		publisher = MockEventPublisher()
		dispatchQueue = DispatchQueue(label: "io.justtrack.PublishEventsQueue.queue", qos: .userInteractive)
		sequenceNumberProvider = MockSequenceNumberProvider()
		sqliteDriver = try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)")
		provideSdkVersionCallsNumber = -1
	}

	func testPublishEventSimple() {
		let httpClient = HttpClientImpl(
			retryConfig: RetryConfig.defaultConfig,
			urlSession: URLSession.shared
		)
		let requestFactory = RequestFactoryImpl(
			platformType: .native,
			apiToken: TestCredentials.apiToken,
			clientId: TestCredentials.clientId
		)
		let testClient = TestUserEventsHttpClient(httpClient: httpClient, requestFactory: requestFactory, remainingFails: 0)
		let sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: httpClient,
			attributionApi: testClient,
			privacyApi: testClient,
			eventApi: testClient,
			logApi: testClient,
			userPropertyApi: testClient,
			remoteConfigApi: testClient,
			sessionManagerBuilder: { _ in NopSessionManager() },
			connectivityManagerBuilder: { _ in nil },
			adTrackingProvider: TestAdTrackingProvider(idfa: JustTrackSdkTests.idfa, idfv: JustTrackSdkTests.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)"),
			config: .default,
			manualStart: true
		)
		sdk.start()
		let expectation = self.expectation(description: #function)
		let f = sdk.track(event: JtTrackingPermissionEvent(jtAction: "requested", happenedAt: Date()))
		f.observe { result in
			switch result {
			case let .failure(error):
				XCTFail(error.justTrackGetErrorDescription())
			case .success:
				XCTAssert(true)
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 60)
		assertCorrectEventsPublished(
			expected: [
				JtTrackingPermissionEvent.name,
				JtAppInstallEvent.name,
				JtAppOpenEvent.name,
			],
			actual: testClient.publishedEvents
		)
		sdk.shutdown()
	}

	func testPublishEventWithReallyBadNetwork() {
		let httpClient = HttpClientImpl(
			retryConfig: RetryConfig.defaultConfig,
			urlSession: URLSession.shared
		)
		let requestFactory = RequestFactoryImpl(
			platformType: .native,
			apiToken: TestCredentials.apiToken,
			clientId: TestCredentials.clientId
		)
		let testClient = TestUserEventsHttpClient(
			httpClient: httpClient,
			requestFactory: requestFactory,
			remainingFails: 5
		)
		let sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: httpClient,
			attributionApi: testClient,
			privacyApi: testClient,
			eventApi: testClient,
			logApi: testClient,
			userPropertyApi: testClient,
			remoteConfigApi: testClient,
			sessionManagerBuilder: { _ in NopSessionManager() },
			connectivityManagerBuilder: { _ in nil },
			adTrackingProvider: TestAdTrackingProvider(idfa: JustTrackSdkTests.idfa, idfv: JustTrackSdkTests.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)"),
			config: .default,
			manualStart: true
		)
		sdk.start()
		let expectation = self.expectation(description: #function)
		let f = sdk.track(event: JtTrackingPermissionEvent(jtAction: "requested", happenedAt: Date()))
		f.observe { result in
			switch result {
			case let .failure(error):
				XCTFail(error.justTrackGetErrorDescription())
			case .success:
				XCTAssert(true)
			}
			expectation.fulfill()
		}
		let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
			// every second we are reachable again
			sdk.getUserEventQueue().onReachable()
		}
		waitForExpectations(timeout: 60)
		timer.invalidate()
		assertCorrectEventsPublished(
			expected: [
				JtTrackingPermissionEvent.name,
				JtAppInstallEvent.name,
				JtAppOpenEvent.name,
			],
			actual: testClient.publishedEvents
		)
		sdk.shutdown()
	}

	func testPublishEventsManyConcurrently() {
		let httpClient = HttpClientImpl(
			retryConfig: RetryConfig.defaultConfig,
			urlSession: URLSession.shared
		)
		let requestFactory = RequestFactoryImpl(
			platformType: .native,
			apiToken: TestCredentials.apiToken,
			clientId: TestCredentials.clientId
		)
		let testClient = TestUserEventsHttpClient(
			httpClient: httpClient,
			requestFactory: requestFactory,
			remainingFails: 0
		)

		let sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: httpClient,
			attributionApi: testClient,
			privacyApi: testClient,
			eventApi: testClient,
			logApi: testClient,
			userPropertyApi: testClient,
			remoteConfigApi: testClient,
			sessionManagerBuilder: { _ in NopSessionManager() },
			connectivityManagerBuilder: { _ in nil },
			adTrackingProvider: TestAdTrackingProvider(idfa: JustTrackSdkTests.idfa, idfv: JustTrackSdkTests.idfv),
			skAdNetwork: MockSkAdNetwork.self,
			adTrackingEventPublisher: MockAdTrackingEventPublisher(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)"),
			config: JustTrackSdkConfig(
				trackingInfo: try! JustTrackSdkConfig.TrackingInfo(id: "trackingId", provider: "test")
			),
			manualStart: false
		)

		let expectation = self.expectation(description: #function)
		let group = DispatchGroup()
		var expectedEvents: [String] = [JtAppInstallEvent.name, JtAppOpenEvent.name]

		// Publish events concurrently
		for i in 0..<100 {
			group.enter()
			let eventName = "event_\(i)"
			expectedEvents.append(eventName)
			sdk.track(event: AppEvent(eventName)).observe { result in
				if case .failure(let error) = result {
					XCTFail(error.justTrackGetErrorDescription())
				}
				group.leave()
			}
		}

		group.notify(queue: .main) {
			self.assertCorrectEventsPublished(expected: expectedEvents, actual: testClient.publishedEvents)
			sdk.shutdown()
			expectation.fulfill()
		}

		waitForExpectations(timeout: 60)
	}

	func testProvideNextIsCalledAfterPublishEvent() {
		let expectation = expectation(description: #function)

		for num in 0...5 {
			_ = queue.publishEvent(
				event: PublishableUserEvent(
					name: "event_\(num)",
					sessionId: "7072faff-8242-4317-a399-a31b89d42b67",
					dimensions: [:],
					value: 41,
					unit: .count,
					currency: nil,
					happenedAt: Date()
				)
			)
		}

		dispatchQueue.async {
			XCTAssertEqual(
				(self.sequenceNumberProvider as! MockSequenceNumberProvider).calls,
				[
					.provideNext(0),
					.provideNext(1),
					.provideNext(2),
					.provideNext(3),
					.provideNext(4),
					.provideNext(5),
				]
			)
			expectation.fulfill()
		}

		waitForExpectations(timeout: 5)
	}

	func testStoreEventIsCalledWithCorrectSequenceNumber() {
		let expectation = expectation(description: #function)
		var sequenceNumbers = [Int]()
		let expectedSequenceNumbers = [0, 1, 2, 3, 4, 5]
		let mockEventStore = MockEventStore()
		mockEventStore.onStoreEvent = { event in
			sequenceNumbers.append(event.sequenceNumber)
		}
		eventStore = mockEventStore

		for num in expectedSequenceNumbers {
			_ = queue.publishEvent(
				event: PublishableUserEvent(
					name: "event_\(num)",
					sessionId: "7072faff-8242-4317-a399-a31b89d42b67",
					dimensions: [:],
					value: 41,
					unit: .count,
					currency: nil,
					happenedAt: Date()
				)
			)
		}

		dispatchQueue.async {
			XCTAssertEqual(sequenceNumbers, expectedSequenceNumbers)
			expectation.fulfill()
		}

		waitForExpectations(timeout: 5)
	}

	func testPublishesCorrectSdkVersion() {
		provideSdkVersionCallsNumber = -1

		let events = [
			PublishableUserEvent(name: "event_1", sessionId: "session_1", dimensions: [:], value: 41, unit: .count, currency: nil, happenedAt: Date()),
			PublishableUserEvent(name: "event_2", sessionId: "session_1", dimensions: [:], value: 42, unit: .count, currency: nil, happenedAt: Date()),
			PublishableUserEvent(name: "event_3", sessionId: "session_2", dimensions: [:], value: 11, unit: .milliseconds, currency: nil, happenedAt: Date()),
		]

		_ = queue
		publisher.calls = []
		publisher.publishEventBatchPromise.resolve(Void())

		let expectation = self.expectation(description: #function)
		expectation.expectedFulfillmentCount = events.count

		for event in events {
			queue.publishEvent(event: event).observe { result in
				if case let .failure(error) = result {
					XCTFail(error.justTrackGetErrorDescription())
				}
				expectation.fulfill()
			}
		}

		waitForExpectations(timeout: 10)

		// Collect all published events from all batches
		var publishedItems: [PublishingBatchItem] = []

		for call in publisher.calls {
			switch call {
			case .registerAttributionListener:
				XCTFail("Wrong call")
			case let .publishEventBatch(items):
				publishedItems.append(contentsOf: items)
			}
		}

		// Verify we have exactly 3 published events
		XCTAssertEqual(publishedItems.count, 3, "Expected 3 published events but got \(publishedItems.count)")

		// Verify each event has the correct SDK version
		for (idx, item) in publishedItems.enumerated() {
			guard idx < events.count else {
				XCTFail("Index \(idx) out of range for events array (count: \(events.count))")
				continue
			}
			guard idx < sdkVersions.count else {
				XCTFail("Index \(idx) out of range for sdkVersions array (count: \(sdkVersions.count))")
				continue
			}

			XCTAssertEqual(item.baseEvent, events[idx], "Event at index \(idx) doesn't match")
			XCTAssertEqual(item.sdkVersion.major, sdkVersions[idx].major, "SDK version major at index \(idx) doesn't match")
			XCTAssertEqual(item.sdkVersion.minor, sdkVersions[idx].minor, "SDK version minor at index \(idx) doesn't match")
			XCTAssertEqual(item.sdkVersion.patch, sdkVersions[idx].patch, "SDK version patch at index \(idx) doesn't match")
			XCTAssertEqual(item.sdkVersion.name, sdkVersions[idx].name, "SDK version name at index \(idx) doesn't match")
		}
	}

	private func assertCorrectEventsPublished(expected expectedEvents: [String], actual actualEvents: [String]) {
		var expectedMap: [String: Int] = [:]
		var actualMap: [String: Int] = [:]

		for expected in expectedEvents {
			expectedMap[expected] = (expectedMap[expected] ?? 0) + 1
		}
		for actual in actualEvents {
			actualMap[actual] = (actualMap[actual] ?? 0) + 1
		}

		var missing: [String] = []
		var duplicates: [String] = []

		for (k, v) in expectedMap {
			let difference = v - (actualMap[k] ?? 0)
			if difference > 0 {
				for _ in 0..<difference {
					missing.append(k)
				}
			} else if difference < 0 {
				for _ in 0..<difference {
					duplicates.append(k)
				}
			}
		}

		for (k, v) in actualMap {
			if expectedMap[k] != nil {
				continue
			}

			for _ in 0..<v {
				duplicates.append(k)
			}
		}

		if missing.count > 0 || duplicates.count > 0 {
			XCTFail("Missing: \(missing); Duplicates: \(duplicates)")
		}
	}

	// MARK: - shutdown

	func testShutdownStopsPublishing() {
		let expectation = self.expectation(description: #function)

		_ = queue
		queue.shutdown()

		// After shutdown, events published should not be forwarded
		dispatchQueue.async {
			// If shutdown executed, done flag is set; we can't check it directly
			// but we can verify no new batch was dispatched after shutdown:
			let callsBefore = self.publisher.calls.count
			_ = self.queue.publishEvent(
				event: PublishableUserEvent(
					name: "post_shutdown_event",
					sessionId: "s",
					dimensions: [:],
					value: 1.0,
					unit: .count,
					currency: nil,
					happenedAt: nil
				)
			)
			self.dispatchQueue.async {
				// handle() returns early when done == true, so no new publishEventBatch call
				XCTAssertEqual(self.publisher.calls.count, callsBefore)
				expectation.fulfill()
			}
		}

		waitForExpectations(timeout: 5)
	}

	// MARK: - onReachable moves retry queue to work queue

	func testOnReachableRetriesFailedEvents() {
		let failPublisher = MockEventPublisher()
		let failPromise = FutureImpl<Void>()
		failPublisher.publishEventBatchPromise = failPromise
		let localQueue = PublishEventsQueue(
			connectivityManager: nil,
			eventStore: MockEventStore(),
			logger: MockHttpLogger(),
			publisher: failPublisher,
			queue: dispatchQueue,
			sequenceNumberProvider: MockSequenceNumberProvider(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)"),
			sdkVersionProvider: { VersionImpl(major: 1, minor: 0, patch: 0, name: "1.0.0") }
		)

		let publishExpectation = self.expectation(description: "event published after retry")
		let successPromise = FutureImpl<Void>()

		// Publish one event — it will fail on first attempt
		localQueue.publishEvent(
			event: PublishableUserEvent(
				name: "retry_event",
				sessionId: "s",
				dimensions: [:],
				value: 1.0,
				unit: .count,
				currency: nil,
				happenedAt: nil
			)
		).observe { result in
			if case .success = result {
				publishExpectation.fulfill()
			}
		}

		// Wait for the event to be dispatched, then fail it
		dispatchQueue.async {
			failPromise.reject(TestError(1))
			// Now swap promise so retry succeeds
			failPublisher.publishEventBatchPromise = successPromise
			successPromise.resolve(Void())
			// onReachable moves retryQueue → workQueue and re-publishes
			localQueue.onReachable()
		}

		waitForExpectations(timeout: 10)
	}

	// MARK: - Batch flushed immediately on session-end event

	func testBatchFlushedOnSessionEndEvent() {
		let expectation = self.expectation(description: #function)
		publisher.publishEventBatchPromise.resolve(Void())

		let sessionEndEvent = PublishableUserEvent(
			name: JtSessionTrackingEvent.name,
			sessionId: "s",
			dimensions: [Dimension.jtAction.rawValue: "end"],
			value: 0,
			unit: nil,
			currency: nil,
			happenedAt: Date()
		)

		queue.publishEvent(event: sessionEndEvent).observe { result in
			if case .success = result {
				expectation.fulfill()
			}
		}

		waitForExpectations(timeout: 10)
	}

	// MARK: - Batch flushed when maxBatchSize (100) is reached

	func testBatchFlushedWhenMaxBatchSizeReached() {
		let expectation = self.expectation(description: #function)
		expectation.expectedFulfillmentCount = 100
		publisher.publishEventBatchPromise.resolve(Void())

		for i in 0..<100 {
			queue.publishEvent(
				event: PublishableUserEvent(
					name: "batch_event_\(i)",
					sessionId: "s",
					dimensions: [:],
					value: Double(i),
					unit: .count,
					currency: nil,
					happenedAt: nil
				)
			).observe { result in
				if case .success = result {
					expectation.fulfill()
				}
			}
		}

		waitForExpectations(timeout: 10)
	}

	// MARK: - restorePreservedEvents db-mismatch path logs an error

	func testRestorePreservedEventsLogsDatabaseMismatch() {
		let mockLogger = MockHttpLogger()

		// SingleReadEventStore returns one event then nil — simulates a non-empty store
		// while the fresh SQLite driver returns [] — causing a mismatch log.
		let seedEvent = StorableEvent(
			id: 1,
			event: PublishableUserEvent(
				name: "seeded",
				sessionId: "s",
				dimensions: [:],
				value: 1.0,
				unit: .count,
				currency: nil,
				happenedAt: nil
			),
			sequenceNumber: 0
		)

		let localQueue = PublishEventsQueue(
			connectivityManager: nil,
			eventStore: SingleReadEventStore(event: seedEvent),
			logger: mockLogger,
			publisher: MockEventPublisher(),
			queue: dispatchQueue,
			sequenceNumberProvider: MockSequenceNumberProvider(),
			sqliteDriver: try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)"),
			sdkVersionProvider: { VersionImpl(major: 1, minor: 0, patch: 0, name: "1.0.0") }
		)
		_ = localQueue  // ensure init runs

		// Wait for the async init work (restorePreservedEvents) to finish
		let syncExpectation = self.expectation(description: "init async block finished")
		dispatchQueue.async {
			syncExpectation.fulfill()
		}
		waitForExpectations(timeout: 5)

		// An error entry must have been logged due to the db ↔ store mismatch
		XCTAssertTrue(
			mockLogger.entries.contains { $0.level == .error },
			"Expected an error entry in logger due to db/store mismatch"
		)
	}

	private var provideSdkVersionCallsNumber = -1

	private func provideSdkVersion() -> any Version {
		provideSdkVersionCallsNumber += 1
		if provideSdkVersionCallsNumber < sdkVersions.count {
			return sdkVersions[provideSdkVersionCallsNumber]
		}
		return VersionImpl(major: 4, minor: 1, patch: 0, name: "4.1.0")
	}
}

class NopSessionManager: SessionManager {
	func start() {
	}

	func moveToForeground() {
	}

	func moveToBackground() {
	}

	func getLastSessionId(_ sdkRef: JustTrackSdkImpl) -> String {
		return "sessionId"
	}

	func saveSession() {
	}
}

class TestUserEventsHttpClient: AttributionApi, PrivacyApi, EventApi, LogApi, UserPropertyApi, RemoteConfigApi {
	let attributionApi: AttributionApi
	let privacyApi: PrivacyApi
	let eventApi: EventApi
	let logApi: LogApi
	let userPropertyApi: UserPropertyApi
	let remoteConfigApi: RemoteConfigApi
	var remainingFails: Int
	var publishedEvents: [String]

	init(httpClient: HttpClientImpl, requestFactory: RequestFactory, remainingFails: Int) {
		self.attributionApi = AttributionApiImpl(httpClient: httpClient, requestFactory: requestFactory, retryConfig: httpClient.retryConfig)
		self.privacyApi = PrivacyApiImpl(httpClient: httpClient, requestFactory: requestFactory)
		self.eventApi = EventApiImpl(httpClient: httpClient, requestFactory: requestFactory, retryConfig: httpClient.retryConfig, logger: LoggerImpl())
		self.logApi = LogApiImpl(httpClient: httpClient, requestFactory: requestFactory)
		self.userPropertyApi = UserPropertyApiImpl(httpClient: httpClient, requestFactory: requestFactory)
		self.remoteConfigApi = RemoteConfigApiImpl(httpClient: httpClient, requestFactory: requestFactory)
		self.remainingFails = remainingFails
		self.publishedEvents = []
	}

	// MARK: AttributionApi

	func sendAttributionRequest(request: DTOAttributionRequest, userData: UserData) -> Future<Data> {
		return attributionApi.sendAttributionRequest(request: request, userData: userData)
	}

	func sendAnonymizeRequest(request: DTOAnonymizeRequest, userData: UserData) -> Future<Data> {
		return privacyApi.sendAnonymizeRequest(request: request, userData: userData)
	}

	func getSignedIpClaim(ipProtocol: IPProtocol, userData: UserData) -> Future<Data> {
		return attributionApi.getSignedIpClaim(ipProtocol: ipProtocol, userData: userData)
	}

	// MARK: EventApi

	func sendUserEvents(events: DTOUserEvent, userData: UserData) -> Future<Data> {
		if remainingFails > 0 {
			remainingFails -= 1

			return FutureImpl().reject(NetworkError.networkError(TestError(1)))
		}

		for event in events.events {
			publishedEvents.append(event.name)
		}

		return eventApi.sendUserEvents(events: events, userData: userData)
	}

	// MARK: LogApi

	func sendLogs(input: DTOLogInput, userData: UserData) -> Future<Data> {
		return logApi.sendLogs(input: input, userData: userData)
	}

	// MARK: UserPropertyApi

	func sendCustomUserId(request: DTOPublishCustomUserIdRequest, userData: UserData) -> Future<Data> {
		XCTFail("Unexpected call to publish a Custom user id")

		return userPropertyApi.sendCustomUserId(request: request, userData: userData)
	}

	func sendFirebaseAppInstanceId(request: DTOPublishFirebaseAppInstanceIdRequest, userData: UserData) -> Future<Data> {
		XCTFail("Unexpected call to publish a Firebase app instance id")

		return userPropertyApi.sendFirebaseAppInstanceId(request: request, userData: userData)
	}

	// MARK: RemoteConfigApi

	func sendSetExperimentVariant(request: DTOSetExperimentVariantRequest, userData: UserData) -> Future<Data> {
		return remoteConfigApi.sendSetExperimentVariant(request: request, userData: userData)
	}

	func getAssignments(parameters: GetAssignmentsParameters, userData: UserData) -> Future<AssignmentsResponse> {
		return remoteConfigApi.getAssignments(parameters: parameters, userData: userData)
	}

	func postEnrollments(request: DTOPostEnrollmentRequest, userData: UserData) -> Future<Data> {
		return remoteConfigApi.postEnrollments(request: request, userData: userData)
	}
}

class TestOfflineHttpClient: AttributionApi, PrivacyApi, EventApi, LogApi, UserPropertyApi, RemoteConfigApi {
	private let attributionApi: AttributionApi
	private let logApi: LogApi
	private let userPropertyApi: UserPropertyApi
	private let remoteConfigApi: RemoteConfigApi
	private var failedPublishCount: Int = 0
	private var onFailedPublishData: (Int, () -> Void)? = nil
	private var failedToPublishEventIds: [String: Int] = [:]

	init(httpClient: HttpClientImpl, requestFactory: RequestFactory) {
		self.attributionApi = AttributionApiImpl(httpClient: httpClient, requestFactory: requestFactory, retryConfig: httpClient.retryConfig)
		self.logApi = LogApiImpl(httpClient: httpClient, requestFactory: requestFactory)
		self.userPropertyApi = UserPropertyApiImpl(httpClient: httpClient, requestFactory: requestFactory)
		self.remoteConfigApi = RemoteConfigApiImpl(httpClient: httpClient, requestFactory: requestFactory)
	}

	func onFailedPublish(_ count: Int, _ callback: @escaping () -> Void) {
		self.onFailedPublishData = (count, callback)
	}

	// MARK: AttributionApi

	func sendAttributionRequest(request: DTOAttributionRequest, userData: UserData) -> Future<Data> {
		return attributionApi.sendAttributionRequest(request: request, userData: userData)
	}

	func sendAnonymizeRequest(request: DTOAnonymizeRequest, userData: UserData) -> Future<Data> {
		return FutureImpl().resolve(Data())
	}

	func getSignedIpClaim(ipProtocol: IPProtocol, userData: UserData) -> Future<Data> {
		return FutureImpl().reject(NetworkError.networkError(TestError(1)))
	}

	// MARK: EventApi

	func sendUserEvents(events: DTOUserEvent, userData: UserData) -> Future<Data> {
		if let (count, onFailedPublish) = self.onFailedPublishData {
			if failedPublishCount < count && failedPublishCount + events.events.count >= count {
				onFailedPublish()
				self.onFailedPublishData = nil
			}
		}
		failedPublishCount += events.events.count
		LoggerImpl().debug("Offline client prevented \(failedPublishCount) events from publishing")

		for event in events.events {
			if let publishCount = failedToPublishEventIds[event.id] {
				failedToPublishEventIds[event.id] = publishCount + 1
			} else {
				failedToPublishEventIds[event.id] = 1
			}
		}

		return FutureImpl().reject(NetworkError.networkError(TestError(1)))
	}

	// MARK: LogApi

	func sendLogs(input: DTOLogInput, userData: UserData) -> Future<Data> {
		return FutureImpl().reject(NetworkError.networkError(TestError(1)))
	}

	// MARK: UserPropertyApi

	func sendCustomUserId(request: DTOPublishCustomUserIdRequest, userData: UserData) -> Future<Data> {
		return FutureImpl().reject(NetworkError.networkError(TestError(1)))
	}

	func sendFirebaseAppInstanceId(request: DTOPublishFirebaseAppInstanceIdRequest, userData: UserData) -> Future<Data> {
		return FutureImpl().reject(NetworkError.networkError(TestError(1)))
	}

	// MARK: RemoteConfigApi

	func sendSetExperimentVariant(request: DTOSetExperimentVariantRequest, userData: UserData) -> Future<Data> {
		return FutureImpl().reject(NetworkError.networkError(TestError(1)))
	}

	func getAssignments(parameters: GetAssignmentsParameters, userData: UserData) -> Future<AssignmentsResponse> {
		return FutureImpl().reject(NetworkError.networkError(TestError(1)))
	}

	func postEnrollments(request: DTOPostEnrollmentRequest, userData: UserData) -> Future<Data> {
		return FutureImpl().reject(NetworkError.networkError(TestError(1)))
	}
}

final class ExpectedEventsHolder {
	private(set) var events = [String]()

	func add(_ event: String) {
		objc_sync_enter(self)
		events.append(event)
		objc_sync_exit(self)
	}
}

/// An EventStoring implementation that returns `event` exactly once from readStoredEvent,
/// then nil on subsequent calls. Used to simulate a non-empty store without looping forever.
final class SingleReadEventStore: EventStoring {
	private var pending: StorableEvent?
	private var nextId = 0

	init(event: StorableEvent) {
		self.pending = event
	}

	func readStoredEvent() -> StorableEvent? {
		defer { pending = nil }
		return pending
	}

	func getNextId() -> Int {
		nextId += 1
		return nextId
	}

	func storeEvent(event: StorableEvent) {}
	func removeEvent(event: StorableEvent) {}
}
