import Foundation
import XCTest

@testable import JustTrackSDK

final class PublishEventsQueueTests: XCTestCase {
	private var connectivityManager = MockConnectivityManager()
	private var eventStore: EventStoring = EventStore()
	private var logger = MockHttpLogger()
	private var publisher = MockEventPublisher()
	private var dispatchQueue: DispatchQueue = DispatchQueue(label: "io.justtrack.PublishEventsQueue.queue", qos: .userInteractive)
	private var sequenceNumberProvider: SequenceNumberProvider = MockSequenceNumberProvider()
	private var sqliteDriver = try! DefaultSqliteDriver(databaseName: "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)")
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

	func testPublishEventSimple() {
		JustTrack.resetForTesting(clearStorage: true)
		let httpClient = HttpClientImpl(
			platformType: .native,
			apiToken: JustTrackSdkTests.apiToken,
			retryConfig: RetryConfig.defaultConfig,
			urlSession: URLSession.shared,
			clientId: JustTrackSdkTests.clientId
		)
		let testClient = TestUserEventsHttpClient(httpClient: httpClient, remainingFails: 0)
		let sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: testClient,
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
		JustTrack.resetForTesting(clearStorage: true)
		let testClient = TestUserEventsHttpClient(
			httpClient: HttpClientImpl(
				platformType: .native,
				apiToken: JustTrackSdkTests.apiToken,
				retryConfig: RetryConfig.defaultConfig,
				urlSession: URLSession.shared,
				clientId: JustTrackSdkTests.clientId
			),
			remainingFails: 5
		)
		let sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: testClient,
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
		JustTrack.resetForTesting(clearStorage: true)

		let testClient = TestUserEventsHttpClient(
			httpClient: HttpClientImpl(
				platformType: .native,
				apiToken: JustTrackSdkTests.apiToken,
				retryConfig: RetryConfig.defaultConfig,
				urlSession: URLSession.shared,
				clientId: JustTrackSdkTests.clientId
			),
			remainingFails: 0
		)

		let sdk = try! JustTrackSdkImpl(
			attributionSettings: AttributionSettings(),
			logger: LoggerImpl(),
			httpClient: testClient,
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
		JustTrack.resetForTesting(clearStorage: true)
		provideSdkVersionCallsNumber = -1

		let events = [
			PublishableUserEvent(name: "event_1", sessionId: "session_1", dimensions: [:], value: 41, unit: .count, currency: nil, happenedAt: Date()),
			PublishableUserEvent(name: "event_2", sessionId: "session_1", dimensions: [:], value: 42, unit: .count, currency: nil, happenedAt: Date()),
			PublishableUserEvent(name: "event_3", sessionId: "session_2", dimensions: [:], value: 11, unit: .milliseconds, currency: nil, happenedAt: Date()),
		]

		_ = queue
		publisher.calls = []
		publisher.publishEventBatchPromise.resolve(Void())

		_ = queue.publishEvent(event: events[0])
		_ = queue.publishEvent(event: events[1])
		_ = queue.publishEvent(event: events[2])

		let expectation = self.expectation(description: #function)

		publishEventsGlobalQueue.asyncAfter(deadline: .now() + 7) { [self] in
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

			expectation.fulfill()
		}

		waitForExpectations(timeout: 10)
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

class TestUserEventsHttpClient: HttpClient {
	let httpClient: HttpClient
	var remainingFails: Int
	var publishedEvents: [String]

	init(httpClient: HttpClient, remainingFails: Int) {
		self.httpClient = httpClient
		self.remainingFails = remainingFails
		self.publishedEvents = []
	}

	func sendAttributionRequest(request: DTOAttributionRequest, userData: UserData) -> Future<Data> {
		// pass through, we need an attribution
		return httpClient.sendAttributionRequest(request: request, userData: userData)
	}

	func sendUserEvents(events: DTOUserEvent, userData: UserData) -> Future<Data> {
		if remainingFails > 0 {
			remainingFails -= 1

			return FutureImpl().reject(NetworkError.networkError(TestError(1)))
		}

		for event in events.events {
			publishedEvents.append(event.name)
		}

		return httpClient.sendUserEvents(events: events, userData: userData)
	}

	func sendCustomUserId(request: DTOPublishCustomUserIdRequest, userData: UserData) -> Future<Data> {
		XCTFail("Unexpected call to publish a Custom user id")

		return httpClient.sendCustomUserId(request: request, userData: userData)
	}

	func sendFirebaseAppInstanceId(request: DTOPublishFirebaseAppInstanceIdRequest, userData: UserData) -> Future<Data> {
		XCTFail("Unexpected call to publish a Firebase app instance id")

		return httpClient.sendFirebaseAppInstanceId(request: request, userData: userData)
	}

	func sendLogs(input: DTOLogInput, userData: UserData) -> Future<Data> {
		return httpClient.sendLogs(input: input, userData: userData)
	}

	func getSignedIpClaim(ipProtocol: IPProtocol, userData: UserData) -> Future<Data> {
		// needed for an attribution
		return httpClient.getSignedIpClaim(ipProtocol: ipProtocol, userData: userData)
	}

	func setRules(eventConfig: AttributionOutputSdkConfig.Event) {
	}

	func sendAnonymizeRequest(request: DTOAnonymizeRequest, userData: UserData) -> Future<Data> {
		return FutureImpl().resolve(Data())
	}

	func sendSetExperimentVariant(request: DTOSetExperimentVariantRequest, userData: UserData) -> Future<Data> {
		return httpClient.sendSetExperimentVariant(request: request, userData: userData)
	}

	func getAssignments(parameters: GetAssignmentsParameters, userData: UserData) -> Future<AssignmentsResponse> {
		return httpClient.getAssignments(parameters: parameters, userData: userData)
	}

	func postEnrollments(request: DTOPostEnrollmentRequest, userData: UserData) -> Future<Data> {
		return httpClient.postEnrollments(request: request, userData: userData)
	}
}

class TestOfflineHttpClient: HttpClient {
	private let httpClient: HttpClient
	private var failedPublishCount: Int = 0
	private var onFailedPublishData: (Int, () -> Void)? = nil
	private var failedToPublishEventIds: [String: Int] = [:]

	init(httpClient: HttpClient) {
		self.httpClient = httpClient
	}

	func onFailedPublish(_ count: Int, _ callback: @escaping () -> Void) {
		self.onFailedPublishData = (count, callback)
	}

	func sendAttributionRequest(request: DTOAttributionRequest, userData: UserData) -> Future<Data> {
		// pass through, we need an attribution
		return httpClient.sendAttributionRequest(request: request, userData: userData)
	}

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

	func sendCustomUserId(request: DTOPublishCustomUserIdRequest, userData: UserData) -> Future<Data> {
		return FutureImpl().reject(NetworkError.networkError(TestError(1)))
	}

	func sendFirebaseAppInstanceId(request: DTOPublishFirebaseAppInstanceIdRequest, userData: UserData) -> Future<Data> {
		return FutureImpl().reject(NetworkError.networkError(TestError(1)))
	}

	func sendLogs(input: DTOLogInput, userData: UserData) -> Future<Data> {
		return FutureImpl().reject(NetworkError.networkError(TestError(1)))
	}

	func getSignedIpClaim(ipProtocol: IPProtocol, userData: UserData) -> Future<Data> {
		return FutureImpl().reject(NetworkError.networkError(TestError(1)))
	}

	func setRules(eventConfig: AttributionOutputSdkConfig.Event) {
		httpClient.setRules(eventConfig: eventConfig)
	}

	func sendAnonymizeRequest(request: DTOAnonymizeRequest, userData: UserData) -> Future<Data> {
		return FutureImpl().resolve(Data())
	}

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
