import JustTrackSDK
import SwiftUI

struct ContentView: View {
	@State private var initResult: InitResult?

	var body: some View {
		if let initResult {
			TabView {
				InfoView(initResult: initResult).tabItem {
					Label("Info", systemImage: "faceid")
				}
				PublishingView(sdk: initResult.sdk, bridge: initResult.sdkBridge).tabItem {
					Label("Publish", systemImage: "paperplane")
				}
				PrivacyView(sdk: initResult.sdk).tabItem {
					Label("Privacy", systemImage: "hand.raised.fill")
				}
			}
		} else {
			InitView { result in
				self.initResult = result
			}
		}
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}
