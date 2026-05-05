import AppTrackingTransparency
import JustTrackSDK
import SwiftUI

struct InitView: View {
	private static var sdk: JustTrackSdk!

	@State private var isDisplayingAlert = false
	@State private var alert: (title: String, message: String?)? {
		didSet {
			isDisplayingAlert = alert != nil
		}
	}

	@State private var isLoading = false
	@State private var isManualStartEnabled = false
	@State private var userId: String = ""
	@State private var trackingId: String = ""
	@State private var customBundleId: String = ""
	@State private var customVersionName: String = ""
	@State private var customVersionCode: String = ""

	private let apiToken = LocalCredentials.apiToken
	private let onInitSdk: (InitResult) -> Void

	init(
		onInitSdk: @escaping (InitResult) -> Void
	) {
		self.onInitSdk = onInitSdk
	}

	var body: some View {
		ZStack {
			VStack {
				Spacer()
				VStack(alignment: .leading) {
					ListItemTitleView("User ID")
					TextField("User ID", text: $userId)
						.autocapitalization(.none)
						.fontForListItemText()

					ListItemTitleView("Tracking ID")
					TextField("Tracking ID", text: $trackingId)
						.autocapitalization(.none)
						.fontForListItemText()

					ListItemTitleView("Custom Bundle ID")
					TextField("e.g. com.example.app", text: $customBundleId)
						.autocapitalization(.none)
						.fontForListItemText()

					ListItemTitleView("Custom Version Name")
					TextField("e.g. 1.0.0", text: $customVersionName)
						.autocapitalization(.none)
						.fontForListItemText()

					ListItemTitleView("Custom Version Code")
					TextField("e.g. 1", text: $customVersionCode)
						.autocapitalization(.none)
						.fontForListItemText()
				}.padding(.all, 18)

				Toggle(isOn: $isManualStartEnabled) {
					Text("Manual Start")
						.font(.headline)
				}
				.fixedSize()
				.padding(.all, 18)
				DefaultButton("Run With No Tracking") {
					initSdk()
				}.padding(.bottom, 18)
				DefaultButton("Run With Tracking") {
					DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
						ATTrackingManager.requestTrackingAuthorization { _ in }
					}
					DispatchQueue.main.asyncAfter(deadline: .now() + 7, execute: initSdk)
				}.padding(.bottom, 18)
				DefaultButton("Run With (SDK) Tracking") {
					DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
						JustTrack.requestTrackingAuthorization { _ in }
					}
					DispatchQueue.main.asyncAfter(deadline: .now() + 7, execute: initSdk)
				}.padding(.bottom, 18)
				DefaultButton("Run With (Postponed) Tracking") {
					DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
						ATTrackingManager.requestTrackingAuthorization { _ in }
					}
					initSdk()
				}
				.padding(.bottom, 48)
			}
			Color.clear.overlay(
				Group {
					if isLoading {
						Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
						ProgressView()
							.progressViewStyle(CircularProgressViewStyle(tint: .white))
							.scaleEffect(2)
					}
				}
				.animation(.easeInOut, value: isLoading)
				.transition(.opacity)
			)
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
		.onTapGesture {
			UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
		}
	}

	private func initSdk() {
		isLoading = true

		if InitView.sdk == nil {
			let builder = JustTrackSdkBuilder(apiToken: apiToken)

			if !userId.isEmpty {
				try! _ = builder.set(userId: userId)  // swiftlint:disable:this force_try
			}

			if !trackingId.isEmpty {
				try! _ = builder.set(trackingId: trackingId, trackingProvider: "advertiserId")  // swiftlint:disable:this force_try
			}

			if !customBundleId.isEmpty {
				_ = builder.set(bundleId: customBundleId)
			}

			if !customVersionName.isEmpty && !customVersionCode.isEmpty {
				_ = builder.set(applicationVersion: customVersionName, versionCode: customVersionCode)
			}

			InitView.sdk =
				try! builder  // swiftlint:disable:this force_try
				.set(manualStart: isManualStartEnabled)
				.set(isLoggingEnabled: true)
				.set(serverUrl: LocalCredentials.sandbox)
				.build()
		}

		sdkBridge!.getUserId().observe(on: .main) { getUserIdResult in  // swiftlint:disable:this force_unwrapping
			switch getUserIdResult {
			case let .success(userId):
				onInitSdk(
					InitResult(
						sdk: InitView.sdk,
						sdkBridge: sdkBridge!,  // swiftlint:disable:this force_unwrapping
						userId: userId
					)
				)
			case .failure:
				onInitSdk(
					InitResult(
						sdk: InitView.sdk,
						sdkBridge: sdkBridge!,  // swiftlint:disable:this force_unwrapping
						userId: nil
					)
				)
			}
		}
	}
}

struct InitResult {
	let sdk: JustTrackSdk
	let sdkBridge: SdkBridge
	let userId: String?
}
