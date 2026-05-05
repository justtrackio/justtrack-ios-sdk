import UIKit

protocol SessionManager: AnyObject {
	func start()
	func moveToForeground()
	func moveToBackground()
	func getLastSessionId(_ sdkRef: JustTrackSdkImpl) -> String
	func saveSession()
}

class SessionManagerImpl: SessionManager {
	weak var sdk: JustTrackSdkImpl?
	private var session: Session?
	private var lastSessionId: String?
	private weak var timer: Timer?

	init(_ sdk: JustTrackSdkImpl?) {
		self.sdk = sdk
		self.session = nil
		self.lastSessionId = nil
		self.timer = nil
	}

	func start() {
		reportLastSession()
		moveToForeground()
	}

	func getLastSessionId(_ sdkRef: JustTrackSdkImpl) -> String {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		if let session {
			return session.sessionId.value
		}

		if let lastSessionId {
			return lastSessionId
		}

		return startSession(sdkRef).sessionId.value
	}

	func moveToForeground() {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		if session == nil {
			if let sdk {
				_ = startSession(sdk)
			}
		}

		// we should be on the main thread, but just to be sure... so we have a run loop for our timer
		DispatchQueue.main.async {
			self.timer?.invalidate()
			self.timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
				self?.saveSession()
			}
		}
	}

	func moveToBackground() {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		timer?.invalidate()
		timer = nil
		endSession()
	}

	private func startSession(_ sdkRef: JustTrackSdkImpl) -> Session {
		if let session {
			return session
		}

		let newSession = Session()
		session = newSession
		_ = sdkRef.track(event: JtSessionTrackingEvent(sessionId: newSession.sessionId.value, jtAction: "start", happenedAt: Date()))

		return newSession
	}

	private func endSession() {
		guard let session = session else {
			return
		}

		lastSessionId = endSession(sessionToEnd: session, sessionLastTick: Date())
		self.session = nil
	}

	private func endSession(sessionToEnd: Session, sessionLastTick: Date) -> String {
		let sessionId = sessionToEnd.sessionId.value
		let duration = sessionLastTick.timeIntervalSince(sessionToEnd.sessionStart)
		_ = sdk?.track(event: JtSessionTrackingEvent(sessionId: sessionId, jtAction: "end", duration: duration, unit: .milliseconds, happenedAt: sessionLastTick))
		sessionToEnd.remove(from: .standard)

		return sessionId
	}

	private func reportLastSession() {
		if let lastSession = Session(restoreFrom: .standard) {
			_ = endSession(sessionToEnd: lastSession, sessionLastTick: lastSession.sessionLastTick)
		}
	}

	func saveSession() {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		session?.persist(storeTo: .standard)
	}
}

struct Session {
	internal static let key = "io.justtrack.attribution.session"

	fileprivate let sessionId: StringID
	fileprivate let sessionStart: Date
	fileprivate let sessionLastTick: Date

	fileprivate init() {
		sessionId = StringID()
		sessionStart = Date()
		sessionLastTick = sessionStart
	}

	fileprivate init?(restoreFrom: UserDefaults) {
		guard let dict = restoreFrom.dictionary(forKey: Session.key) else {
			return nil
		}

		guard let sessionIdString = dict["sessionId"] as? String else {
			return nil
		}
		guard let sessionId = StringID(value: sessionIdString) else {
			return nil
		}
		self.sessionId = sessionId

		guard let sessionStart = dict["sessionStart"] as? Date else {
			return nil
		}
		self.sessionStart = sessionStart

		guard let sessionLastTick = dict["sessionLastTick"] as? Date else {
			return nil
		}
		self.sessionLastTick = sessionLastTick
	}

	fileprivate func persist(storeTo: UserDefaults) {
		let dict: [String: Any] = [
			"sessionId": sessionId.value,
			"sessionStart": sessionStart,
			"sessionLastTick": Date(),
		]

		storeTo.setValue(dict, forKey: Session.key)
	}

	fileprivate func remove(from: UserDefaults) {
		from.removeObject(forKey: Session.key)
	}
}
