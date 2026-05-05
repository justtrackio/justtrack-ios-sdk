struct JsCrashReport: Decodable {
	let timestamp: Date
	let message: String
	let stackTrace: String
}

struct NativeCrashReport: Codable {
	enum ReportType: String, Codable {
		case exception
		case signal
	}

	let timestamp: Double
	let reportType: ReportType
	let name: String
	let reason: String?
	let callStack: String
	let signalInfo: SignalInfo?

	struct SignalInfo: Codable {
		let errorNumber: String
		let signalCode: String
		let signalNumber: String
		let sendingProcess: String
		let senderRuid: String
		let exitValue: String
		let signalValue: String
		let faultingAddress: String?
	}
}

final class DefaultCrashReporter: CrashReporter {
	static let shared = DefaultCrashReporter()

	private static let crashesDirectory = "justtrack/crashes"
	private static let jsCrashesDirectory = "justtrack/js_crashes"

	fileprivate init() {
	}

	func startMonitoring() {
		downstreamExceptionHandler = NSGetUncaughtExceptionHandler()
		NSSetUncaughtExceptionHandler(exceptionHandler)
		setSignalHandler()
	}

	func stopMonitoring() {
		if exceptionHandlerIsStilSet {
			NSSetUncaughtExceptionHandler(downstreamExceptionHandler)
		}
		removeSignalHandler()
	}

	func saveCrashReport(_ report: CrashReport, timestamp: Double) {
		guard let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

		let crashesDir = documentsUrl.appendingPathComponent(Self.crashesDirectory)
		try? FileManager.default.createDirectory(at: crashesDir, withIntermediateDirectories: true, attributes: nil)

		let filename = "\(Int(timestamp)).json"
		let reportUrl = crashesDir.appendingPathComponent(filename)

		let storedReport: NativeCrashReport
		switch report {
		case let .exception(exceptionReport):
			storedReport = NativeCrashReport(
				timestamp: timestamp,
				reportType: .exception,
				name: exceptionReport.name,
				reason: exceptionReport.reason,
				callStack: exceptionReport.callStack,
				signalInfo: nil
			)
		case let .signal(signalReport):
			storedReport = NativeCrashReport(
				timestamp: timestamp,
				reportType: .signal,
				name: signalReport.name,
				reason: nil,
				callStack: signalReport.callStack,
				signalInfo: signalReport.info.map { info in
					NativeCrashReport.SignalInfo(
						errorNumber: info.errorNumber,
						signalCode: info.signalCode,
						signalNumber: info.signalNumber,
						sendingProcess: info.sendingProcess,
						senderRuid: info.senderRuid,
						exitValue: info.exitValue,
						signalValue: info.signalValue,
						faultingAddress: info.faultingAddress
					)
				}
			)
		}

		if let data = try? JSONEncoder().encode(storedReport) {
			try? data.write(to: reportUrl, options: .atomic)
		}
	}

	private func processCrashReports<T: Decodable>(
		from directory: String,
		decodingType: T.Type,
		completionHandler: @escaping (Result<T, Error>) -> Void
	) {
		DispatchQueue.global(qos: .userInitiated).async {
			guard let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
				let error = NSError(
					domain: "DefaultCrashReporter",
					code: 1,
					userInfo: [NSLocalizedDescriptionKey: "Could not access documents directory"]
				)
				DispatchQueue.main.async {
					completionHandler(.failure(error))
				}
				return
			}

			let crashesDir = documentsUrl.appendingPathComponent(directory)

			guard FileManager.default.fileExists(atPath: crashesDir.path) else {
				return
			}

			do {
				let files = try FileManager.default.contentsOfDirectory(at: crashesDir, includingPropertiesForKeys: nil)
					.filter { $0.pathExtension == "json" }
					.sorted { $0.lastPathComponent < $1.lastPathComponent }

				for fileUrl in files {
					do {
						let data = try Data(contentsOf: fileUrl)
						let report = try JSONDecoder().decode(T.self, from: data)
						DispatchQueue.main.async {
							completionHandler(.success(report))
						}
						try FileManager.default.removeItem(at: fileUrl)
					} catch {
						DispatchQueue.main.async {
							completionHandler(.failure(error))
						}
					}
				}
			} catch {
				DispatchQueue.main.async {
					completionHandler(.failure(error))
				}
			}
		}
	}

	func checkNativeCrashReport(completionHandler: @escaping (Result<NativeCrashReport, Error>) -> Void) {
		processCrashReports(from: Self.crashesDirectory, decodingType: NativeCrashReport.self, completionHandler: completionHandler)
	}

	func checkJsReport(completionHandler: @escaping (Result<JsCrashReport, Error>) -> Void) {
		processCrashReports(from: Self.jsCrashesDirectory, decodingType: JsCrashReport.self, completionHandler: completionHandler)
	}
}

