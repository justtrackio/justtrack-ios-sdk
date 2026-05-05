import JustTrackSDK
import SwiftUI

struct JtEventsView: View {
	private let sdk: JustTrackSdk
	private let bridge: SdkBridge

	init(
		sdk: JustTrackSdk,
		bridge: SdkBridge
	) {
		self.sdk = sdk
		self.bridge = bridge
	}

	var body: some View {
		ScrollView {
			VStack {
				VStack(alignment: .center) {
					DefaultButton("Publish all", action: publishAll)
					DefaultButton("Publish custom", action: publishCustom)
				}
				.frame(maxWidth: .infinity)
				.padding()
			}
		}
		.navigationTitle("Jt Events")
	}

	private func publishAll() {
		publishPublic()
		publishInternal()
	}

	private func publishCustom() {
		let event = AppEvent("custom_event_with_pred_dim")
			.add(dimension: Dimension.jtCategory, value: "category")
			.add(dimension: Dimension.jtContext, value: "context")
			.add(dimension: Dimension.jtLocation, value: "location")
			.add(dimension: Dimension.jtDetail, value: "detail")
			.add(dimension: Dimension.jtTrigger, value: "trigger")
			.add(dimension: Dimension.jtState, value: "state")
		_ = sdk.track(event: event)
	}

	private func publishPublic() {
		let events = [
			JtProgressionEvent(
				jtAction: "manual_testing_start",
				jtProgression1: "manual_testing_world",
				jtProgression2: "manual_testing_path",
				jtProgression3: "manual_testing_boss",
				duration: 0,
				unit: .milliseconds
			),
			JtProgressionEvent(
				jtAction: "manual_testing_fail",
				jtProgression1: "manual_testing_world",
				jtProgression2: "manual_testing_path",
				jtProgression3: "manual_testing_boss",
				duration: 10_000,
				unit: .milliseconds
			),
			JtResourceEvent(
				jtAction: "manual_testing_source",
				jtItemType: "manual_testing_weapon",
				jtItemName: "manual_testing_sword",
				jtItemId: "manual_testing_resource_id_1",
				count: 45
			),
			JtPurchaseEvent(
				jtAction: "manual_testing_subscription",
				jtProductId: "manual_testing_subscription_1",
				jtToken: "manual_testing_subscription_token_1",
				jtProductType: "manual_testing_subscription",
				count: 41
			),
			JtAdEvent(
				jtAction: "manual_testing_load",
				jtAdBundleId: "manual_testing_123",
				jtAdInstanceName: "manual_testing_xyz",
				jtAdNetwork: "manual_testing_adjoe",
				jtAdPlacement: "manual_testing_abc",
				jtAdSdk: "manual_testing_applovin",
				jtAdSegment: "manual_testing_random",
				jtAdUnit: "manual_testing_banner",
				jtAdTestGroup: "2",
				duration: 41,
				unit: .milliseconds
			),
			JtLoginEvent(
				jtAction: "manual_testing_success",
				jtMethod: "manual_testing_google"
			),
		]

		for event in events {
			_ = sdk.track(event: event)
		}
	}

	private func publishInternal() {
		bridge.sendInternalEvents()
	}
}
