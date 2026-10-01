import XCTest

@testable import JustTrackSDK

final class DefaultCrashReporterTests: XCTestCase {
	private var reporter: DefaultCrashReporter!
	private var tempDirectory: URL!

	override func setUp() {
		super.setUp()
		tempDirectory = FileManager.default.temporaryDirectory
			.appendingPathComponent("DefaultCrashReporterTests-\(UUID().uuidString)")
		try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

		reporter = DefaultCrashReporter(testFileManager: makeFileManager())
	}

	override func tearDown() {
		try? FileManager.default.removeItem(at: tempDirectory)
		reporter = nil
		tempDirectory = nil
		super.tearDown()
	}

	// MARK: - Helpers

	/// Returns a FileManager whose document directory resolves to our isolated temp folder.
	/// Since FileManager.default always returns the real Documents dir, we subclass it to
	/// redirect urls(for:in:) to the temp directory.
	private func makeFileManager() -> FileManager {
		return TempDirectoryFileManager(tempDirectory: tempDirectory)
	}

	private var crashesDir: URL {
		tempDirectory.appendingPathComponent("justtrack/crashes")
	}

	private func writtenFiles() throws -> [URL] {
		guard FileManager.default.fileExists(atPath: crashesDir.path) else { return [] }
		return try FileManager.default.contentsOfDirectory(at: crashesDir, includingPropertiesForKeys: nil)
			.filter { $0.pathExtension == "json" }
			.sorted { $0.lastPathComponent < $1.lastPathComponent }
	}

	private func decode(from url: URL) throws -> NativeCrashReport {
		let data = try Data(contentsOf: url)
		return try JSONDecoder().decode(NativeCrashReport.self, from: data)
	}

	// MARK: - saveCrashReport: exception

	func testSaveCrashReportExceptionWritesFileToCorrectPath() throws {
		let timestamp = 1_700_000_000.0
		let report = CrashReport.ExceptionReport(name: "NSException", reason: "bad access", callStack: "frame 0")

		reporter.saveCrashReport(.exception(report), timestamp: timestamp)

		let files = try writtenFiles()
		XCTAssertEqual(files.count, 1)
		XCTAssertEqual(files[0].lastPathComponent, "\(Int(timestamp)).json")
	}

	func testSaveCrashReportExceptionSetsReportTypeToException() throws {
		let report = CrashReport.ExceptionReport(name: "NSException", reason: "bad access", callStack: "frame 0")

		reporter.saveCrashReport(.exception(report), timestamp: 1_700_000_001.0)

		let stored = try decode(from: try writtenFiles()[0])
		XCTAssertEqual(stored.reportType, .exception)
	}

	func testSaveCrashReportExceptionPreservesName() throws {
		let report = CrashReport.ExceptionReport(name: "NSRangeException", reason: nil, callStack: "frame 0")

		reporter.saveCrashReport(.exception(report), timestamp: 1_700_000_002.0)

		let stored = try decode(from: try writtenFiles()[0])
		XCTAssertEqual(stored.name, "NSRangeException")
	}

	func testSaveCrashReportExceptionPreservesReason() throws {
		let report = CrashReport.ExceptionReport(name: "NSException", reason: "index out of bounds", callStack: "frame 0")

		reporter.saveCrashReport(.exception(report), timestamp: 1_700_000_003.0)

		let stored = try decode(from: try writtenFiles()[0])
		XCTAssertEqual(stored.reason, "index out of bounds")
	}

	func testSaveCrashReportExceptionWithNilReasonStoresNilReason() throws {
		let report = CrashReport.ExceptionReport(name: "NSException", reason: nil, callStack: "frame 0")

		reporter.saveCrashReport(.exception(report), timestamp: 1_700_000_004.0)

		let stored = try decode(from: try writtenFiles()[0])
		XCTAssertNil(stored.reason)
	}

	func testSaveCrashReportExceptionPreservesCallStack() throws {
		let callStack = "frame 0\nframe 1\nframe 2"
		let report = CrashReport.ExceptionReport(name: "NSException", reason: nil, callStack: callStack)

		reporter.saveCrashReport(.exception(report), timestamp: 1_700_000_005.0)

		let stored = try decode(from: try writtenFiles()[0])
		XCTAssertEqual(stored.callStack, callStack)
	}

