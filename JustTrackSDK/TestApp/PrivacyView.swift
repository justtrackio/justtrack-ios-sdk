import AppTrackingTransparency
import JustTrackSDK
import SwiftUI

struct PrivacyView: View {
	private var sdk: JustTrackSdk

	@State var isRunning = false
	@State var isDisplayingAlert = false
	@State private var alert: (title: String, message: String?)? {
		didSet {
			isDisplayingAlert = alert != nil
		}
	}

	init(
		sdk: JustTrackSdk
	) {
		self.sdk = sdk
	}

	var body: some View {
		NavigationView {
			VStack {
				VStack(alignment: .center) {
					if isRunning {
						DefaultButton("Stop SDK", action: stopSDK)
					} else {
						DefaultButton("Start SDK", action: startSDK)
					}
					DefaultButton("Anonymize user", action: anonymize)
				}
				.frame(maxWidth: .infinity)
				.padding()
			}
			.navigationBarTitle("Privacy")
		}.onAppear {
			isRunning = sdk.isRunning()
		}.alert(isPresented: $isDisplayingAlert) {
			Alert(
				title: Text(alert?.title ?? ""),
				message: Text(alert?.message ?? ""),
				dismissButton: .default(Text("OK")) {
					alert = nil
				}
			)
		}
	}

	private func startSDK() {
		sdk.start()
		isRunning = sdk.isRunning()
	}

	private func stopSDK() {
		sdk.stop()
		isRunning = sdk.isRunning()
	}

	private func anonymize() {
		Task(priority: .userInitiated) {
			do {
				try await sdk.anonymize().async()

				await MainActor.run {
					isDisplayingAlert = true
					alert = ("Anonymize user", "Anonymized successfully!")
				}
			} catch {
				await MainActor.run {
					isDisplayingAlert = true
					alert = ("Anonymize user", "Failed to anonymize: \(error.localizedDescription)")
				}
			}
		}
	}
}
