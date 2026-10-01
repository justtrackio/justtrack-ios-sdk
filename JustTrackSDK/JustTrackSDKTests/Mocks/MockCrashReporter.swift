@testable import JustTrackSDK

final class MockCrashReporter: CrashReporter {
	enum Call: Equatable {
		case checkJsReport
		case checkNativeCrashReport
		case startMonitoring
		case stopMonitoring
	}

	var calls: [Call] = []
	var jsCrashReportStub: Result<JsCrashReport, Error>?
	var nativeCrashReportStub: Result<NativeCrashReport, Error>?

	func reset() {
		calls = []
	}

	func checkJsReport(completionHandler: @escaping (Result<JsCrashReport, any Error>) -> Void) {
		calls.append(.checkJsReport)
		if let stub = jsCrashReportStub {
			completionHandler(stub)
		}
	}

	func checkNativeCrashReport(completionHandler: @escaping (Result<NativeCrashReport, any Error>) -> Void) {
		calls.append(.checkNativeCrashReport)
		if let stub = nativeCrashReportStub {
			completionHandler(stub)
		}
	}

	func startMonitoring() {
		calls.append(.startMonitoring)
	}

	func stopMonitoring() {
		calls.append(.stopMonitoring)
	}
}
