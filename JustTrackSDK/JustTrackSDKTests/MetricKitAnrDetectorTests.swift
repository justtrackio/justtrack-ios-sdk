import XCTest

@testable import JustTrackSDK

final class MetricKitAnrDetectorTests: XCTestCase {
	private var processor: MetricKitAnrReportProcessor!

	override func setUp() {
		super.setUp()
		processor = MetricKitAnrReportProcessor()
	}

	override func tearDown() {
		processor = nil
		super.tearDown()
	}

	// MARK: - extractCallsFromJSON

	func testExtractCallsFromJSONReturnsEmptyCallsWhenJSONHasNoCallStacks() {
		let report = processor.extractCallsFromJSON([:])
		XCTAssertEqual(report.callStacks.count, 1)
		XCTAssertTrue(report.callStacks[0].calls.isEmpty)
	}

	func testExtractCallsFromJSONReturnsEmptyCallsWhenCallStacksIsEmpty() {
		let json: [String: Any] = ["callStacks": []]
		let report = processor.extractCallsFromJSON(json)
		XCTAssertTrue(report.callStacks[0].calls.isEmpty)
	}

	func testExtractCallsFromJSONReturnsEmptyCallsWhenRootFramesIsMissing() {
		let json: [String: Any] = ["callStacks": [["otherKey": "value"]]]
		let report = processor.extractCallsFromJSON(json)
		XCTAssertTrue(report.callStacks[0].calls.isEmpty)
	}

	func testExtractCallsFromJSONParsesAddressAndBinaryName() {
		let json = makeJSON(frames: [
			["address": 0x1000, "binaryName": "MyApp", "offsetIntoBinaryTextSegment": 0x10]
		])
		let report = processor.extractCallsFromJSON(json)
		let calls = report.callStacks[0].calls
		XCTAssertEqual(calls.count, 1)
		XCTAssertEqual(calls[0].address, "0x1000")
		XCTAssertEqual(calls[0].package, "MyApp")
		XCTAssertEqual(calls[0].addressOffset, "0x10")
	}

	func testExtractCallsFromJSONUsesFallbacksForMissingFields() {
		let json = makeJSON(frames: [[:]])
		let report = processor.extractCallsFromJSON(json)
		let calls = report.callStacks[0].calls
		XCTAssertEqual(calls.count, 1)
		XCTAssertEqual(calls[0].address, "0x0")
		XCTAssertEqual(calls[0].package, "Unknown")
		XCTAssertEqual(calls[0].addressOffset, "0x0")
	}

	func testExtractCallsFromJSONParsesMultipleRootFrames() {
		let json = makeJSON(frames: [
			["address": 0x1000, "binaryName": "FrameA"],
			["address": 0x2000, "binaryName": "FrameB"],
			["address": 0x3000, "binaryName": "FrameC"],
		])
		let report = processor.extractCallsFromJSON(json)
		let calls = report.callStacks[0].calls
		XCTAssertEqual(calls.count, 3)
		XCTAssertEqual(calls[0].package, "FrameA")
		XCTAssertEqual(calls[1].package, "FrameB")
		XCTAssertEqual(calls[2].package, "FrameC")
	}

	func testExtractCallsFromJSONUsesOnlyFirstCallStack() {
		let json: [String: Any] = [
			"callStacks": [
				["callStackRootFrames": [["address": 0x1000, "binaryName": "FirstStack"]]],
				["callStackRootFrames": [["address": 0x2000, "binaryName": "SecondStack"]]],
			]
		]
		let report = processor.extractCallsFromJSON(json)
		let calls = report.callStacks[0].calls
		XCTAssertEqual(calls.count, 1)
		XCTAssertEqual(calls[0].package, "FirstStack")
	}

	func testExtractCallsFromJSONSetsThreadIdToOne() {
		let report = processor.extractCallsFromJSON([:])
		XCTAssertEqual(report.callStacks[0].threadId, "1")
	}

	// MARK: - extractCallsFromFrame (subframes)

	func testExtractCallsFromFrameRecursesIntoFirstSubFrameOnly() {
		let frame: [String: Any] = [
			"address": 0x1000,
			"binaryName": "Parent",
			"subFrames": [
				["address": 0x2000, "binaryName": "Child"],
				["address": 0x3000, "binaryName": "SecondChild"],  // should be ignored
			],
		]
		var calls = [AnrReport.CallStack.Call]()
		processor.extractCallsFromFrame(frame, into: &calls)
		XCTAssertEqual(calls.count, 2, "Should include parent and first subframe only")
		XCTAssertEqual(calls[0].package, "Parent")
		XCTAssertEqual(calls[1].package, "Child")
	}

	func testExtractCallsFromFrameHandlesDeepNesting() {
		let frame: [String: Any] = [
			"address": 0x1000,
			"binaryName": "Level1",
			"subFrames": [
				[
					"address": 0x2000,
					"binaryName": "Level2",
					"subFrames": [
						["address": 0x3000, "binaryName": "Level3"]
					],
				]
			],
		]
		var calls = [AnrReport.CallStack.Call]()
		processor.extractCallsFromFrame(frame, into: &calls)
		XCTAssertEqual(calls.count, 3)
		XCTAssertEqual(calls[0].package, "Level1")
		XCTAssertEqual(calls[1].package, "Level2")
		XCTAssertEqual(calls[2].package, "Level3")
	}

