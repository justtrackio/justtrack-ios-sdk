import Foundation
import XCTest

@testable import JustTrackSDK

final class PeriodicLogsPublisherTests: XCTestCase {
	// MARK: - stop() immediately halts scheduling without crash

	func testStopPreventsSubsequentSendToServerCalls() {
		// After stop(), the scheduled handle should see .stopped and return early (the
		// "already stopped" debug log path). We verify no extra sendToServer calls arrive.
		let mockLogger = MockLogger()
		let mockHttpLogger = MockHttpLogger()

		let publisher = PeriodicLogsPublisher(fallback: mockLogger, httpLogger: mockHttpLogger)
		publisher.stop()

		let noCallExp = expectation(description: "no sendToServer after stop")
		noCallExp.isInverted = true
		mockHttpLogger.onSendToServer = {
			noCallExp.fulfill()
		}

		// Wait long enough for the init-scheduled (5s) handle to fire
		// but state is .stopped so it returns early — no call expected
		waitForExpectations(timeout: 6)
	}

	// MARK: - pause() calls sendToServer immediately

	func testPauseCallsSendToServer() {
		let mockLogger = MockLogger()
		let mockHttpLogger = MockHttpLogger()

		let publisher = PeriodicLogsPublisher(fallback: mockLogger, httpLogger: mockHttpLogger)
		// Immediately stop so the init-scheduled timer doesn't interfere
		publisher.stop()

		let pauseExp = expectation(description: "pause sendToServer")
		pauseExp.assertForOverFulfill = false
		mockHttpLogger.onSendToServer = {
			pauseExp.fulfill()
		}

		publisher.pause()

		waitForExpectations(timeout: 3)
	}

	// MARK: - pause() transitions to stopped after 1s

	func testPauseTransitionsToStopped() {
		// This test verifies that handle() sees .stopping and transitions to .stopped.
		// We observe: after pause(), a second sendToServer() coming from the scheduled
		// handle(). After the transition state == .stopping → .stopped, subsequent
		// handle calls see .stopped and log "already stopped".
		let mockLogger = MockLogger()
		let mockHttpLogger = MockHttpLogger()

		let publisher = PeriodicLogsPublisher(fallback: mockLogger, httpLogger: mockHttpLogger)
		publisher.stop()

		var callCount = 0
		let exp = expectation(description: "handle fires after pause")
		mockHttpLogger.onSendToServer = {
			callCount += 1
			if callCount >= 2 {
				exp.fulfill()
			}
		}

		publisher.pause()  // immediate sendToServer (count=1) + schedules handle after 1s (count=2)

		waitForExpectations(timeout: 3)
		XCTAssertGreaterThanOrEqual(callCount, 2)
	}
}
