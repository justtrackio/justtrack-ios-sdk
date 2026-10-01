import XCTest

@testable import JustTrackSDK

class EventTests: XCTestCase {
	func testCorrectEventsPublished() {
		withAllStates { stateName, expectedEvents in
			let databaseName = "JustTrackSDK_DefaultSqliteDriver_Database_\(UUID().uuidString)"
			var publishedEvents: [String] = []
			var sessionIds: [String] = []
			let expectation = self.expectation(description: #function)
			let httpClient = TestAttributionHttpClient(changeInstallId: false) { events in
				for event in events.events {
					sessionIds.append(event.sessionId)
					publishedEvents.append(event.name)
				}
				if publishedEvents.count == expectedEvents.count {
					expectation.fulfill()
				}
			}
			let sdk = try! JustTrackSdkImpl(
				attributionSettings: AttributionSettings(),
				logger: LoggerImpl(),
				httpClient: StubHttpClient(),
				attributionApi: httpClient,
				privacyApi: httpClient,
				eventApi: httpClient,
				logApi: httpClient,
				userPropertyApi: httpClient,
				remoteConfigApi: httpClient,
				sessionManagerBuilder: SessionManagerImpl.init,
				connectivityManagerBuilder: { _ in nil },
				adTrackingProvider: TestAdTrackingProvider(idfa: JustTrackSdkTests.idfa, idfv: JustTrackSdkTests.idfv),
				skAdNetwork: MockSkAdNetwork.self,
				adTrackingEventPublisher: MockAdTrackingEventPublisher(),
				sqliteDriver: DefaultSqliteDriver(databaseName: databaseName),
				config: .default,
				manualStart: true
			)
			sdk.start()
			sdk.moveToForeground()
			let f = sdk.track(event: AppEvent("custom_event_name"))
			f.observe { _ in
				sdk.moveToBackground()
			}

			waitForExpectations(timeout: 20)
			sdk.shutdown()

			XCTAssertEqual(publishedEvents, expectedEvents, "Missing or additional event when running with state \(stateName)")
			XCTAssertEqual(publishedEvents.count, sessionIds.count)
			for (index, sessionId) in sessionIds.enumerated() {
				XCTAssertEqual(sessionId, sessionIds[0], "Wrong session id on event \(index) \(publishedEvents[index])")
			}
		}
	}

	func withAllStates(_ f: (_ stateName: String, _ expectedEvents: [String]) -> Void) {
		// reset and remove all data for the first run
		JustTrack.resetForTesting(clearStorage: true)
		// execute on an empty store
		f(
			"Clean",
			[
				JtSessionTrackingEvent.name,
				JtAppOpenEvent.name,
				JtAppInstallEvent.name,
				"custom_event_name",
				JtSessionTrackingEvent.name,

			]
		)
		// execute with the store with the result from the first call, i.e., a filled store
		// but reset the stuff we hold in memory
		JustTrack.resetForTesting(clearStorage: false)
		f(
			"Restarted",
			[
				JtSessionTrackingEvent.name,
				JtAppOpenEvent.name,
				"custom_event_name",
				JtSessionTrackingEvent.name,
			]
		)
		// change the version of the app so we trigger an update event
		JustTrack.resetForTesting(clearStorage: false)
		var dict = [String: Any]()
		dict["major"] = 0
		dict["minor"] = 0
		dict["name"] = "0.0-Testing"
		UserDefaults.standard.set(dict, forKey: Store.currentAppVersionKey)
		f(
			"Updated",
			[
				JtSessionTrackingEvent.name,
				JtAppOpenEvent.name,
				"custom_event_name",
				JtSessionTrackingEvent.name,
			]
		)
	}
}
