import XCTest

@testable import JustTrackSDK

final class DefaultAnrDetectorTests: XCTestCase {
	private var logger: MockHttpLogger!
	private var detector: DefaultAnrDetector!

	override func setUp() {
		super.setUp()
		logger = MockHttpLogger()
		// skipMonitoringForTesting prevents performMonitoring from blocking the
		// queue with its semaphore wait, allowing syncForTesting() to drain safely.
		detector = DefaultAnrDetector(checkInterval: 4, threshold: 2, logger: logger, skipMonitoringForTesting: true)
	}

	override func tearDown() {
		// Nil out the handler directly so tearDown does not need to drain the queue
		detector.anrHandler = nil
		detector = nil
		logger = nil
		super.tearDown()
	}

	// MARK: - init

	func testInitDoesNotCrash() {
		let localLogger = MockHttpLogger()
		let localDetector = DefaultAnrDetector(checkInterval: 4, threshold: 2, logger: localLogger, skipMonitoringForTesting: true)
		XCTAssertNotNil(localDetector)
	}

	// MARK: - handleReport: filtering

	func testHandleReportCallsHandlerWhenCallPackageMatchesSDK() {
		var called = false
		detector.anrHandler = { _ in called = true }

		detector.handleReport(makeReport(packages: [String.sdkPackageName]))

		XCTAssertTrue(called, "Handler should be called when a call's package matches the SDK name")
	}

	func testHandleReportDoesNotCallHandlerWhenNoCallMatchesSDK() {
		var called = false
		detector.anrHandler = { _ in called = true }

		detector.handleReport(makeReport(packages: ["SomeOtherFramework", "AnotherLib"]))

		XCTAssertFalse(called, "Handler should not be called when no call's package matches the SDK name")
	}

	func testHandleReportCallsHandlerExactlyOnceWithMultipleMatchingCallsInOneStack() {
		var callCount = 0
		detector.anrHandler = { _ in callCount += 1 }

		let report = AnrReport(
			timestamp: Date(),
			callStacks: [
				AnrReport.CallStack(
					threadId: "main",
					calls: [
						AnrReport.CallStack.Call(address: "0x1", package: String.sdkPackageName),
						AnrReport.CallStack.Call(address: "0x2", package: String.sdkPackageName),
					]
				)
			]
		)
		detector.handleReport(report)

		XCTAssertEqual(callCount, 1, "Handler should be called exactly once even when multiple calls match")
	}

	func testHandleReportCallsHandlerExactlyOnceAcrossMultipleCallStacks() {
		var callCount = 0
		detector.anrHandler = { _ in callCount += 1 }

		let report = AnrReport(
			timestamp: Date(),
			callStacks: [
				AnrReport.CallStack(
					threadId: "main",
					calls: [AnrReport.CallStack.Call(address: "0x1", package: String.sdkPackageName)]
				),
				AnrReport.CallStack(
					threadId: "background",
					calls: [AnrReport.CallStack.Call(address: "0x2", package: String.sdkPackageName)]
				),
			]
		)
		detector.handleReport(report)

		XCTAssertEqual(callCount, 1, "Handler should be called exactly once even across multiple call stacks")
	}

	func testHandleReportPassesOriginalReportToHandler() {
		let expectedTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
		var receivedReport: AnrReport?
		detector.anrHandler = { report in receivedReport = report }

		let report = AnrReport(
			timestamp: expectedTimestamp,
			callStacks: [
				AnrReport.CallStack(
					threadId: "main",
					calls: [AnrReport.CallStack.Call(address: "0x1", package: String.sdkPackageName)]
				)
			]
		)
		detector.handleReport(report)

		XCTAssertEqual(
			receivedReport?.timestamp.timeIntervalSince1970,
			expectedTimestamp.timeIntervalSince1970,
			"Handler should receive the original AnrReport"
		)
	}

