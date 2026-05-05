enum CrashReport {
	case exception(ExceptionReport)
	case signal(SignalReport)
}

extension CrashReport {
	struct ExceptionReport {
		let name: String
		let reason: String?
		let callStack: String
	}

	struct SignalReport {
		let name: String
		let callStack: String
		let info: Info?
	}
}

extension CrashReport.SignalReport {
	struct Info {
		init(
			errorNumber: String,
			signalCode: String,
			signalNumber: String,
			sendingProcess: String,
			senderRuid: String,
			exitValue: String,
			signalValue: String,
			faultingAddress: String? = nil
		) {
			self.errorNumber = errorNumber
			self.signalCode = signalCode
			self.signalNumber = signalNumber
			self.sendingProcess = sendingProcess
			self.senderRuid = senderRuid
			self.exitValue = exitValue
			self.signalValue = signalValue
			self.faultingAddress = faultingAddress
		}

		let errorNumber: String
		let signalCode: String
		let signalNumber: String
		let sendingProcess: String
		let senderRuid: String
		let exitValue: String
		let signalValue: String
		let faultingAddress: String?

		init?(t: siginfo_t?) {
			guard let t else { return nil }
			errorNumber = String(t.si_errno)
			signalCode = String(t.si_code)
			signalNumber = String(t.si_signo)
			sendingProcess = String(t.si_pid)
			senderRuid = String(t.si_uid)
			exitValue = String(t.si_status)
			signalValue = String(t.si_value.sival_int)
			faultingAddress = {
				guard let addr = t.si_addr else { return nil }
				return String(describing: addr)
			}()
		}
	}
}

extension CrashReport.ExceptionReport {
	var metricFields: LoggerFieldsBuilder {
		LoggerFieldsImpl().with("exception_name", name)
	}

	func generateErrorFields(
		breadcrumbs: [Breadcrumb]
	) -> LoggerFieldsBuilder {
		var errorFields = LoggerFieldsImpl()
			.with("exception_name", name)
			.with("reason", reason)
			.with("stack_trace", callStack)
		for (index, breadcrumb) in breadcrumbs.enumerated() {
			errorFields =
				errorFields
				.with("breadcrumb_\(index)_message", breadcrumb.message)
				.with("breadcrumb_\(index)_category", breadcrumb.category)
				.with("breadcrumb_\(index)_level", breadcrumb.level)
				.with("breadcrumb_\(index)_timestamp", formatDateMilliseconds(breadcrumb.timestamp))
		}
		return errorFields
	}
}

extension CrashReport.SignalReport {
	func generateErrorFields(
		breadcrumbs: [Breadcrumb]
	) -> LoggerFieldsBuilder {
		var errorFields = LoggerFieldsImpl()
			.with("signal_name", name)
			.with("stack_trace", callStack)
			.with("info_error_number", info?.errorNumber)
			.with("info_signal_code", info?.signalCode)
			.with("info_signal_number", info?.signalNumber)
			.with("info_sending_process", info?.sendingProcess)
			.with("info_sender_ruid", info?.senderRuid)
			.with("info_exit_value", info?.exitValue)
			.with("info_signal_value", info?.signalValue)
			.with("info_faulting_address", info?.faultingAddress)
		for (index, breadcrumb) in breadcrumbs.enumerated() {
			errorFields =
				errorFields
				.with("breadcrumb_\(index)_message", breadcrumb.message)
				.with("breadcrumb_\(index)_category", breadcrumb.category)
				.with("breadcrumb_\(index)_level", breadcrumb.level)
				.with("breadcrumb_\(index)_timestamp", formatDateMilliseconds(breadcrumb.timestamp))
		}
		return errorFields
	}
}
