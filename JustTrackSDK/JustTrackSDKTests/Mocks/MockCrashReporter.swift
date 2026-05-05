@testable import JustTrackSDK

final class MockCrashReporter: CrashReporter {
	enum Call: Equatable {
		case checkJsReport
		case checkNativeCrashReport
		case startMonitoring
		case stopMonitoring
	}

	var calls: [Call] = []

	func reset() {
		calls = []
	}

	func checkJsReport(completionHandler: @escaping (Result<JsCrashReport, any Error>) -> Void) {
		calls.append(.checkJsReport)
	}

	func checkNativeCrashReport(completionHandler: @escaping (Result<NativeCrashReport, any Error>) -> Void) {
		calls.append(.checkNativeCrashReport)
	}

	func startMonitoring() {
		calls.append(.startMonitoring)
	}

	func stopMonitoring() {
		calls.append(.stopMonitoring)
	}
}
