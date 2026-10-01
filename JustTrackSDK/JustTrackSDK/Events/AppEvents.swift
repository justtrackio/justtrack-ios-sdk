// swift-format-ignore-file

/// The session of the user either start or end. The duration denotes the time the user stayed in the app. Event is automatically send by the justtrack SDK.
final class JtSessionTrackingEvent: AppEvent {
	static let name: String = "jt_session_tracking"

	init(sessionId: String, jtAction: String, duration: Double, unit: TimeUnitGroup, happenedAt: Date) {
		super.init(name: Self.name, sessionId: sessionId, dimensions: [:], value: nil, unit: nil, currency: nil, happenedAt: happenedAt)
		_ = add(dimension: .jtAction, value: jtAction)
		_ = set(value: duration, unit: unit.unitValue)
	}

	init(sessionId: String, jtAction: String, happenedAt: Date) {
		super.init(name: Self.name, sessionId: sessionId, dimensions: [:], value: nil, unit: nil, currency: nil, happenedAt: happenedAt)
		_ = add(dimension: .jtAction, value: jtAction)
	}

}

/// The app was launched by the user and did not run before. The duration denotes the time the app was running before the SDK was initialized. Event is automatically send by the justtrack SDK.
final class JtAppOpenEvent: AppEvent {
	static let name: String = "jt_app_open"

	init(sessionId: String, duration: Double, unit: TimeUnitGroup, happenedAt: Date) {
		super.init(name: Self.name, sessionId: sessionId, dimensions: [:], value: nil, unit: nil, currency: nil, happenedAt: happenedAt)
		_ = set(value: duration, unit: unit.unitValue)
	}

}

/// The app was installed by the user and launched for the first time. Event is automatically send by the justtrack SDK.
final class JtAppInstallEvent: AppEvent {
	static let name: String = "jt_app_install"

	init(sessionId: String, duration: Double, unit: TimeUnitGroup, happenedAt: Date) {
		super.init(name: Self.name, sessionId: sessionId, dimensions: [:], value: nil, unit: nil, currency: nil, happenedAt: happenedAt)
		_ = set(value: duration, unit: unit.unitValue)
	}

}

final class JtDeeplinkHandledEvent: AppEvent {
	static let name: String = "jt_deeplink_handled"

	init(sessionId: String, jtUrl: String, happenedAt: Date) {
		super.init(name: Self.name, sessionId: sessionId, dimensions: [:], value: nil, unit: nil, currency: nil, happenedAt: happenedAt)
		_ = add(dimension: .jtUrl, value: jtUrl)
	}

}

final class JtDeeplinkNotHandledEvent: AppEvent {
	static let name: String = "jt_deeplink_not_handled"

	init(sessionId: String, jtUrl: String, happenedAt: Date) {
		super.init(name: Self.name, sessionId: sessionId, dimensions: [:], value: nil, unit: nil, currency: nil, happenedAt: happenedAt)
		_ = add(dimension: .jtUrl, value: jtUrl)
	}

}

/// Event is automatically send by the justtrack SDK upon requesting permission for App Transparency Tracking.
final class JtTrackingPermissionEvent: AppEvent {
	static let name: String = "jt_tracking_permission"

	init(jtAction: String, happenedAt: Date) {
		super.init(name: Self.name, sessionId: nil, dimensions: [:], value: nil, unit: nil, currency: nil, happenedAt: happenedAt)
		_ = add(dimension: .jtAction, value: jtAction)
	}

}

/// You can use this event to track all details related to the progression of the user in the game.
public final class JtProgressionEvent: AppEvent {

	public enum Action: String {
		case start
		case complete
		case fail
	}

	static let name: String = "jt_progression"

	public convenience init(jtAction: Action, jtProgression1: String? = nil, jtProgression2: String? = nil, jtProgression3: String? = nil, duration: Double, unit: TimeUnitGroup) {
		self.init(jtAction: jtAction.rawValue, jtProgression1: jtProgression1, jtProgression2: jtProgression2, jtProgression3: jtProgression3, duration: duration, unit: unit)
	}

	public convenience init(jtAction: Action, jtProgression1: String? = nil, jtProgression2: String? = nil, jtProgression3: String? = nil) {
		self.init(jtAction: jtAction.rawValue, jtProgression1: jtProgression1, jtProgression2: jtProgression2, jtProgression3: jtProgression3)
	}

