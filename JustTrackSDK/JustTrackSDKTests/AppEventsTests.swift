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
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.stringValue], jtAction)
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
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.stringValue], jtAction)
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
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.stringValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProgression1.stringValue], jtProgression1)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProgression2.stringValue], jtProgression2)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProgression3.stringValue], jtProgression3)
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
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.stringValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProgression1.stringValue], jtProgression1)
		XCTAssertNil(event.getDimensions()[Dimension.jtProgression2.stringValue])
		XCTAssertNil(event.getDimensions()[Dimension.jtProgression3.stringValue])
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
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.stringValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtItemType.stringValue], jtItemType)
		XCTAssertEqual(event.getDimensions()[Dimension.jtItemName.stringValue], jtItemName)
		XCTAssertEqual(event.getDimensions()[Dimension.jtItemId.stringValue], jtItemId)
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
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.stringValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtItemType.stringValue], jtItemType)
		XCTAssertEqual(event.getDimensions()[Dimension.jtItemName.stringValue], jtItemName)
		XCTAssertNil(event.getDimensions()[Dimension.jtItemId.stringValue])
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
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.stringValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProductId.stringValue], jtProductId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtToken.stringValue], jtToken)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProductType.stringValue], jtProductType)
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
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.stringValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProductId.stringValue], jtProductId)
		XCTAssertEqual(event.getDimensions()[Dimension.jtToken.stringValue], jtToken)
		XCTAssertEqual(event.getDimensions()[Dimension.jtProductType.stringValue], jtProductType)
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
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.stringValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdNetwork.stringValue], jtAdNetwork)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdPlacement.stringValue], jtAdPlacement)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdUnit.stringValue], jtAdUnit)
		XCTAssertNil(event.getDimensions()[Dimension.jtAdBundleId.stringValue])
		XCTAssertNil(event.getDimensions()[Dimension.jtAdInstanceName.stringValue])
		XCTAssertNil(event.getDimensions()[Dimension.jtAdSdk.stringValue])
		XCTAssertNil(event.getDimensions()[Dimension.jtAdSegment.stringValue])
		XCTAssertNil(event.getDimensions()[Dimension.jtAdTestGroup.stringValue])
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
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.stringValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdNetwork.stringValue], jtAdNetwork)
		XCTAssertEqual(event.getDimensions()[Dimension.jtAdPlacement.stringValue], jtAdPlacement)
		XCTAssertNil(event.getDimensions()[Dimension.jtAdUnit.stringValue])
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
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.stringValue], jtAction)
		XCTAssertEqual(event.getDimensions()[Dimension.jtMethod.stringValue], jtMethod)
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
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.stringValue], jtAction)
		XCTAssertNil(event.getDimensions()[Dimension.jtMethod.stringValue])
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
		XCTAssertEqual(event.getDimensions()[Dimension.jtUrl.stringValue], jtUrl)
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
		XCTAssertEqual(event.getDimensions()[Dimension.jtUrl.stringValue], jtUrl)
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
		XCTAssertEqual(event.getDimensions()[Dimension.jtAction.stringValue], jtAction)
		XCTAssertEqual(event.value, 0.0)
		XCTAssertNil(event.unit)
		XCTAssertNil(event.currency)
		XCTAssertEqual(event.happenedAt, happenedAt)
	}
}