	func testSaveCrashReportExceptionPreservesTimestamp() throws {
		let timestamp = 1_700_000_006.0
		let report = CrashReport.ExceptionReport(name: "NSException", reason: nil, callStack: "frame 0")

		reporter.saveCrashReport(.exception(report), timestamp: timestamp)

		let stored = try decode(from: try writtenFiles()[0])
		XCTAssertEqual(stored.timestamp, timestamp)
	}

	func testSaveCrashReportExceptionHasNilSignalInfo() throws {
		let report = CrashReport.ExceptionReport(name: "NSException", reason: nil, callStack: "frame 0")

		reporter.saveCrashReport(.exception(report), timestamp: 1_700_000_007.0)

		let stored = try decode(from: try writtenFiles()[0])
		XCTAssertNil(stored.signalInfo)
	}

	// MARK: - saveCrashReport: signal with info

	func testSaveCrashReportSignalSetsReportTypeToSignal() throws {
		let report = makeSignalReport()

		reporter.saveCrashReport(.signal(report), timestamp: 1_700_001_000.0)

		let stored = try decode(from: try writtenFiles()[0])
		XCTAssertEqual(stored.reportType, .signal)
	}

	func testSaveCrashReportSignalPreservesName() throws {
		let report = makeSignalReport(name: "SIGSEGV")

		reporter.saveCrashReport(.signal(report), timestamp: 1_700_001_001.0)

		let stored = try decode(from: try writtenFiles()[0])
		XCTAssertEqual(stored.name, "SIGSEGV")
	}

	func testSaveCrashReportSignalPreservesCallStack() throws {
		let callStack = "sig frame 0\nsig frame 1"
		let report = makeSignalReport(callStack: callStack)

		reporter.saveCrashReport(.signal(report), timestamp: 1_700_001_002.0)

		let stored = try decode(from: try writtenFiles()[0])
		XCTAssertEqual(stored.callStack, callStack)
	}

	func testSaveCrashReportSignalHasNilReasonAlways() throws {
		let report = makeSignalReport()

		reporter.saveCrashReport(.signal(report), timestamp: 1_700_001_003.0)

		let stored = try decode(from: try writtenFiles()[0])
		XCTAssertNil(stored.reason)
	}

	func testSaveCrashReportSignalPreservesSignalInfo() throws {
		let info = CrashReport.SignalReport.Info(
			errorNumber: "11",
			signalCode: "1",
			signalNumber: "4",
			sendingProcess: "123",
			senderRuid: "501",
			exitValue: "0",
			signalValue: "0",
			faultingAddress: "0x0000000100004000"
		)
		let report = CrashReport.SignalReport(name: "SIGILL", callStack: "frame 0", info: info)

		reporter.saveCrashReport(.signal(report), timestamp: 1_700_001_004.0)

		let stored = try decode(from: try writtenFiles()[0])
		XCTAssertNotNil(stored.signalInfo)
		XCTAssertEqual(stored.signalInfo?.errorNumber, "11")
		XCTAssertEqual(stored.signalInfo?.signalCode, "1")
		XCTAssertEqual(stored.signalInfo?.signalNumber, "4")
		XCTAssertEqual(stored.signalInfo?.sendingProcess, "123")
		XCTAssertEqual(stored.signalInfo?.senderRuid, "501")
		XCTAssertEqual(stored.signalInfo?.exitValue, "0")
		XCTAssertEqual(stored.signalInfo?.signalValue, "0")
		XCTAssertEqual(stored.signalInfo?.faultingAddress, "0x0000000100004000")
	}

	func testSaveCrashReportSignalWithNilFaultingAddressStoresNilFaultingAddress() throws {
		let info = CrashReport.SignalReport.Info(
			errorNumber: "0",
			signalCode: "0",
			signalNumber: "6",
			sendingProcess: "0",
			senderRuid: "0",
			exitValue: "0",
			signalValue: "0",
			faultingAddress: nil
		)
		let report = CrashReport.SignalReport(name: "SIGABRT", callStack: "frame 0", info: info)

		reporter.saveCrashReport(.signal(report), timestamp: 1_700_001_005.0)

		let stored = try decode(from: try writtenFiles()[0])
		XCTAssertNil(stored.signalInfo?.faultingAddress)
	}

