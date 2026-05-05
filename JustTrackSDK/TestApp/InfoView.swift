import JustTrackSDK
import SwiftUI

struct InfoView: View {
	@ObservedObject private var info: Info

	@State private var copiedItemName = ""
	@State private var showingToast = false

	private let sdk: JustTrackSdk

	init(initResult: InitResult) {
		sdk = initResult.sdk
		info = Info(
			sdkVersionItem: sdk.sdkVersion.name,
			installIdItem: "Not available",
			advertiserIdItem: "Not available"
		)
	}

	var body: some View {
		NavigationView {
			ZStack {
				List {
					Section(header: SectionHeaderView("General")) {
						VStack(alignment: .leading) {
							ListItemTitleView("SDK Version")
							ListItemTextView(info.sdkVersionItem)
						}
						.onTapGesture {
							UIPasteboard.general.string = info.sdkVersionItem
							copiedItemName = "SDK Version"
							showingToast = true
						}

						VStack(alignment: .leading) {
							ListItemTitleView("Install ID")
							ListItemTextView(info.installIdItem)
						}
						.onTapGesture {
							UIPasteboard.general.string = info.installIdItem
							copiedItemName = "Install ID"
							showingToast = true
						}

						VStack(alignment: .leading) {
							ListItemTitleView("Advertiser ID")
							ListItemTextView(info.advertiserIdItem)
						}
						.onTapGesture {
							UIPasteboard.general.string = info.advertiserIdItem
							copiedItemName = "Advertiser ID"
							showingToast = true
						}
					}
				}

				if showingToast {
					VStack {
						Spacer()
						ToastView(text: "`\(copiedItemName)` copied to clipboard").padding()
						Spacer().frame(height: 41)
					}
					.transition(.move(edge: .bottom))
					.zIndex(1)
					.onAppear {
						DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
							self.showingToast = false
						}
					}
				}
			}
			.navigationTitle("Info")
			.onAppear { fetchUserData() }
		}
	}

	private func fetchUserData() {
		Task(priority: .userInitiated) {
			do {
				self.info.installIdItem = try await sdk.getInstallInstanceId().async()
				self.info.advertiserIdItem = try await sdk.getAdvertiserIdInfo().async().advertiserId ?? "Not available"
			} catch {
				print("Attribution failed: \(error)")
			}
		}
	}
}