	public init(jtAction: String, jtProgression1: String? = nil, jtProgression2: String? = nil, jtProgression3: String? = nil, duration: Double, unit: TimeUnitGroup) {
		super.init(Self.name)
		_ = add(dimension: .jtAction, value: jtAction)
		_ = add(dimension: .jtProgression1, value: jtProgression1)
		_ = add(dimension: .jtProgression2, value: jtProgression2)
		_ = add(dimension: .jtProgression3, value: jtProgression3)
		_ = set(value: duration, unit: unit.unitValue)
	}

	public init(jtAction: String, jtProgression1: String? = nil, jtProgression2: String? = nil, jtProgression3: String? = nil) {
		super.init(Self.name)
		_ = add(dimension: .jtAction, value: jtAction)
		_ = add(dimension: .jtProgression1, value: jtProgression1)
		_ = add(dimension: .jtProgression2, value: jtProgression2)
		_ = add(dimension: .jtProgression3, value: jtProgression3)
	}

}

/// You can use this event to capture details of items removed from the user's inventory. It could be either weapons or in-app currency.
public final class JtResourceEvent: AppEvent {
	static let name: String = "jt_resource"

	public init(jtAction: String, jtItemType: String? = nil, jtItemName: String? = nil, jtItemId: String? = nil, count: Double) {
		super.init(Self.name)
		_ = add(dimension: .jtAction, value: jtAction)
		_ = add(dimension: .jtItemType, value: jtItemType)
		_ = add(dimension: .jtItemName, value: jtItemName)
		_ = add(dimension: .jtItemId, value: jtItemId)
		_ = set(value: count, unit: .count)
	}

	public init(jtAction: String, jtItemType: String? = nil, jtItemName: String? = nil, jtItemId: String? = nil) {
		super.init(Self.name)
		_ = add(dimension: .jtAction, value: jtAction)
		_ = add(dimension: .jtItemType, value: jtItemType)
		_ = add(dimension: .jtItemName, value: jtItemName)
		_ = add(dimension: .jtItemId, value: jtItemId)
	}

}

/// Event that tracks and reports in-app purchase related details e.g. user selected some item from store, confirmed purchase, added to cart etc. In case of a successful purchase or subscription justtrack automatically tracks and reports the event so there is no need to generate that event.
public final class JtPurchaseEvent: AppEvent {
	static let name: String = "jt_purchase"

	public enum Action: String {
		case view
		case click
	}

	public init(jtAction: String, jtProductId: String, jtToken: String? = nil, jtProductType: String, count: Double) {
		super.init(Self.name)
		_ = add(dimension: .jtAction, value: jtAction)
		_ = add(dimension: .jtProductId, value: jtProductId)
		_ = add(dimension: .jtToken, value: jtToken)
		_ = add(dimension: .jtProductType, value: jtProductType)
		_ = set(value: count, unit: .count)
	}

	public init(jtAction: String, jtProductId: String, jtToken: String? = nil, jtProductType: String) {
		super.init(Self.name)
		_ = add(dimension: .jtAction, value: jtAction)
		_ = add(dimension: .jtProductId, value: jtProductId)
		_ = add(dimension: .jtToken, value: jtToken)
		_ = add(dimension: .jtProductType, value: jtProductType)
	}

	public convenience init(jtAction: Action, jtProductId: String, jtToken: String? = nil, jtProductType: String, count: Double) {
		self.init(jtAction: jtAction.rawValue, jtProductId: jtProductId, jtToken: jtToken, jtProductType: jtProductType, count: count)
	}

	public convenience init(jtAction: Action, jtProductId: String, jtToken: String? = nil, jtProductType: String) {
		self.init(jtAction: jtAction.rawValue, jtProductId: jtProductId, jtToken: jtToken, jtProductType: jtProductType)
	}

}

/// You can use this event to capture details of an ad like load, click, show etc. Ad impressions are automatically tracked by justtrack SDK for integrated networks. For networks not integrated you can use forwardAdImpression().
public final class JtAdEvent: AppEvent {
	static let name: String = "jt_ad"

