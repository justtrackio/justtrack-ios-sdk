import JustTrackSDK
import SwiftUI

final class Event: ObservableObject {
	@Published var name: String = "custom_event_1"
	@Published var value: Double = 0.1
	@Published var unit: JustTrackSDK.Unit?
	@Published var dimensions: [String: String] = [:]
	@Published var currency: String = ""
}
