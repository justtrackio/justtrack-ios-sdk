import JustTrackSDK
import SwiftUI

struct PublishingView: View {
	private var sdk: JustTrackSdk
	private var bridge: SdkBridge

	init(
		sdk: JustTrackSdk,
		bridge: SdkBridge
	) {
		self.sdk = sdk
		self.bridge = bridge
	}

	var body: some View {
		NavigationView {
			List {
				Section(header: SectionHeaderView("New")) {
					NavigationLink("Event", destination: EventView(sdk: sdk))
					#if DEBUG
						NavigationLink("Message", destination: LogMessageView(bridge: bridge))
						NavigationLink("Metric", destination: LogMetricView(bridge: bridge))
					#endif
					NavigationLink("Ad Impression", destination: AdImpressionView(sdk: sdk))
					NavigationLink("Test Groups", destination: TestGroupView(sdk: sdk))
					NavigationLink("Remote Config", destination: RemoteConfigView(sdk: sdk))
				}
				Section(header: SectionHeaderView("Predefined")) {
					NavigationLink("Jt Events", destination: JtEventsView(sdk: sdk, bridge: bridge))
					NavigationLink("Spam", destination: SpamView(sdk: sdk, bridge: bridge))
					NavigationLink("Game", destination: GameView(sdk: sdk))
					NavigationLink("In-App Purchases", destination: InAppPurchasesView(sdk: sdk))
					NavigationLink("In-App Purchases V2", destination: InAppPurchasesViewV2(sdk: sdk))
					NavigationLink("Crash Reports", destination: CrashReportsView(bridge: bridge))
					NavigationLink("ANR Reports", destination: AnrView(bridge: bridge))
				}
			}
			.navigationBarTitle("Publish")
		}
	}
}
