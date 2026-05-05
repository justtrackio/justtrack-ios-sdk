import Foundation

public enum AdUnit: String {
	case banner
	case interstitial
	case rewarded
	case rewardedInterstitial = "rewarded_interstitial"
	case native
	case appOpen = "app_open"

	var name: String {
		rawValue
	}
}
