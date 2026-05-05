/// An enum describing all possible dimensions of a UserEvent.
public enum Dimension: Int {
	case jtAction
	case jtAdBundleId
	case jtAdInstanceName
	case jtAdNetwork
	case jtAdPlacement
	case jtAdSdk
	case jtAdSegment
	case jtAdTestGroup
	case jtAdUnit
	case jtCategory
	case jtContext
	case jtDetail
	case jtItemId
	case jtItemName
	case jtItemType
	case jtLocation
	case jtMethod
	case jtProductId
	case jtProductType
	case jtProgression1
	case jtProgression2
	case jtProgression3
	case jtState
	case jtToken
	case jtTrigger
	case jtUrl

	var stringValue: String {
		switch self {
		case .jtAction:
			return "jt_action"
		case .jtAdBundleId:
			return "jt_ad_bundle_id"
		case .jtAdInstanceName:
			return "jt_ad_instance_name"
		case .jtAdNetwork:
			return "jt_ad_network"
		case .jtAdPlacement:
			return "jt_ad_placement"
		case .jtAdSdk:
			return "jt_ad_sdk"
		case .jtAdSegment:
			return "jt_ad_segment"
		case .jtAdTestGroup:
			return "jt_ad_test_group"
		case .jtAdUnit:
			return "jt_ad_unit"
		case .jtCategory:
			return "jt_category"
		case .jtContext:
			return "jt_context"
		case .jtDetail:
			return "jt_detail"
		case .jtItemId:
			return "jt_item_id"
		case .jtItemName:
			return "jt_item_name"
		case .jtItemType:
			return "jt_item_type"
		case .jtLocation:
			return "jt_location"
		case .jtMethod:
			return "jt_method"
		case .jtProductId:
			return "jt_product_id"
		case .jtProductType:
			return "jt_product_type"
		case .jtProgression1:
			return "jt_progression_1"
		case .jtProgression2:
			return "jt_progression_2"
		case .jtProgression3:
			return "jt_progression_3"
		case .jtState:
			return "jt_state"
		case .jtToken:
			return "jt_token"
		case .jtTrigger:
			return "jt_trigger"
		case .jtUrl:
			return "jt_url"
		}
	}
}
