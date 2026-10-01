import JustTrackSDK
import SwiftUI

struct InfoView: View {
	@ObservedObject private var info: Info

	@State private var copiedItemName = ""
	@State private var showingToast = false

	@State private var customUserId = ""
	@State private var firebaseAppInstanceId = ""
	@State private var isDisplayingAlert = false
	@State private var alert: (title: String, message: String?)? {
		didSet {
			isDisplayingAlert = alert != nil
		}
	}

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

					Section(header: SectionHeaderView("User IDs")) {
						idRow(
							title: "Custom User ID",
							placeholder: "my-user-id",
							text: $customUserId,
							action: setCustomUserId
						)

						idRow(
							title: "Firebase App Instance ID",
							placeholder: "firebase-app-instance-id",
							text: $firebaseAppInstanceId,
							action: setFirebaseAppInstanceId
						)
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
		.alert(isPresented: $isDisplayingAlert) {
			Alert(
				title: Text(alert?.title ?? ""),
				message: Text(alert?.message ?? ""),
				dismissButton: .default(Text("OK")) {
					alert = nil
				}
			)
		}
	}

	private func idRow(
		title: String,
		placeholder: String,
		text: Binding<String>,
		action: @escaping () -> Void
	) -> some View {
		HStack(spacing: 12) {
			VStack(alignment: .leading) {
				ListItemTitleView(title)
				TextField(placeholder, text: text)
					.autocapitalization(.none)
					.disableAutocorrection(true)
					.fontForListItemText()
			}

			CompactButton("Set", action: action)
				.disabled(text.wrappedValue.isEmpty)
		}
	}

	private func setCustomUserId() {
		let userId = customUserId
		guard !userId.isEmpty else { return }

		sdk.set(userId: userId).observe(on: .main) { result in
			switch result {
			case .success:
				alert = ("Custom User ID Set", "Successfully set custom user ID: \(userId)")
			case let .failure(error):
				alert = ("Custom User ID Failed", "Failed to set custom user ID: \(error.localizedDescription)")
			}
		}
	}

	private func setFirebaseAppInstanceId() {
		let appInstanceId = firebaseAppInstanceId
		guard !appInstanceId.isEmpty else { return }

		sdk.set(firebaseAppInstanceId: appInstanceId).observe(on: .main) { result in
			switch result {
			case .success:
				alert = ("Firebase App Instance ID Set", "Successfully set Firebase app instance ID: \(appInstanceId)")
			case let .failure(error):
				alert = ("Firebase App Instance ID Failed", "Failed to set Firebase app instance ID: \(error.localizedDescription)")
			}
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