	func testExtractCallsFromFrameWithNoSubFrames() {
		let frame: [String: Any] = ["address": 0x1000, "binaryName": "Leaf"]
		var calls = [AnrReport.CallStack.Call]()
		processor.extractCallsFromFrame(frame, into: &calls)
		XCTAssertEqual(calls.count, 1)
		XCTAssertEqual(calls[0].package, "Leaf")
	}

	func testExtractCallsFromFrameWithEmptySubFrames() {
		let frame: [String: Any] = ["address": 0x1000, "binaryName": "Leaf", "subFrames": []]
		var calls = [AnrReport.CallStack.Call]()
		processor.extractCallsFromFrame(frame, into: &calls)
		XCTAssertEqual(calls.count, 1)
	}

	// MARK: - processReports

	func testProcessReportsDoesNotCrashWhenHandlerIsNil() {
		// anrHandler is nil — must not crash
		processor.processReports([makeReport(packages: [String.sdkPackageName])])
	}

	func testProcessReportsCallsHandlerOnMainThreadForMatchingReport() {
		let exp = expectation(description: "handler called on main thread")
		processor.anrHandler = { _ in
			XCTAssertTrue(Thread.isMainThread, "Handler should be dispatched on main thread")
			exp.fulfill()
		}

		processor.processReports([makeReport(packages: [String.sdkPackageName])])

		waitForExpectations(timeout: 1)
	}

	func testProcessReportsDoesNotCallHandlerWhenNoPackageMatchesSDK() {
		var called = false
		processor.anrHandler = { _ in called = true }

		processor.processReports([makeReport(packages: ["SomeOtherFramework"])])

		let drained = expectation(description: "main queue drained")
		DispatchQueue.main.async { drained.fulfill() }
		waitForExpectations(timeout: 1)

		XCTAssertFalse(called)
	}

	func testProcessReportsCallsHandlerOncePerMatchingReport() {
		var callCount = 0
		let exp = expectation(description: "handler called twice")
		exp.expectedFulfillmentCount = 2
		processor.anrHandler = { _ in
			callCount += 1
			exp.fulfill()
		}

		processor.processReports([
			makeReport(packages: [String.sdkPackageName]),
			makeReport(packages: [String.sdkPackageName]),
		])

		waitForExpectations(timeout: 1)
		XCTAssertEqual(callCount, 2)
	}

	func testProcessReportsCallsHandlerExactlyOncePerReportEvenWithMultipleMatchingCalls() {
		var callCount = 0
		let exp = expectation(description: "handler called once")
		processor.anrHandler = { _ in
			callCount += 1
			exp.fulfill()
		}

		let report = AnrReport(
			timestamp: Date(),
			callStacks: [
				AnrReport.CallStack(
					threadId: "1",
					calls: [
						AnrReport.CallStack.Call(address: "0x1", package: String.sdkPackageName),
						AnrReport.CallStack.Call(address: "0x2", package: String.sdkPackageName),
					]
				)
			]
		)
		processor.processReports([report])

		waitForExpectations(timeout: 1)
		XCTAssertEqual(callCount, 1)
	}

	func testProcessReportsPassesCorrectReportToHandler() {
		let expectedTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
		var receivedReport: AnrReport?
		let exp = expectation(description: "handler called")
		processor.anrHandler = { report in
			receivedReport = report
			exp.fulfill()
		}

		let report = AnrReport(
			timestamp: expectedTimestamp,
			callStacks: [
				AnrReport.CallStack(
					threadId: "1",
					calls: [AnrReport.CallStack.Call(address: "0x1", package: String.sdkPackageName)]
				)
			]
		)
		processor.processReports([report])

		waitForExpectations(timeout: 1)
		XCTAssertEqual(
			receivedReport?.timestamp.timeIntervalSince1970,
			expectedTimestamp.timeIntervalSince1970
		)
	}

	func testProcessReportsWithEmptyListDoesNotCallHandler() {
		var called = false
		processor.anrHandler = { _ in called = true }

		processor.processReports([])

		let drained = expectation(description: "main queue drained")
		DispatchQueue.main.async { drained.fulfill() }
		waitForExpectations(timeout: 1)

		XCTAssertFalse(called)
	}

	func testProcessReportsSkipsReportWithNoCallStacks() {
		var called = false
		processor.anrHandler = { _ in called = true }

		processor.processReports([AnrReport(timestamp: Date(), callStacks: [])])

		let drained = expectation(description: "main queue drained")
		DispatchQueue.main.async { drained.fulfill() }
		waitForExpectations(timeout: 1)

		XCTAssertFalse(called)
	}

	// MARK: - Helpers

	private func makeJSON(frames: [[String: Any]]) -> [String: Any] {
		["callStacks": [["callStackRootFrames": frames]]]
	}

	private func makeReport(packages: [String]) -> AnrReport {
		let calls = packages.enumerated().map { index, pkg in
			AnrReport.CallStack.Call(
				address: String(format: "0x%016llx", index + 1),
				package: pkg
			)
		}
		return AnrReport(
			timestamp: Date(),
			callStacks: [AnrReport.CallStack(threadId: "1", calls: calls)]
		)
	}
}
