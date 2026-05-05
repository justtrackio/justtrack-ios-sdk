import JustTrackSDK
import SwiftUI

final class Impression: ObservableObject {
	@Published var unit: AdUnit = .banner
	@Published var sdkName: String = ""
	@Published var network: String = ""
	@Published var placement: String = ""
	@Published var testGroup: String = ""
	@Published var segmentName: String = ""
	@Published var instanceName: String = ""
	@Published var bundleId: String = ""
}