	public init(jtAction: String, jtAdBundleId: String? = nil, jtAdInstanceName: String? = nil, jtAdNetwork: String? = nil, jtAdPlacement: String? = nil, jtAdSdk: String? = nil, jtAdSegment: String? = nil, jtAdUnit: String? = nil, jtAdTestGroup: String? = nil, duration: Double, unit: TimeUnitGroup) {
		super.init(Self.name)
		_ = add(dimension: .jtAction, value: jtAction)
		_ = add(dimension: .jtAdBundleId, value: jtAdBundleId)
		_ = add(dimension: .jtAdInstanceName, value: jtAdInstanceName)
		_ = add(dimension: .jtAdNetwork, value: jtAdNetwork)
		_ = add(dimension: .jtAdPlacement, value: jtAdPlacement)
		_ = add(dimension: .jtAdSdk, value: jtAdSdk)
		_ = add(dimension: .jtAdSegment, value: jtAdSegment)
		_ = add(dimension: .jtAdUnit, value: jtAdUnit)
		_ = add(dimension: .jtAdTestGroup, value: jtAdTestGroup)
		_ = set(value: duration, unit: unit.unitValue)
	}

	public init(jtAction: String, jtAdBundleId: String? = nil, jtAdInstanceName: String? = nil, jtAdNetwork: String? = nil, jtAdPlacement: String? = nil, jtAdSdk: String? = nil, jtAdSegment: String? = nil, jtAdUnit: String? = nil, jtAdTestGroup: String? = nil) {
		super.init(Self.name)
		_ = add(dimension: .jtAction, value: jtAction)
		_ = add(dimension: .jtAdBundleId, value: jtAdBundleId)
		_ = add(dimension: .jtAdInstanceName, value: jtAdInstanceName)
		_ = add(dimension: .jtAdNetwork, value: jtAdNetwork)
		_ = add(dimension: .jtAdPlacement, value: jtAdPlacement)
		_ = add(dimension: .jtAdSdk, value: jtAdSdk)
		_ = add(dimension: .jtAdSegment, value: jtAdSegment)
		_ = add(dimension: .jtAdUnit, value: jtAdUnit)
		_ = add(dimension: .jtAdTestGroup, value: jtAdTestGroup)
	}

}

/// To capture all details related to user login events.
public final class JtLoginEvent: AppEvent {
	static let name: String = "jt_login"

	public init(jtAction: String, jtMethod: String? = nil) {
		super.init(Self.name)
		_ = add(dimension: .jtAction, value: jtAction)
		_ = add(dimension: .jtMethod, value: jtMethod)
	}

}

/// This is an internal event to pass ad impression information.
final class JtAdInternalEvent: AppEvent {
	static let name: String = "jt_ad"

	init(jtAction: String, jtAdBundleId: String? = nil, jtAdInstanceName: String? = nil, jtAdNetwork: String? = nil, jtAdPlacement: String? = nil, jtAdSdk: String? = nil, jtAdSegment: String? = nil, jtAdUnit: String? = nil, jtAdTestGroup: String? = nil, revenue: Money? = nil, happenedAt: Date) {
		super.init(name: Self.name, sessionId: nil, dimensions: [:], value: nil, unit: nil, currency: nil, happenedAt: happenedAt)
		_ = add(dimension: .jtAction, value: jtAction)
		_ = add(dimension: .jtAdBundleId, value: jtAdBundleId)
		_ = add(dimension: .jtAdInstanceName, value: jtAdInstanceName)
		_ = add(dimension: .jtAdNetwork, value: jtAdNetwork)
		_ = add(dimension: .jtAdPlacement, value: jtAdPlacement)
		_ = add(dimension: .jtAdSdk, value: jtAdSdk)
		_ = add(dimension: .jtAdSegment, value: jtAdSegment)
		_ = add(dimension: .jtAdUnit, value: jtAdUnit)
		_ = add(dimension: .jtAdTestGroup, value: jtAdTestGroup)
		_ = set(money: revenue)
	}

}

/// This is internal event.
final class JtPurchaseInternalEvent: AppEvent {
	static let name: String = "jt_purchase"

	init(jtAction: String, jtProductId: String, jtToken: String, jtProductType: String, revenue: Money? = nil, happenedAt: Date) {
		super.init(name: Self.name, sessionId: nil, dimensions: [:], value: nil, unit: nil, currency: nil, happenedAt: happenedAt)
		_ = add(dimension: .jtAction, value: jtAction)
		_ = add(dimension: .jtProductId, value: jtProductId)
		_ = add(dimension: .jtToken, value: jtToken)
		_ = add(dimension: .jtProductType, value: jtProductType)
		_ = set(money: revenue)
	}

}
