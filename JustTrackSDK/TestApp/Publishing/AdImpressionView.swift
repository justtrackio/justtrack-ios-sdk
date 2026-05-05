import JustTrackSDK
import SwiftUI

struct AdImpressionView: View {
	@ObservedObject private var impression = Impression()

	@State private var selectedUnitIndex: Int = 0
	private let units = [AdUnit.banner, .interstitial, .rewarded, .rewardedInterstitial, .native, .appOpen].map(\.rawValue)

	@State private var isDisplayingAlert = false
	@State private var alert: (title: String, message: String?)? {
		didSet {
			isDisplayingAlert = alert != nil
		}
	}

	@State private var isSending = false

	private let sdk: JustTrackSdk

	init(
		impression: Impression = Impression(),
		sdk: JustTrackSdk
	) {
		self.impression = impression
		self.sdk = sdk
	}

	var body: some View {
		VStack {
			List {
				VStack(alignment: .leading) {
					Spacer()

					ListItemTitleView("Unit")

					Spacer()

					ForEach(0..<units.count, id: \.self) { index in
						Text(units[index])
							.fontForListItemText()
							.foregroundColor(selectedUnitIndex == index ? .black : .gray)
							.onTapGesture {
								selectedUnitIndex = index
								impression.unit = AdUnit(rawValue: units[index]) ?? .banner
							}
						Spacer()
					}
				}

				VStack(alignment: .leading) {
					ListItemTitleView("SDK Name")

					TextField(
						"",
						text: $impression.sdkName
					)
					.fontForListItemText()
				}

				VStack(alignment: .leading) {
					ListItemTitleView("Network")

					TextField(
						"",
						text: $impression.network
					)
					.fontForListItemText()
				}

				VStack(alignment: .leading) {
					ListItemTitleView("Placement")

					TextField(
						"",
						text: $impression.placement
					)
					.fontForListItemText()
				}

				VStack(alignment: .leading) {
					ListItemTitleView("Test Group")

					TextField(
						"",
						text: $impression.testGroup
					)
					.fontForListItemText()
				}

				VStack(alignment: .leading) {
					ListItemTitleView("Segment Name")

					TextField(
						"",
						text: $impression.segmentName
					)
					.fontForListItemText()
				}

				VStack(alignment: .leading) {
					ListItemTitleView("Instance Name")

					TextField(
						"",
						text: $impression.instanceName
					)
					.fontForListItemText()
				}

				VStack(alignment: .leading) {
					ListItemTitleView("Bundle ID")

					TextField(
						"",
						text: $impression.bundleId
					)
					.fontForListItemText()
				}
			}
		}
		.navigationTitle("Ad Impression")
		.navigationBarItems(
			trailing: Button(action: publish) {
				Text("Send")
					.fontWeight(.bold)
			}
		)
		.alert(isPresented: $isDisplayingAlert) {
			Alert(
				title: Text(alert?.title ?? ""),
				message: Text(alert?.message ?? ""),
				dismissButton: .default(Text("OK")) {
					alert = nil
					isSending = false
				}
			)
		}
	}

	private func publish() {
		let adImpression = AdImpression(
			unit: impression.unit,
			sdkName: impression.sdkName
		)
		.set(network: impression.network.nilIfEmpty)
		.set(placement: impression.placement.nilIfEmpty)
		.set(testGroup: impression.testGroup.nilIfEmpty)
		.set(segmentName: impression.segmentName.nilIfEmpty)
		.set(instanceName: impression.instanceName.nilIfEmpty)
		.set(bundleId: impression.bundleId.nilIfEmpty)

		sdk.forward(adImpression: adImpression).observe { result in
			switch result {
			case .failure:
				alert = ("Failure", "Failed to forward impression.")
			case .success:
				alert = ("Success", "The impression has been forwarded.")
			}
		}
	}
}

fileprivate extension String {
	var nilIfEmpty: String? {
		isEmpty ? nil : self
	}
}
