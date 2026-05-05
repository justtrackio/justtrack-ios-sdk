import Foundation

final class PeriodicLogsPublisher {
	private static let initialDelay: TimeInterval = 5
	private static let pauseDelay: TimeInterval = 1
	private static let periodDelay: TimeInterval = 60

	private let fallback: Logger
	private let httpLogger: HttpLogger
	private var state: PeriodicLogsPublisherState
	private var nextScheduled: Int

	init(fallback: Logger, httpLogger: HttpLogger) {
		self.fallback = fallback
		self.httpLogger = httpLogger
		self.state = .stopped
		self.nextScheduled = 0
		start()
	}

	private func schedule(after delay: TimeInterval) {
		objc_sync_enter(self)
		let thisScheduled = nextScheduled + 1
		nextScheduled = thisScheduled
		objc_sync_exit(self)

		DispatchQueue.main.asyncAfter(
			deadline: .now() + delay,
			execute: {
				self.handle(thisScheduled)
			}
		)
	}

	private func handle(_ thisScheduled: Int) {
		objc_sync_enter(self)
		let state = self.state
		if state == .stopping {
			fallback.debug("PeriodicLogsPublisher: stopped")
			self.state = .stopped
		}
		let nextScheduled = self.nextScheduled
		objc_sync_exit(self)

		if state == .stopped {
			fallback.debug("PeriodicLogsPublisher: we are already stopped")
			return
		}

		fallback.debug("PeriodicLogsPublisher: sending to server")
		httpLogger.sendToServer()

		if state == .running {
			// only schedule next run if there hasn't been another run scheduled already
			if thisScheduled == nextScheduled {
				fallback.debug("PeriodicLogsPublisher: scheduled next run")
				schedule(after: Self.periodDelay)
			}
		}
	}

	func start() {
		objc_sync_enter(self)
		state = .running
		objc_sync_exit(self)

		fallback.debug("PeriodicLogsPublisher: started running")
		schedule(after: Self.initialDelay)
	}

	func pause() {
		httpLogger.sendToServer()

		objc_sync_enter(self)
		state = .stopping
		objc_sync_exit(self)

		fallback.debug("PeriodicLogsPublisher: initiating pause")
		schedule(after: Self.pauseDelay)
	}

	func stop() {
		objc_sync_enter(self)
		state = .stopped
		objc_sync_exit(self)

		fallback.debug("PeriodicLogsPublisher: set to stopped")
	}
}

private enum PeriodicLogsPublisherState {
	case running
	case stopping
	case stopped
}
