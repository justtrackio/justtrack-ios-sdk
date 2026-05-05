import Foundation

@testable import JustTrackSDK

class UserEventList {
	static func getEventsList() -> [AppEvent] {
		return [
			JtSessionTrackingEvent(
				sessionId: UUID().uuidString.lowercased(),
				jtAction: "start",
				happenedAt: Date()
			),
			JtAppOpenEvent(
				sessionId: UUID().uuidString.lowercased(),
				duration: 41,
				unit: .seconds,
				happenedAt: Date()
			),
			JtAppInstallEvent(
				sessionId: UUID().uuidString.lowercased(),
				duration: 41,
				unit: .seconds,
				happenedAt: Date()
			),
			JtDeeplinkHandledEvent(
				sessionId: UUID().uuidString.lowercased(),
				jtUrl: "https://google.com",
				happenedAt: Date()
			),
			JtDeeplinkNotHandledEvent(
				sessionId: UUID().uuidString.lowercased(),
				jtUrl: "https://swift.org",
				happenedAt: Date()
			),
			JtTrackingPermissionEvent(
				jtAction: "authorized",
				happenedAt: Date()
			),
			JtProgressionEvent(
				jtAction: "complete",
				jtProgression1: "level_1",
				jtProgression2: "level_1_1",
				jtProgression3: "level_1_1_1"
			),
			JtResourceEvent(
				jtAction: "source",
				jtItemType: "bundle_1",
				jtItemName: "item_1",
				jtItemId: "item_id_1",
				count: 41
			),
			JtPurchaseEvent(
				jtAction: "purchase",
				jtProductId: "product_id",
				jtToken: "token",
				jtProductType: "product",
				count: 1
			),
			JtAdEvent(
				jtAction: "load",
				jtAdBundleId: "ad_bundle_id",
				jtAdInstanceName: "ad_instance_name",
				jtAdNetwork: "ad_network",
				jtAdPlacement: "ad_placement",
				jtAdSdk: "ad_sdk",
				jtAdSegment: "ad_segment",
				jtAdUnit: "ad_unit",
				jtAdTestGroup: "ad_test_group",
				duration: 41,
				unit: .seconds
			),
			JtLoginEvent(
				jtAction: "success",
				jtMethod: "oauth"
			),
			JtAdInternalEvent(
				jtAction: "load",
				jtAdBundleId: "ad_bundle_id",
				jtAdInstanceName: "ad_instance_name",
				jtAdNetwork: "ad_network",
				jtAdPlacement: "ad_placement",
				jtAdSdk: "ad_sdk",
				jtAdSegment: "ad_segment",
				jtAdUnit: "ad_unit",
				jtAdTestGroup: "ad_test_group",
				revenue: Money(value: 41, currency: "EUR"),
				happenedAt: Date()
			),
			JtPurchaseInternalEvent(
				jtAction: "purchase",
				jtProductId: "product_id",
				jtToken: "token",
				jtProductType: "purchase",
				revenue: Money(value: 1, currency: "USD"),
				happenedAt: Date()
			),
		]
	}
}
