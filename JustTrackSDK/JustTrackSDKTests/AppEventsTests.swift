import XCTest

@testable import JustTrackSDK

final class AppEventsTests: XCTestCase {

	// MARK:  JtSessionTrackingEvent

	func testJtSessionTrackingEventWithDurationCorrectlyInitialized() {
		let sessionId = "test-session-123"
		let jtAction = "start"
		let duration = 120.5
		let unit = TimeUnitGroup.seconds
		let happenedAt = Date()

		let event = JtSessionTrackingEvent(sessionId: sessionId, jtAction: jtAction, duration: duration, unit: unit, happenedAt: happenedAt)

		XCTAssertEqual(event.name, JtSessionTrackingEvent.name)
		XCTAssertEqual(event.sessionId, sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], jtAction)
		XCTAssertEqual(event.value, duration)
		XCTAssertEqual(event.unit, unit.unitValue)
		XCTAssertNil(event.currency)
		XCTAssertEqual(event.happenedAt, happenedAt)
	}

	func testJtSessionTrackingEventWithoutDurationCorrectlyInitialized() {
		let sessionId = "test-session-123"
		let jtAction = "end"
		let happenedAt = Date()

		let event = JtSessionTrackingEvent(sessionId: sessionId, jtAction: jtAction, happenedAt: happenedAt)

		XCTAssertEqual(event.name, JtSessionTrackingEvent.name)
		XCTAssertEqual(event.sessionId, sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], jtAction)
		XCTAssertEqual(event.value, 0.0)
		XCTAssertNil(event.unit)
		XCTAssertNil(event.currency)
		XCTAssertEqual(event.happenedAt, happenedAt)
	}

	// MARK:  JtAppOpenEvent

	func testJtAppOpenEventWithDurationCorrectlyInitialized() {
		let sessionId = "test-session-123"
		let duration = 5.2
		let unit = TimeUnitGroup.seconds
		let happenedAt = Date()

		let event = JtAppOpenEvent(sessionId: sessionId, duration: duration, unit: unit, happenedAt: happenedAt)

		XCTAssertEqual(event.name, JtAppOpenEvent.name)
		XCTAssertEqual(event.sessionId, sessionId)
		XCTAssertEqual(event.value, duration)
		XCTAssertEqual(event.unit, unit.unitValue)
		XCTAssertNil(event.currency)
		XCTAssertEqual(event.happenedAt, happenedAt)
	}

	// MARK:  JtProgressionEvent

	func testJtProgressionEventWithDurationCorrectlyInitialized() {
		let jtAction = "complete"
		let jtProgression1 = "level"
		let jtProgression2 = "world-1"
		let jtProgression3 = "stage-3"
		let duration = 410.0
		let unit = TimeUnitGroup.seconds

		let event = JtProgressionEvent(
			jtAction: jtAction,
			jtProgression1: jtProgression1,
			jtProgression2: jtProgression2,
			jtProgression3: jtProgression3,
			duration: duration,
			unit: unit
		)

		XCTAssertEqual(event.name, JtProgressionEvent.name)
		XCTAssertNil(event.sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProgression1.rawValue], jtProgression1)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProgression2.rawValue], jtProgression2)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProgression3.rawValue], jtProgression3)
		XCTAssertEqual(event.value, duration)
		XCTAssertEqual(event.unit, unit.unitValue)
		XCTAssertNil(event.currency)
		XCTAssertNil(event.happenedAt)
	}

	func testJtProgressionEventWithoutDurationCorrectlyInitialized() {
		let jtAction = "start"
		let jtProgression1 = "level"

		let event = JtProgressionEvent(jtAction: jtAction, jtProgression1: jtProgression1)

		XCTAssertEqual(event.name, JtProgressionEvent.name)
		XCTAssertNil(event.sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProgression1.rawValue], jtProgression1)
		XCTAssertNil(event.getDimensions()[Dimension.jtProgression2.rawValue])
		XCTAssertNil(event.getDimensions()[Dimension.jtProgression3.rawValue])
		XCTAssertEqual(event.value, 0.0)
		XCTAssertNil(event.unit)
		XCTAssertNil(event.currency)
		XCTAssertNil(event.happenedAt)
	}

	// MARK:  JtResourceEvent

	func testJtResourceEventWithCountCorrectlyInitialized() {
		let jtAction = "spend"
		let jtItemType = "currency"
		let jtItemName = "coins"
		let jtItemId = "gold_coin"
		let count = 50.0

		let event = JtResourceEvent(
			jtAction: jtAction,
			jtItemType: jtItemType,
			jtItemName: jtItemName,
			jtItemId: jtItemId,
			count: count
		)

		XCTAssertEqual(event.name, JtResourceEvent.name)
		XCTAssertNil(event.sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtItemType.rawValue], jtItemType)
		XCTAssertEqual(event.getDimensions()[Dimension.jtItemName.rawValue], jtItemName)
		XCTAssertEqual(event.getDimensions()[Dimension.jtItemId.rawValue], jtItemId)
		XCTAssertEqual(event.value, count)
		XCTAssertEqual(event.unit, Unit.count)
		XCTAssertNil(event.currency)
		XCTAssertNil(event.happenedAt)
	}

	func testJtResourceEventWithoutCountCorrectlyInitialized() {
		let jtAction = "acquire"
		let jtItemType = "weapon"
		let jtItemName = "sword"

		let event = JtResourceEvent(jtAction: jtAction, jtItemType: jtItemType, jtItemName: jtItemName)

		XCTAssertEqual(event.name, JtResourceEvent.name)
		XCTAssertNil(event.sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtItemType.rawValue], jtItemType)
		XCTAssertEqual(event.getDimensions()[Dimension.jtItemName.rawValue], jtItemName)
		XCTAssertNil(event.getDimensions()[Dimension.jtItemId.rawValue])
		XCTAssertEqual(event.value, 0.0)
		XCTAssertNil(event.unit)
		XCTAssertNil(event.currency)
		XCTAssertNil(event.happenedAt)
	}

	// MARK:  JtPurchaseEvent

	func testJtPurchaseEventWithCountCorrectlyInitialized() {
		let jtAction = "purchase"
		let jtProductId = "premium_pack"
		let jtToken = "purchase-token-123"
		let jtProductType = "consumable"
		let count = 1.0

		let event = JtPurchaseEvent(
			jtAction: jtAction,
			jtProductId: jtProductId,
			jtToken: jtToken,
			jtProductType: jtProductType,
			count: count
		)

		XCTAssertEqual(event.name, JtPurchaseEvent.name)
		XCTAssertNil(event.sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProductId.rawValue], jtProductId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtToken.rawValue], jtToken)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProductType.rawValue], jtProductType)
		XCTAssertEqual(event.value, count)
		XCTAssertEqual(event.unit, Unit.count)
		XCTAssertNil(event.currency)
		XCTAssertNil(event.happenedAt)
	}

	func testJtPurchaseEventWithoutCountCorrectlyInitialized() {
		let jtAction = "select"
		let jtProductId = "gold_pack"
		let jtToken = "purchase-token-456"
		let jtProductType = "non_consumable"

		let event = JtPurchaseEvent(
			jtAction: jtAction,
			jtProductId: jtProductId,
			jtToken: jtToken,
			jtProductType: jtProductType
		)

		XCTAssertEqual(event.name, JtPurchaseEvent.name)
		XCTAssertNil(event.sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProductId.rawValue], jtProductId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtToken.rawValue], jtToken)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProductType.rawValue], jtProductType)
		XCTAssertEqual(event.value, 0.0)
		XCTAssertNil(event.unit)
		XCTAssertNil(event.currency)
		XCTAssertNil(event.happenedAt)
	}

	func testJtPurchaseEventWithActionEnumAndCountCorrectlyInitialized() {
		let jtAction = JtPurchaseEvent.Action.view
		let jtProductId = "premium_pack"
		let jtToken = "purchase-token-789"
		let jtProductType = "consumable"
		let count = 2.0

		let event = JtPurchaseEvent(
			jtAction: jtAction,
			jtProductId: jtProductId,
			jtToken: jtToken,
			jtProductType: jtProductType,
			count: count
		)

		XCTAssertEqual(event.name, JtPurchaseEvent.name)
		XCTAssertNil(event.sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], jtAction.rawValue)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProductId.rawValue], jtProductId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtToken.rawValue], jtToken)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProductType.rawValue], jtProductType)
		XCTAssertEqual(event.value, count)
		XCTAssertEqual(event.unit, Unit.count)
		XCTAssertNil(event.currency)
		XCTAssertNil(event.happenedAt)
	}

	func testJtPurchaseEventWithActionEnumWithoutCountCorrectlyInitialized() {
		let jtAction = JtPurchaseEvent.Action.click
		let jtProductId = "gold_pack"
		let jtToken = "purchase-token-012"
		let jtProductType = "non_consumable"

		let event = JtPurchaseEvent(
			jtAction: jtAction,
			jtProductId: jtProductId,
			jtToken: jtToken,
			jtProductType: jtProductType
		)

		XCTAssertEqual(event.name, JtPurchaseEvent.name)
		XCTAssertNil(event.sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], jtAction.rawValue)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProductId.rawValue], jtProductId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtToken.rawValue], jtToken)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProductType.rawValue], jtProductType)
		XCTAssertEqual(event.value, 0.0)
		XCTAssertNil(event.unit)
		XCTAssertNil(event.currency)
		XCTAssertNil(event.happenedAt)
	}

	// MARK:  JtAdEvent

	func testJtAdEventWithDurationCorrectlyInitialized() {
		let jtAction = "show"
		let jtAdNetwork = "AdMob"
		let jtAdPlacement = "level_complete"
		let jtAdUnit = "rewarded_video"
		let duration = 30.0
		let unit = TimeUnitGroup.seconds

		let event = JtAdEvent(
			jtAction: jtAction,
			jtAdNetwork: jtAdNetwork,
			jtAdPlacement: jtAdPlacement,
			jtAdUnit: jtAdUnit,
			duration: duration,
			unit: unit
		)

		XCTAssertEqual(event.name, JtAdEvent.name)
		XCTAssertNil(event.sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdNetwork.rawValue], jtAdNetwork)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdPlacement.rawValue], jtAdPlacement)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdUnit.rawValue], jtAdUnit)
		XCTAssertNil(event.getDimensions()[Dimension.jtAdBundleId.rawValue])
		XCTAssertNil(event.getDimensions()[Dimension.jtAdInstanceName.rawValue])
		XCTAssertNil(event.getDimensions()[Dimension.jtAdSdk.rawValue])
		XCTAssertNil(event.getDimensions()[Dimension.jtAdSegment.rawValue])
		XCTAssertNil(event.getDimensions()[Dimension.jtAdTestGroup.rawValue])
		XCTAssertEqual(event.value, duration)
		XCTAssertEqual(event.unit, unit.unitValue)
		XCTAssertNil(event.currency)
		XCTAssertNil(event.happenedAt)
	}

	func testJtAdEventWithoutDurationCorrectlyInitialized() {
		let jtAction = "click"
		let jtAdNetwork = "Unity"
		let jtAdPlacement = "main_menu"

		let event = JtAdEvent(
			jtAction: jtAction,
			jtAdNetwork: jtAdNetwork,
			jtAdPlacement: jtAdPlacement
		)

		XCTAssertEqual(event.name, JtAdEvent.name)
		XCTAssertNil(event.sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdNetwork.rawValue], jtAdNetwork)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdPlacement.rawValue], jtAdPlacement)
		XCTAssertNil(event.getDimensions()[Dimension.jtAdUnit.rawValue])
		XCTAssertEqual(event.value, 0.0)
		XCTAssertNil(event.unit)
		XCTAssertNil(event.currency)
		XCTAssertNil(event.happenedAt)
	}

	// MARK:  JtLoginEvent

	func testJtLoginEventWithMethodCorrectlyInitialized() {
		let jtAction = "login"
		let jtMethod = "facebook"

		let event = JtLoginEvent(jtAction: jtAction, jtMethod: jtMethod)

		XCTAssertEqual(event.name, JtLoginEvent.name)
		XCTAssertNil(event.sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtMethod.rawValue], jtMethod)
		XCTAssertEqual(event.value, 0.0)
		XCTAssertNil(event.unit)
		XCTAssertNil(event.currency)
		XCTAssertNil(event.happenedAt)
	}

	func testJtLoginEventWithoutMethodCorrectlyInitialized() {
		let jtAction = "logout"

		let event = JtLoginEvent(jtAction: jtAction)

		XCTAssertEqual(event.name, JtLoginEvent.name)
		XCTAssertNil(event.sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], jtAction)
		XCTAssertNil(event.getDimensions()[Dimension.jtMethod.rawValue])
		XCTAssertEqual(event.value, 0.0)
		XCTAssertNil(event.unit)
		XCTAssertNil(event.currency)
		XCTAssertNil(event.happenedAt)
	}

	// MARK:  JtDeeplinkHandledEvent

	func testJtDeeplinkHandledEventCorrectlyInitialized() {
		let sessionId = "test-session-123"
		let jtUrl = "app://open/product/123"
		let happenedAt = Date()

		let event = JtDeeplinkHandledEvent(sessionId: sessionId, jtUrl: jtUrl, happenedAt: happenedAt)

		XCTAssertEqual(event.name, JtDeeplinkHandledEvent.name)
		XCTAssertEqual(event.sessionId, sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtUrl.rawValue], jtUrl)
		XCTAssertEqual(event.value, 0.0)
		XCTAssertNil(event.unit)
		XCTAssertNil(event.currency)
		XCTAssertEqual(event.happenedAt, happenedAt)
	}

	// MARK:  JtDeeplinkNotHandledEvent

	func testJtDeeplinkNotHandledEventCorrectlyInitialized() {
		let sessionId = "test-session-123"
		let jtUrl = "app://open/unknown/route"
		let happenedAt = Date()

		let event = JtDeeplinkNotHandledEvent(sessionId: sessionId, jtUrl: jtUrl, happenedAt: happenedAt)

		XCTAssertEqual(event.name, JtDeeplinkNotHandledEvent.name)
		XCTAssertEqual(event.sessionId, sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtUrl.rawValue], jtUrl)
		XCTAssertEqual(event.value, 0.0)
		XCTAssertNil(event.unit)
		XCTAssertNil(event.currency)
		XCTAssertEqual(event.happenedAt, happenedAt)
	}

	// MARK:  JtTrackingPermissionEvent

	func testJtTrackingPermissionEventCorrectlyInitialized() {
		let jtAction = "authorized"
		let happenedAt = Date()

		let event = JtTrackingPermissionEvent(jtAction: jtAction, happenedAt: happenedAt)

		XCTAssertEqual(event.name, JtTrackingPermissionEvent.name)
		XCTAssertNil(event.sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], jtAction)
		XCTAssertEqual(event.value, 0.0)
		XCTAssertNil(event.unit)
		XCTAssertNil(event.currency)
		XCTAssertEqual(event.happenedAt, happenedAt)
	}

	// MARK:  JtAppInstallEvent

	func testJtAppInstallEventCorrectlyInitialized() {
		let sessionId = "install-session-1"
		let duration = 2.5
		let unit = TimeUnitGroup.seconds
		let happenedAt = Date()

		let event = JtAppInstallEvent(sessionId: sessionId, duration: duration, unit: unit, happenedAt: happenedAt)

		XCTAssertEqual(event.name, JtAppInstallEvent.name)
		XCTAssertEqual(event.sessionId, sessionId)
		XCTAssertEqual(event.value, duration)
		XCTAssertEqual(event.unit, unit.unitValue)
		XCTAssertNil(event.currency)
		XCTAssertEqual(event.happenedAt, happenedAt)
	}

	// MARK:  JtProgressionEvent (convenience inits with Action enum)

	func testJtProgressionEventConvenienceInitWithActionEnumAndDuration() {
		let event = JtProgressionEvent(
			jtAction: .complete,
			jtProgression1: "world-1",
			jtProgression2: "level-5",
			jtProgression3: "boss",
			duration: 300.0,
			unit: .seconds
		)

		XCTAssertEqual(event.name, JtProgressionEvent.name)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], "complete")
		XCTAssertEqual(event.getDimensions()[Dimension.jtProgression1.rawValue], "world-1")
		XCTAssertEqual(event.getDimensions()[Dimension.jtProgression2.rawValue], "level-5")
		XCTAssertEqual(event.getDimensions()[Dimension.jtProgression3.rawValue], "boss")
		XCTAssertEqual(event.value, 300.0)
		XCTAssertEqual(event.unit, TimeUnitGroup.seconds.unitValue)
	}

	func testJtProgressionEventConvenienceInitWithActionEnumWithoutDuration() {
		let event = JtProgressionEvent(
			jtAction: .start,
			jtProgression1: "tutorial"
		)

		XCTAssertEqual(event.name, JtProgressionEvent.name)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], "start")
		XCTAssertEqual(event.getDimensions()[Dimension.jtProgression1.rawValue], "tutorial")
		XCTAssertEqual(event.value, 0.0)
		XCTAssertNil(event.unit)
	}

	// MARK:  JtAdInternalEvent

	func testJtAdInternalEventCorrectlyInitialized() {
		let happenedAt = Date()
		let revenue = Money(value: 0.05, currency: "USD")

		let event = JtAdInternalEvent(
			jtAction: "impression",
			jtAdBundleId: "com.example.ad",
			jtAdInstanceName: "rewarded_1",
			jtAdNetwork: "AdMob",
			jtAdPlacement: "level_end",
			jtAdSdk: "GoogleAds",
			jtAdSegment: "high_value",
			jtAdUnit: "rewarded_video",
			jtAdTestGroup: "group_a",
			revenue: revenue,
			happenedAt: happenedAt
		)

		XCTAssertEqual(event.name, JtAdInternalEvent.name)
		XCTAssertNil(event.sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], "impression")
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdBundleId.rawValue], "com.example.ad")
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdInstanceName.rawValue], "rewarded_1")
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdNetwork.rawValue], "AdMob")
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdPlacement.rawValue], "level_end")
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdSdk.rawValue], "GoogleAds")
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdSegment.rawValue], "high_value")
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdUnit.rawValue], "rewarded_video")
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdTestGroup.rawValue], "group_a")
		XCTAssertEqual(event.value, 0.05)
		XCTAssertEqual(event.currency, "USD")
		XCTAssertNil(event.unit)
		XCTAssertEqual(event.happenedAt, happenedAt)
	}

	// MARK:  JtPurchaseInternalEvent

	func testJtPurchaseInternalEventCorrectlyInitialized() {
		let happenedAt = Date()
		let revenue = Money(value: 4.99, currency: "EUR")

		let event = JtPurchaseInternalEvent(
			jtAction: "purchase",
			jtProductId: "premium_sub",
			jtToken: "token-abc-123",
			jtProductType: "subscription",
			revenue: revenue,
			happenedAt: happenedAt
		)

		XCTAssertEqual(event.name, JtPurchaseInternalEvent.name)
		XCTAssertNil(event.sessionId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.rawValue], "purchase")
		XCTAssertEqual(event.getDimensions()[Dimension.jtProductId.rawValue], "premium_sub")
		XCTAssertEqual(event.getDimensions()[Dimension.jtToken.rawValue], "token-abc-123")
		XCTAssertEqual(event.getDimensions()[Dimension.jtProductType.rawValue], "subscription")
		XCTAssertEqual(event.value, 4.99)
		XCTAssertEqual(event.currency, "EUR")
		XCTAssertNil(event.unit)
		XCTAssertEqual(event.happenedAt, happenedAt)
	}
}