private let signals = [SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGTRAP, SIGABRT]
private var signalPreviousActions = [Int32: Any]()

private var exceptionHandlerIsStilSet: Bool {
	let currentHandler = unsafeBitCast(NSGetUncaughtExceptionHandler(), to: UnsafeMutableRawPointer.self)
	let handler = unsafeBitCast(exceptionHandler, to: UnsafeMutableRawPointer.self)
	return currentHandler == handler
}

private var downstreamExceptionHandler: (@convention(c) (NSException) -> Void)?

private let exceptionHandler: @convention(c) (NSException) -> Void = { exception in
	removeSignalHandler()

	defer {
		downstreamExceptionHandler?(exception)
	}

	let callStack = exception.callStackSymbols.joined(separator: "\n")

	if callStack.containsSDK {
		let report = CrashReport.ExceptionReport(
			name: exception.name.rawValue,
			reason: exception.reason,
			callStack: callStack
		)

		let timestamp = Date().timeIntervalSince1970
		DefaultCrashReporter.shared.saveCrashReport(.exception(report), timestamp: timestamp)
	}
}

private let signalHandler: @convention(c) (Int32, UnsafeMutablePointer<__siginfo>?, UnsafeMutableRawPointer?) -> Void = { signal, info, _ in
	let originalErrno = errno

	defer {
		// Also, it is good practice to make a copy of the global variable errno and restore it before returning from the signal handler.  This protects against the side effect of errno being set by functions called from inside the signal handler.
		// https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/sigaction.2.html
		errno = originalErrno

		removeSignalHandler()

		// In theory, most of the signals could be handled without killing the app from our side, so we explicitly do this only for SIGABRT and SIGPIPE.
		if [SIGABRT, SIGPIPE].contains(signal) {
			kill(getpid(), signal)
		}
	}

	let callStack = Thread.callStackSymbols.joined(separator: "\n")

	if callStack.containsSDK {
		let report = CrashReport.SignalReport(
			name: {
				switch signal {
				case SIGABRT:
					return "SIGABRT"
				case SIGILL:
					return "SIGILL"
				case SIGSEGV:
					return "SIGSEGV"
				case SIGFPE:
					return "SIGFPE"
				case SIGBUS:
					return "SIGBUS"
				case SIGPIPE:
					return "SIGPIPE"
				case SIGTRAP:
					return "SIGTRAP"
				default:
					return "Unknown Signal \(signal)"
				}
			}(),
			callStack: callStack,
			info: CrashReport.SignalReport.Info(t: info?.pointee)
		)

		let timestamp = Date().timeIntervalSince1970
		DefaultCrashReporter.shared.saveCrashReport(.signal(report), timestamp: timestamp)
	}
}

private func setSignalHandler() {
	for signal in signals {
		setCustomHandler(for: signal)
	}

	setCustomHandler(for: SIGPIPE, checkForDefault: true)
}

private func setCustomHandler(for signal: Int32, checkForDefault: Bool = false) {
	var action = sigaction()
	action.__sigaction_u = unsafeBitCast(signalHandler, to: __sigaction_u.self)
	sigemptyset(&action.sa_mask)
	action.sa_flags = SA_SIGINFO

	var prevAction = sigaction()

	guard sigaction(signal, &action, &prevAction) == 0 else { return }

	if checkForDefault {
		let defaultHandler = unsafeBitCast(SIG_DFL, to: sig_t.self)
		let previousHandler = prevAction.__sigaction_u.__sa_handler
		let same = justtrack_compareSignalHandlers(defaultHandler, previousHandler) == 1
		if !same {
			sigaction(signal, &prevAction, nil)
			return
		}
	}

	signalPreviousActions[signal] = prevAction
}

private func removeSignalHandler() {
	for signal in signals + [SIGPIPE] {
		var action = getPreviousActionIfAvailable(for: signal)
		sigaction(signal, &action, nil)
	}
}

private func getPreviousActionIfAvailable(for signal: Int32) -> sigaction {
	if let previousAction = signalPreviousActions.removeValue(forKey: signal) as? sigaction {
		return previousAction
	}

	var action = sigaction()
	action.__sigaction_u = unsafeBitCast(SIG_DFL, to: __sigaction_u.self)
	sigemptyset(&action.sa_mask)
	action.sa_flags = 0

	return action
}
