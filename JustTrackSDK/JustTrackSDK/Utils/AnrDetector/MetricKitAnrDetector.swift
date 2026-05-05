import MetricKit

@available(iOS 14, *)
final class MetricKitAnrDetector: NSObject, AnrDetector {
	private var anrHandler: ((AnrReport) -> Void)?
	private let logger: HttpLogger

	init(
		logger: HttpLogger
	) {
		self.logger = logger
	}

	func setHandler(_ handler: @escaping (AnrReport) -> Void) {
		anrHandler = handler
		MXMetricManager.shared.add(self)
	}

	func removeHandler() {
		anrHandler = nil
		MXMetricManager.shared.remove(self)
	}

	private func logError(
		_ message: String,
		error: Error? = nil,
		fields: LoggerFields...
	) {
		if let error {
			logger.error("<MetricKitAnrDetector> \(message)", error, fields)
		} else {
			logger.error("<MetricKitAnrDetector> \(message)", fields)
		}
	}
}

@available(iOS 14, *)
extension MetricKitAnrDetector: MXMetricManagerSubscriber {
	func didReceive(_ payloads: [MXDiagnosticPayload]) {
		for payload in payloads {
			processDiagnosticPayload(payload)
		}
	}

	private func processDiagnosticPayload(_ payload: MXDiagnosticPayload) {
		guard let hangDiagnostics = payload.hangDiagnostics else { return }

		var reports = [AnrReport]()

		for diagnostic in hangDiagnostics {
			guard let report = extractReport(from: diagnostic.callStackTree) else { continue }
			reports.append(report)
		}

		if let anrHandler {
			reportLoop: for report in reports {
				for callStack in report.callStacks {
					for call in callStack.calls {
						if call.package.contains(String.sdkPackageName) {  // swiftlint:disable:this for_where
							DispatchQueue.main.async {
								anrHandler(report)
							}
							continue reportLoop
						}
					}
				}
			}
		}
	}

	private func extractReport(from callStackTree: MXCallStackTree) -> AnrReport? {
		do {
			if let json = try JSONSerialization.jsonObject(with: callStackTree.jsonRepresentation(), options: []) as? [String: Any] {
				return extractCallsFromJSON(json)
			}
		} catch {
			logError("Parsing call stack for calls failure", error: error)
		}

		return nil
	}

	private func extractCallsFromJSON(_ json: [String: Any]) -> AnrReport {
		var calls: [AnrReport.CallStack.Call] = []
		if let callStacks = json["callStacks"] as? [[String: Any]],
			let firstStack = callStacks.first,
			let rootFrames = firstStack["callStackRootFrames"] as? [[String: Any]]
		{
			for rootFrame in rootFrames {
				extractCallsFromFrame(rootFrame, into: &calls)
			}
		}
		return AnrReport(
			timestamp: Date(),
			callStacks: [
				AnrReport.CallStack(
					threadId: "1",
					calls: calls
				)
			]
		)
	}

	private func extractCallsFromFrame(_ frame: [String: Any], into calls: inout [AnrReport.CallStack.Call]) {
		let address = frame["address"] as? Int ?? 0
		let offsetIntoBinaryTextSegment = frame["offsetIntoBinaryTextSegment"] as? Int ?? 0
		let binaryName = frame["binaryName"] as? String ?? "Unknown"
		let call = AnrReport.CallStack.Call(
			address: String(format: "0x%lx", address),
			addressOffset: String(format: "0x%lx", offsetIntoBinaryTextSegment),
			symbol: "",
			offset: "",
			package: binaryName
		)
		calls.append(call)
		if let subFrames = frame["subFrames"] as? [[String: Any]] {
			if let firstSubFrame = subFrames.first {
				extractCallsFromFrame(firstSubFrame, into: &calls)
			}
		}
	}
}