	func testHandleReportWithEmptyCallStacksDoesNotCallHandler() {
		var called = false
		detector.anrHandler = { _ in called = true }

		detector.handleReport(AnrReport(timestamp: Date(), callStacks: []))

		XCTAssertFalse(called, "Handler should not be called when callStacks is empty")
	}

	func testHandleReportWithEmptyCallsInStackDoesNotCallHandler() {
		var called = false
		detector.anrHandler = { _ in called = true }

		let report = AnrReport(
			timestamp: Date(),
			callStacks: [AnrReport.CallStack(threadId: "main", calls: [])]
		)
		detector.handleReport(report)

		XCTAssertFalse(called, "Handler should not be called when all call stacks have no calls")
	}

	func testHandleReportWhenHandlerIsNilDoesNotCrash() {
		// anrHandler is nil by default; must not crash
		detector.handleReport(makeReport(packages: [String.sdkPackageName]))
	}

	// MARK: - handleReport: logError

	func testHandleReportLogsErrorWhenSDKCallIsFound() {
		detector.anrHandler = { _ in }

		detector.handleReport(makeReport(packages: [String.sdkPackageName]))

		let errorEntries = logger.entries.filter { $0.level == .error }
		XCTAssertFalse(errorEntries.isEmpty, "An error should be logged when an ANR is detected")
		XCTAssertTrue(
			errorEntries.contains { $0.message.contains("<DefaultAnrDetector>") },
			"Error log message should contain '<DefaultAnrDetector>' prefix"
		)
	}

	func testHandleReportDoesNotLogErrorWhenNoSDKCallIsFound() {
		detector.anrHandler = { _ in }

		detector.handleReport(makeReport(packages: ["UnrelatedFramework"]))

		let errorEntries = logger.entries.filter { $0.level == .error }
		XCTAssertTrue(
			errorEntries.allSatisfy { !$0.message.contains("ANR detected") },
			"No ANR-detected error should be logged when no SDK call is in the report"
		)
	}

	// MARK: - setHandler

	func testSetHandlerSetsAnrHandler() {
		XCTAssertNil(detector.anrHandler, "anrHandler should be nil before setHandler is called")

		detector.setHandler { _ in }
		detector.syncForTesting()

		XCTAssertNotNil(detector.anrHandler, "anrHandler should be set after setHandler is called")
	}

	func testSetHandlerCalledTwiceUpdatesAnrHandler() {
		var firstCalled = false
		var secondCalled = false

		detector.setHandler { _ in firstCalled = true }
		detector.syncForTesting()

		detector.setHandler { _ in secondCalled = true }
		detector.syncForTesting()

		detector.handleReport(makeReport(packages: [String.sdkPackageName]))

		XCTAssertFalse(firstCalled, "First handler should have been replaced and not called")
		XCTAssertTrue(secondCalled, "Second handler should be the active one")
	}

	// MARK: - removeHandler (via queue)

	func testRemoveHandlerNilsAnrHandler() {
		detector.anrHandler = { _ in }
		XCTAssertNotNil(detector.anrHandler)

		detector.removeHandler()
		detector.syncForTesting()

		XCTAssertNil(detector.anrHandler, "removeHandler should nil out anrHandler")
	}

	func testHandleReportLogMessageContainsThreshold() {
		detector.anrHandler = { _ in }

		detector.handleReport(makeReport(packages: [String.sdkPackageName]))

		let errorEntries = logger.entries.filter { $0.level == .error }
		XCTAssertTrue(
			errorEntries.contains { $0.message.contains("2.0") || $0.message.contains("2") },
			"Error log message should contain the configured threshold value"
		)
	}

	// MARK: - Helpers

	private func makeReport(packages: [String]) -> AnrReport {
		let calls = packages.enumerated().map { index, pkg in
			AnrReport.CallStack.Call(
				address: String(format: "0x%016llx", index + 1),
				package: pkg
			)
		}
		return AnrReport(
			timestamp: Date(),
			callStacks: [AnrReport.CallStack(threadId: "main", calls: calls)]
		)
	}
}
