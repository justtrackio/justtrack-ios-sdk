import Foundation
import XCTest

@testable import JustTrackSDK

final class DimensionTests: XCTestCase {
	func testAllDimensionRawValues() {
		let expectedValues: [JustTrackSDK.Dimension: String] = [
			.jtAction: "jt_action",
			.jtAdBundleId: "jt_ad_bundle_id",
			.jtAdInstanceName: "jt_ad_instance_name",
			.jtAdNetwork: "jt_ad_network",
			.jtAdPlacement: "jt_ad_placement",
			.jtAdSdk: "jt_ad_sdk",
			.jtAdSegment: "jt_ad_segment",
			.jtAdTestGroup: "jt_ad_test_group",
			.jtAdUnit: "jt_ad_unit",
			.jtCategory: "jt_category",
			.jtConnectionType: "jt_connection_type",
			.jtContext: "jt_context",
			.jtDetail: "jt_detail",
			.jtGlobal0: "jt_global_0",
			.jtGlobal1: "jt_global_1",
			.jtGlobal2: "jt_global_2",
			.jtItemId: "jt_item_id",
			.jtItemName: "jt_item_name",
			.jtItemType: "jt_item_type",
			.jtLocation: "jt_location",
			.jtMethod: "jt_method",
			.jtProductId: "jt_product_id",
			.jtProductType: "jt_product_type",
			.jtProgression1: "jt_progression_1",
			.jtProgression2: "jt_progression_2",
			.jtProgression3: "jt_progression_3",
			.jtState: "jt_state",
			.jtToken: "jt_token",
			.jtTrigger: "jt_trigger",
			.jtUrl: "jt_url",
		]

		for (dimension, expected) in expectedValues {
			XCTAssertEqual(dimension.rawValue, expected, "Dimension \(dimension) should have string value '\(expected)'")
		}
	}
}
