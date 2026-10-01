import JustTrackSDK
import SwiftUI

struct ContentView: View {
	@State private var initResult: InitResult?
	@State private var receivedDeeplinks: [String] = []

	var body: some View {
		if let initResult {
			TabView {
				InfoView(initResult: initResult).tabItem {
					Label("Info", systemImage: "faceid")
				}
				PublishingView(sdk: initResult.sdk, bridge: initResult.sdkBridge).tabItem {
					Label("Publish", systemImage: "paperplane")
				}
				DeeplinkView(sdk: initResult.sdk, receivedDeeplinks: $receivedDeeplinks).tabItem {
					Label("Deeplink", systemImage: "link")
				}
				PrivacyView(sdk: initResult.sdk).tabItem {
					Label("Privacy", systemImage: "hand.raised.fill")
				}
			}
			.onOpenURL { url in
				receivedDeeplinks.insert(url.absoluteString, at: 0)
				initResult.sdk.handle(deeplink: url)
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
