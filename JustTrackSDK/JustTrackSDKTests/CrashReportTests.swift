import XCTest

@testable import JustTrackSDK

final class CrashReportTests: XCTestCase {
	func testExceptionMetricFields() {
		let report = CrashReport.ExceptionReport(
			name: "NSInvalidArgumentException",
			reason: "unrecognized selector",
			callStack: "frame1\nframe2"
		)

		XCTAssertEqual(
			report.metricFields.getFields(),
			["exception_name": "NSInvalidArgumentException"]
		)
	}

	func testExceptionErrorFieldsIncludeBreadcrumbs() {
		let report = CrashReport.ExceptionReport(
			name: "NSInvalidArgumentException",
			reason: "unrecognized selector",
			callStack: "frame1\nframe2"
		)
		let breadcrumbs = [
			Breadcrumb(
				message: "User tapped button",
				category: "ui",
				level: "info",
				timestamp: Date(timeIntervalSince1970: 1000)
			),
			Breadcrumb(
				message: "Request started",
				category: "network",
				level: "debug",
				timestamp: Date(timeIntervalSince1970: 1001)
			),
		]

		let fields = report.generateErrorFields(breadcrumbs: breadcrumbs).getFields()

		XCTAssertEqual(fields["exception_name"], "NSInvalidArgumentException")
		XCTAssertEqual(fields["reason"], "unrecognized selector")
		XCTAssertEqual(fields["stack_trace"], "frame1\nframe2")
		XCTAssertEqual(fields["breadcrumb_0_message"], "User tapped button")
		XCTAssertEqual(fields["breadcrumb_0_category"], "ui")
		XCTAssertEqual(fields["breadcrumb_0_level"], "info")
		XCTAssertEqual(fields["breadcrumb_0_timestamp"], formatDateMilliseconds(Date(timeIntervalSince1970: 1000)))
		XCTAssertEqual(fields["breadcrumb_1_message"], "Request started")
		XCTAssertEqual(fields["breadcrumb_1_category"], "network")
		XCTAssertEqual(fields["breadcrumb_1_level"], "debug")
		XCTAssertEqual(fields["breadcrumb_1_timestamp"], formatDateMilliseconds(Date(timeIntervalSince1970: 1001)))
	}

	func testExceptionErrorFieldsOmitNilReason() {
		let report = CrashReport.ExceptionReport(
			name: "NSException",
			reason: nil,
			callStack: "frame1"
		)

		let fields = report.generateErrorFields(breadcrumbs: []).getFields()

		XCTAssertEqual(fields["exception_name"], "NSException")
		XCTAssertNil(fields["reason"])
		XCTAssertEqual(fields["stack_trace"], "frame1")
	}

	func testSignalErrorFieldsIncludeSignalInfoAndBreadcrumbs() {
		let info = CrashReport.SignalReport.Info(
			errorNumber: "0",
			signalCode: "1",
			signalNumber: "11",
			sendingProcess: "1234",
			senderRuid: "501",
			exitValue: "0",
			signalValue: "42",
			faultingAddress: "0x0000"
		)
		let report = CrashReport.SignalReport(
			name: "SIGSEGV",
			callStack: "frame1\nframe2",
			info: info
		)
		let breadcrumbs = [
			Breadcrumb(
				message: "Screen opened",
				category: "navigation",
				level: "info",
				timestamp: Date(timeIntervalSince1970: 2000)
			)
		]

		let fields = report.generateErrorFields(breadcrumbs: breadcrumbs).getFields()

		XCTAssertEqual(fields["signal_name"], "SIGSEGV")
		XCTAssertEqual(fields["stack_trace"], "frame1\nframe2")
		XCTAssertEqual(fields["info_error_number"], "0")
		XCTAssertEqual(fields["info_signal_code"], "1")
		XCTAssertEqual(fields["info_signal_number"], "11")
		XCTAssertEqual(fields["info_sending_process"], "1234")
		XCTAssertEqual(fields["info_sender_ruid"], "501")
		XCTAssertEqual(fields["info_exit_value"], "0")
		XCTAssertEqual(fields["info_signal_value"], "42")
		XCTAssertEqual(fields["info_faulting_address"], "0x0000")
		XCTAssertEqual(fields["breadcrumb_0_message"], "Screen opened")
		XCTAssertEqual(fields["breadcrumb_0_category"], "navigation")
		XCTAssertEqual(fields["breadcrumb_0_level"], "info")
		XCTAssertEqual(fields["breadcrumb_0_timestamp"], formatDateMilliseconds(Date(timeIntervalSince1970: 2000)))
	}

	func testSignalErrorFieldsOmitNilSignalInfo() {
		let report = CrashReport.SignalReport(
			name: "SIGABRT",
			callStack: "frame1",
			info: nil
		)

		let fields = report.generateErrorFields(breadcrumbs: []).getFields()

		XCTAssertEqual(fields["signal_name"], "SIGABRT")
		XCTAssertEqual(fields["stack_trace"], "frame1")
		XCTAssertNil(fields["info_error_number"])
		XCTAssertNil(fields["info_signal_code"])
		XCTAssertNil(fields["info_signal_number"])
		XCTAssertNil(fields["info_sending_process"])
		XCTAssertNil(fields["info_sender_ruid"])
		XCTAssertNil(fields["info_exit_value"])
		XCTAssertNil(fields["info_signal_value"])
		XCTAssertNil(fields["info_faulting_address"])
	}

	func testSignalInfoReturnsNilForNilSiginfo() {
		XCTAssertNil(CrashReport.SignalReport.Info(t: nil))
	}
}
