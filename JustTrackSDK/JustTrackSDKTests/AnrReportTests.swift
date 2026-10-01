import XCTest

@testable import JustTrackSDK

final class AnrReportTests: XCTestCase {
	func testCallDefaultsOptionalFieldsToEmptyStrings() {
		let call = AnrReport.CallStack.Call(address: "0x0000000000000001")

		XCTAssertEqual(call.address, "0x0000000000000001")
		XCTAssertEqual(call.addressOffset, "")
		XCTAssertEqual(call.symbol, "")
		XCTAssertEqual(call.offset, "")
		XCTAssertEqual(call.package, "")
	}

	func testErrorFieldsIncludeTimestampAndStackTrace() {
		let report = AnrReport(
			timestamp: Date(timeIntervalSince1970: 1000),
			callStacks: [
				AnrReport.CallStack(
					threadId: "main",
					calls: [
						AnrReport.CallStack.Call(
							address: "0x0000000000000001",
							addressOffset: "0x10",
							symbol: "symbolOne",
							offset: "5",
							package: "JustTrackSDK.framework"
						),
						AnrReport.CallStack.Call(
							address: "0x0000000000000002",
							addressOffset: "0x20",
							symbol: "symbolTwo",
							offset: "8",
							package: "App.framework"
						),
					]
				)
			]
		)

		let fields = report.errorFields.getFields()

		XCTAssertEqual(fields["timestamp"], "1000.0")
		XCTAssertEqual(
			fields["stack_trace_0"],
			"Thread: main\n0 0x0000000000000001 symbolOne + 5 (JustTrackSDK.framework + 0x10)\n1 0x0000000000000002 symbolTwo + 8 (App.framework + 0x20)\n"
		)
	}

	func testErrorFieldsIncludeMultipleCallStacks() {
		let report = AnrReport(
			timestamp: Date(timeIntervalSince1970: 1000),
			callStacks: [
				AnrReport.CallStack(
					threadId: "main",
					calls: [
						AnrReport.CallStack.Call(
							address: "0x0000000000000001",
							addressOffset: "0x10",
							symbol: "mainSymbol",
							offset: "5",
							package: "JustTrackSDK.framework"
						)
					]
				),
				AnrReport.CallStack(
					threadId: "background",
					calls: [
						AnrReport.CallStack.Call(
							address: "0x0000000000000002",
							addressOffset: "0x20",
							symbol: "backgroundSymbol",
							offset: "8",
							package: "App.framework"
						)
					]
				),
			]
		)

		let fields = report.errorFields.getFields()

		XCTAssertEqual(
			fields["stack_trace_0"],
			"Thread: main\n0 0x0000000000000001 mainSymbol + 5 (JustTrackSDK.framework + 0x10)\n"
		)
		XCTAssertEqual(
			fields["stack_trace_1"],
			"Thread: background\n0 0x0000000000000002 backgroundSymbol + 8 (App.framework + 0x20)\n"
		)
	}

	func testErrorFieldsIncludeEmptyStackTraceForCallStackWithoutCalls() {
		let report = AnrReport(
			timestamp: Date(timeIntervalSince1970: 1000),
			callStacks: [
				AnrReport.CallStack(threadId: "main", calls: [])
			]
		)

		let fields = report.errorFields.getFields()

		XCTAssertEqual(fields["stack_trace_0"], "Thread: main\n")
	}
}
