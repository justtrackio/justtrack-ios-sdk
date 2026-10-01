import Darwin
import Foundation
import MachO

final class DefaultAnrDetector {
	private let queue = DispatchQueue(label: "io.justtrack.DefaultAnrDetector.queue")
	private let checkInterval: TimeInterval
	private let threshold: TimeInterval
	private let logger: HttpLogger
	private let mainThreadPthread: pthread_t
	private let skipMonitoringForTesting: Bool

	var anrHandler: ((AnrReport) -> Void)?
	private var lastHandlerId: Int?

	init(
		checkInterval: TimeInterval = 4,
		threshold: TimeInterval = 2,
		logger: HttpLogger,
		skipMonitoringForTesting: Bool = false
	) {
		self.checkInterval = checkInterval
		self.threshold = threshold
		self.logger = logger
		self.skipMonitoringForTesting = skipMonitoringForTesting

		// Capture the main thread's pthread handle during initialization
		// This must be called from the main thread
		if Thread.isMainThread {
			self.mainThreadPthread = pthread_self()
		} else {
			// If not on main thread, we need to get it synchronously
			var pthread: pthread_t!
			DispatchQueue.main.sync {
				pthread = pthread_self()
			}
			self.mainThreadPthread = pthread
		}
	}

	private func captureMainThreadCallStack() -> AnrReport.CallStack? {
		let mainMachThread = pthread_mach_thread_np(mainThreadPthread)
		guard mainMachThread != 0 else {
			logError("Failed to get mach thread for main thread")
			return nil
		}
		return captureViaSuspension(mainMachThread)
	}

	private func captureViaSuspension(_ machThread: thread_t) -> AnrReport.CallStack? {
		let kr = thread_suspend(machThread)
		guard kr == KERN_SUCCESS else {
			logError("Failed to suspend main thread: \(kr)")
			return nil
		}
		defer { thread_resume(machThread) }

		let maxStackDepth = 128
		let buffer = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: maxStackDepth)
		defer { buffer.deallocate() }

		var frameCount = 0

		#if arch(arm64)
			var state = __darwin_arm_thread_state64()
			var stateCount = mach_msg_type_number_t(MemoryLayout.size(ofValue: state) / MemoryLayout<natural_t>.size)
			let flavor = thread_state_flavor_t(ARM_THREAD_STATE64)

			let statePtr = withUnsafeMutablePointer(to: &state) { ptr in
				ptr.withMemoryRebound(to: natural_t.self, capacity: Int(stateCount)) { $0 }
			}

			let result = thread_get_state(machThread, flavor, statePtr, &stateCount)
			if result == KERN_SUCCESS {
				buffer[0] = UnsafeMutableRawPointer(bitPattern: UInt(state.__pc))
				buffer[1] = UnsafeMutableRawPointer(bitPattern: UInt(state.__lr))
				frameCount = 2

				var fp = state.__fp
				var depth = 2

				while depth < maxStackDepth && fp != 0 && fp > 0x1_0000_0000 {
					let framePtr = UnsafePointer<UInt64>(bitPattern: UInt(fp))
					if let frame = framePtr {
						let nextFp = frame[0]
						let returnAddr = frame[1]

						if returnAddr != 0 {
							buffer[depth] = UnsafeMutableRawPointer(bitPattern: UInt(returnAddr))
							depth += 1
						}

						fp = nextFp
					} else {
						break
					}
				}
				frameCount = depth
			}
		#endif
		guard frameCount > 0 else {
			logError("Failed to capture any stack frames via suspension")
			return nil
		}

		return convertToCallStack(buffer: buffer, count: frameCount)
	}

	private func convertToCallStack(buffer: UnsafeMutablePointer<UnsafeMutableRawPointer?>, count: Int) -> AnrReport.CallStack? {
		var calls = [AnrReport.CallStack.Call]()

		for i in 0..<count {
			guard let address = buffer[i] else { continue }

			let absoluteAddress = UInt(bitPattern: address)

			var info = Dl_info()
			let hasSymbolInfo = dladdr(address, &info) != 0

			if hasSymbolInfo {
				let symbol: String
				if let sname = info.dli_sname {
					symbol = String(cString: sname)
				} else {
					symbol = ""
				}

				let package: String
				if let fname = info.dli_fname {
					package = String(cString: fname).components(separatedBy: "/").last ?? ""
				} else {
					package = ""
				}

				let baseAddress = UInt(bitPattern: info.dli_fbase)
				let addressOffset = absoluteAddress - baseAddress

				let symbolOffset: UInt
				if info.dli_saddr != nil {
					symbolOffset = absoluteAddress - UInt(bitPattern: info.dli_saddr)
				} else {
					symbolOffset = 0
				}

				calls.append(
					AnrReport.CallStack.Call(
						address: String(format: "0x%016llx", absoluteAddress),
						addressOffset: String(format: "0x%llx", addressOffset),
						symbol: symbol,
						offset: String(format: "%d", symbolOffset),
						package: package
					)
				)
			} else {
				calls.append(
					AnrReport.CallStack.Call(
						address: String(format: "0x%016llx", absoluteAddress)
					)
				)
			}
		}

		guard !calls.isEmpty else { return nil }

		return AnrReport.CallStack(threadId: "0", calls: calls)
	}

	private func generateReport() -> AnrReport? {
		guard let mainThreadCallStack = captureMainThreadCallStack() else {
			logError("Failed to capture main thread call stack")
			return nil
		}

		return AnrReport(timestamp: Date(), callStacks: [mainThreadCallStack])
	}

	private func performMonitoring(handlerId: Int) {
		guard lastHandlerId == handlerId else { return }

		let semaphore = DispatchSemaphore(value: 0)

		DispatchQueue.main.async { [weak semaphore] in
			semaphore?.signal()
		}

		switch semaphore.wait(timeout: .now() + threshold) {
		case .timedOut:
			report()
		case .success:
			break
		}

		queue.asyncAfter(deadline: .now() + checkInterval) { [weak self] in
			self?.performMonitoring(handlerId: handlerId)
		}
	}

	private func report() {
		guard let report = generateReport() else {
			logError("Failed to generate ANR report")
			return
		}

		handleReport(report)
	}

	func handleReport(_ report: AnrReport) {
		for callStack in report.callStacks {
			for call in callStack.calls {
				if call.package.contains(String.sdkPackageName) {  // swiftlint:disable:this for_where
					logError("ANR detected - main thread blocked for \(threshold) seconds")
					anrHandler?(report)
					return
				}
			}
		}
	}

	func syncForTesting() {
		queue.sync {}
	}

	private func logError(
		_ message: String,
		error: Error? = nil,
		fields: LoggerFields...
	) {
		if let error {
			logger.error("<DefaultAnrDetector> \(message)", error, fields)
		} else {
			logger.error("<DefaultAnrDetector> \(message)", fields)
		}
	}
}

extension DefaultAnrDetector: AnrDetector {
	func setHandler(
		_ handler: @escaping (AnrReport) -> Void
	) {
		queue.async { [weak self] in
			guard let self else { return }
			self.anrHandler = handler
			let handlerId = (self.lastHandlerId ?? 0) + 1
			self.lastHandlerId = handlerId
			if !self.skipMonitoringForTesting {
				self.performMonitoring(handlerId: handlerId)
			}
		}
	}

	func removeHandler() {
		queue.async { [weak self] in
			self?.lastHandlerId = nil
			self?.anrHandler = nil
		}
	}
}
