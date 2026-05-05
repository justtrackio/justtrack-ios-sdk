@testable import JustTrackSDK

enum UserEventNameList {
	static let allEvents: [String] = [
		JtSessionTrackingEvent.name,
		JtAppOpenEvent.name,
		JtAppInstallEvent.name,
		JtDeeplinkHandledEvent.name,
		JtDeeplinkNotHandledEvent.name,
		JtTrackingPermissionEvent.name,
		JtProgressionEvent.name,
		JtResourceEvent.name,
		JtPurchaseEvent.name,
		JtAdEvent.name,
		JtLoginEvent.name,
		JtAdInternalEvent.name,
		JtPurchaseInternalEvent.name,
	]
}
