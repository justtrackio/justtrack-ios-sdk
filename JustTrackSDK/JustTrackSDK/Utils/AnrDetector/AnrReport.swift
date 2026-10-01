struct AnrReport {
	let timestamp: Date
	let callStacks: [CallStack]

	struct CallStack {
		let threadId: String
		let calls: [Call]

		struct Call {
			let address: String
			let addressOffset: String
			let symbol: String
			let offset: String
			let package: String

			init(
				address: String,
				addressOffset: String = "",
				symbol: String = "",
				offset: String = "",
				package: String = ""
			) {
				self.address = address
				self.addressOffset = addressOffset
				self.symbol = symbol
				self.offset = offset
				self.package = package
			}
		}
	}

	var errorFields: LoggerFieldsBuilder {
		var loggerFields = LoggerFieldsImpl().with("timestamp", timestamp.timeIntervalSince1970)
		for (index, callStack) in callStacks.enumerated() {
			var stackTrace = ""
			for (idx, call) in callStack.calls.enumerated() {
				stackTrace += "\(idx) \(call.address) \(call.symbol) + \(call.offset) (\(call.package) + \(call.addressOffset))\n"
			}
			loggerFields = loggerFields.with("stack_trace_\(index)", "Thread: \(callStack.threadId)\n\(stackTrace)")
		}
		return loggerFields
	}
}