	func testSaveCrashReportSignalWithNilInfoStoresNilSignalInfo() throws {
		let report = CrashReport.SignalReport(name: "SIGFPE", callStack: "frame 0", info: nil)

		reporter.saveCrashReport(.signal(report), timestamp: 1_700_001_006.0)

		let stored = try decode(from: try writtenFiles()[0])
		XCTAssertNil(stored.signalInfo)
	}

	// MARK: - Multiple reports

	func testSaveCrashReportMultipleReportsWriteMultipleFiles() throws {
		let report = CrashReport.ExceptionReport(name: "NSException", reason: nil, callStack: "frame 0")

		reporter.saveCrashReport(.exception(report), timestamp: 1_700_002_000.0)
		reporter.saveCrashReport(.exception(report), timestamp: 1_700_002_001.0)
		reporter.saveCrashReport(.exception(report), timestamp: 1_700_002_002.0)

		let files = try writtenFiles()
		XCTAssertEqual(files.count, 3)
	}

	// MARK: - checkNativeCrashReport round-trip

	func testCheckNativeCrashReportReadsBackSavedExceptionReport() throws {
		let report = CrashReport.ExceptionReport(name: "RoundTrip", reason: "test reason", callStack: "frame 0")
		reporter.saveCrashReport(.exception(report), timestamp: 1_700_003_000.0)

		let expectation = self.expectation(description: "report read back")
		var result: NativeCrashReport?

		reporter.checkNativeCrashReport { outcome in
			if case .success(let r) = outcome {
				result = r
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 3)
		XCTAssertEqual(result?.name, "RoundTrip")
		XCTAssertEqual(result?.reason, "test reason")
		XCTAssertEqual(result?.reportType, .exception)
	}

	func testCheckNativeCrashReportDeletesFileAfterReading() throws {
		let report = CrashReport.ExceptionReport(name: "NSException", reason: nil, callStack: "frame 0")
		reporter.saveCrashReport(.exception(report), timestamp: 1_700_003_001.0)

		let expectation = self.expectation(description: "report read back")
		reporter.checkNativeCrashReport { _ in expectation.fulfill() }
		waitForExpectations(timeout: 3)

		let remaining = try writtenFiles()
		XCTAssertEqual(remaining.count, 0)
	}

	func testCheckNativeCrashReportCallsCompletionForEachFile() throws {
		let report = CrashReport.ExceptionReport(name: "NSException", reason: nil, callStack: "frame 0")
		reporter.saveCrashReport(.exception(report), timestamp: 1_700_003_002.0)
		reporter.saveCrashReport(.exception(report), timestamp: 1_700_003_003.0)

		let expectation = self.expectation(description: "both reports delivered")
		expectation.expectedFulfillmentCount = 2
		reporter.checkNativeCrashReport { _ in expectation.fulfill() }
		waitForExpectations(timeout: 3)
	}

	func testCheckNativeCrashReportDeliversReportsInChronologicalOrder() throws {
		let report = CrashReport.ExceptionReport(name: "NSException", reason: nil, callStack: "frame 0")
		reporter.saveCrashReport(.exception(report), timestamp: 1_700_004_002.0)
		reporter.saveCrashReport(.exception(report), timestamp: 1_700_004_001.0)
		reporter.saveCrashReport(.exception(report), timestamp: 1_700_004_000.0)

		let expectation = self.expectation(description: "all reports delivered")
		expectation.expectedFulfillmentCount = 3
		var timestamps: [Double] = []
		reporter.checkNativeCrashReport { outcome in
			if case .success(let r) = outcome {
				timestamps.append(r.timestamp)
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 3)

		XCTAssertEqual(timestamps, [1_700_004_000.0, 1_700_004_001.0, 1_700_004_002.0])
	}

	func testCheckNativeCrashReportDoesNotCallCompletionWhenNoCrashesDirectoryExists() {
		// No reports written → crashes directory never created
		let expectation = self.expectation(description: "completion not called")
		expectation.isInverted = true

		reporter.checkNativeCrashReport { _ in expectation.fulfill() }

		waitForExpectations(timeout: 1)
	}

	// MARK: - signalName(for:)

	func testSignalNameSIGABRT() {
		XCTAssertEqual(signalName(for: SIGABRT), "SIGABRT")
	}

	func testSignalNameSIGILL() {
		XCTAssertEqual(signalName(for: SIGILL), "SIGILL")
	}

	func testSignalNameSIGSEGV() {
		XCTAssertEqual(signalName(for: SIGSEGV), "SIGSEGV")
	}

	func testSignalNameSIGFPE() {
		XCTAssertEqual(signalName(for: SIGFPE), "SIGFPE")
	}

	func testSignalNameSIGBUS() {
		XCTAssertEqual(signalName(for: SIGBUS), "SIGBUS")
	}

	func testSignalNameSIGPIPE() {
		XCTAssertEqual(signalName(for: SIGPIPE), "SIGPIPE")
	}

	func testSignalNameSIGTRAP() {
		XCTAssertEqual(signalName(for: SIGTRAP), "SIGTRAP")
	}

	func testSignalNameUnknownSignalContainsNumber() {
		XCTAssertEqual(signalName(for: 999), "Unknown Signal 999")
	}

	// MARK: - checkJsReport

	func testCheckJsReportReadsBackSavedReport() throws {
		let timestamp = Date(timeIntervalSince1970: 1_700_005_000)
		try writeJsCrashReport(message: "TypeError: undefined", stackTrace: "at foo.js:10", timestamp: timestamp)

		let expectation = self.expectation(description: "js report delivered")
		var result: JsCrashReport?

		reporter.checkJsReport { outcome in
			if case .success(let r) = outcome {
				result = r
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 3)
		XCTAssertEqual(result?.message, "TypeError: undefined")
		XCTAssertEqual(result?.stackTrace, "at foo.js:10")
		XCTAssertEqual(result.map { $0.timestamp.timeIntervalSince1970 } ?? 0, timestamp.timeIntervalSince1970, accuracy: 1)
	}

	func testCheckJsReportDeletesFileAfterReading() throws {
		try writeJsCrashReport(message: "ReferenceError", stackTrace: "at bar.js:5", timestamp: Date())

		let expectation = self.expectation(description: "js report delivered")
		reporter.checkJsReport { _ in expectation.fulfill() }
		waitForExpectations(timeout: 3)

		let jsCrashesDir = tempDirectory.appendingPathComponent("justtrack/js_crashes")
		let allFiles = try? FileManager.default.contentsOfDirectory(at: jsCrashesDir, includingPropertiesForKeys: nil)
		let remaining = (allFiles ?? []).filter { $0.pathExtension == "json" }
		XCTAssertEqual(remaining.count, 0)
	}

	func testCheckJsReportDoesNotCallCompletionWhenNoCrashesDirectoryExists() {
		let expectation = self.expectation(description: "completion not called")
		expectation.isInverted = true

		reporter.checkJsReport { _ in expectation.fulfill() }

		waitForExpectations(timeout: 1)
	}

	func testCheckJsReportCallsCompletionForEachFile() throws {
		try writeJsCrashReport(message: "Error 1", stackTrace: "s1", timestamp: Date(timeIntervalSince1970: 1_700_006_000))
		try writeJsCrashReport(message: "Error 2", stackTrace: "s2", timestamp: Date(timeIntervalSince1970: 1_700_006_001))

		let expectation = self.expectation(description: "both js reports delivered")
		expectation.expectedFulfillmentCount = 2
		reporter.checkJsReport { _ in expectation.fulfill() }
		waitForExpectations(timeout: 3)
	}

	// MARK: - processCrashReports: failure paths

	func testCheckNativeCrashReportCallsFailureOnCorruptFile() throws {
		let corruptData = "not valid json".data(using: .utf8)!
		let crashDir = crashesDir
		try FileManager.default.createDirectory(at: crashDir, withIntermediateDirectories: true)
		let fileUrl = crashDir.appendingPathComponent("1700007000.json")
		try corruptData.write(to: fileUrl)

		let expectation = self.expectation(description: "failure delivered")
		var receivedError: Error?

		reporter.checkNativeCrashReport { outcome in
			if case .failure(let error) = outcome {
				receivedError = error
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 3)
		XCTAssertNotNil(receivedError)
	}

	func testCheckNativeCrashReportCallsFailureWhenDocumentsDirectoryUnavailable() {
		let unavailableFileManager = TempDirectoryFileManager(tempDirectory: tempDirectory, simulateUnavailableDocuments: true)
		let reporterWithNoDocuments = DefaultCrashReporter(testFileManager: unavailableFileManager)

		let expectation = self.expectation(description: "failure delivered")
		var receivedError: Error?

		reporterWithNoDocuments.checkNativeCrashReport { outcome in
			if case .failure(let error) = outcome {
				receivedError = error
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 3)
		XCTAssertNotNil(receivedError)
		XCTAssertEqual((receivedError as NSError?)?.domain, "DefaultCrashReporter")
		XCTAssertEqual((receivedError as NSError?)?.code, 1)
	}

	func testCheckJsReportCallsFailureOnCorruptFile() throws {
		let jsCrashesDir = tempDirectory.appendingPathComponent("justtrack/js_crashes")
		try FileManager.default.createDirectory(at: jsCrashesDir, withIntermediateDirectories: true)
		let fileUrl = jsCrashesDir.appendingPathComponent("1700008000.json")
		try "not valid json".data(using: .utf8)!.write(to: fileUrl)

		let expectation = self.expectation(description: "failure delivered")
		var receivedError: Error?

		reporter.checkJsReport { outcome in
			if case .failure(let error) = outcome {
				receivedError = error
			}
			expectation.fulfill()
		}

		waitForExpectations(timeout: 3)
		XCTAssertNotNil(receivedError)
	}

	// MARK: - Private helpers

	private func makeSignalReport(
		name: String = "SIGABRT",
		callStack: String = "signal frame 0"
	) -> CrashReport.SignalReport {
		CrashReport.SignalReport(name: name, callStack: callStack, info: nil)
	}

	/// Writes a JSON file directly into the js_crashes temp directory, bypassing
	/// DefaultCrashReporter (which has no saveCrashReport path for JS crashes).
	/// JSONDecoder's default Date strategy is .deferredToDate (seconds since 2001-01-01),
	/// so the timestamp is written as a raw number using timeIntervalSinceReferenceDate.
	private func writeJsCrashReport(message: String, stackTrace: String, timestamp: Date) throws {
		let jsCrashesDir = tempDirectory.appendingPathComponent("justtrack/js_crashes")
		try FileManager.default.createDirectory(at: jsCrashesDir, withIntermediateDirectories: true)

		let secondsSinceReferenceDate = timestamp.timeIntervalSinceReferenceDate
		let json = """
			{"timestamp":\(secondsSinceReferenceDate),"message":"\(message)","stackTrace":"\(stackTrace)"}
			"""
		let filename = "\(Int(timestamp.timeIntervalSince1970)).json"
		try json.data(using: .utf8)!.write(to: jsCrashesDir.appendingPathComponent(filename))
	}
}

// MARK: - TempDirectoryFileManager

/// Subclass of FileManager that redirects urls(for:in:) to a given temp directory,
/// allowing DefaultCrashReporter to write/read files in an isolated location during tests.
/// When `simulateUnavailableDocuments` is true, returns an empty array for `.documentDirectory`
/// to exercise the unavailable-documents-directory failure path.
private final class TempDirectoryFileManager: FileManager {
	private let tempDirectory: URL
	private let simulateUnavailableDocuments: Bool

	init(tempDirectory: URL, simulateUnavailableDocuments: Bool = false) {
		self.tempDirectory = tempDirectory
		self.simulateUnavailableDocuments = simulateUnavailableDocuments
	}

	override func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
		if directory == .documentDirectory {
			return simulateUnavailableDocuments ? [] : [tempDirectory]
		}
		return super.urls(for: directory, in: domainMask)
	}
}
