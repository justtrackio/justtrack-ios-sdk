protocol CrashReporter: AnyObject {
	func startMonitoring()

	func stopMonitoring()

	func checkJsReport(completionHandler: @escaping (Result<JsCrashReport, Error>) -> Void)

	func checkNativeCrashReport(completionHandler: @escaping (Result<NativeCrashReport, Error>) -> Void)
}
