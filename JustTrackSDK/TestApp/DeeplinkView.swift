import JustTrackSDK
import SwiftUI

struct DeeplinkView: View {
	private let sdk: JustTrackSdk

	@State private var urlString = "https://example.com/?gbraid=abc123"
	@Binding var receivedDeeplinks: [String]
	@State private var odmInfoString = "odm-info-from-google"
	@State private var odmInfoLog: [String] = []
	@State private var isDisplayingAlert = false
	@State private var alert: (title: String, message: String?)? {
		didSet {
			isDisplayingAlert = alert != nil
		}
	}

	init(sdk: JustTrackSdk, receivedDeeplinks: Binding<[String]>) {
		self.sdk = sdk
		_receivedDeeplinks = receivedDeeplinks
	}

	var body: some View {
		NavigationView {
			List {
				Section(header: SectionHeaderView("Deeplink")) {
					VStack(alignment: .leading) {
						ListItemTitleView("Deeplink URL")
						TextField("https://example.com/?gbraid=abc123", text: $urlString)
							.autocapitalization(.none)
							.disableAutocorrection(true)
							.keyboardType(.URL)
							.fontForListItemText()
					}

					DefaultButton("Handle Deeplink") {
						sendDeeplink()
					}
				}

				if !receivedDeeplinks.isEmpty {
					Section(header: SectionHeaderView("Handled Deeplinks")) {
						ForEach(receivedDeeplinks, id: \.self) { deeplink in
							ListItemTextView(deeplink)
						}
					}
				}

				Section(header: SectionHeaderView("ODM Info")) {
					VStack(alignment: .leading) {
						ListItemTitleView("ODM Info String")
						TextField(odmInfoString, text: $odmInfoString)
							.autocapitalization(.none)
							.disableAutocorrection(true)
							.fontForListItemText()
					}

					DefaultButton("Set ODM Info") {
						sendOdmInfo()
					}
				}

				if !odmInfoLog.isEmpty {
					Section(header: SectionHeaderView("ODM Info Log")) {
						ForEach(odmInfoLog, id: \.self) { entry in
							ListItemTextView(entry)
						}
					}
				}
			}
			.navigationBarTitle("Deeplink")
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

	private func sendDeeplink() {
		guard let url = URL(string: urlString) else {
			alert = ("Invalid URL", "Please enter a valid URL.")
			isDisplayingAlert = true
			return
		}

		receivedDeeplinks.insert(url.absoluteString, at: 0)
		sdk.handle(deeplink: url)
		alert = ("Deeplink handled", "\(url.absoluteString)")
		isDisplayingAlert = true
	}

	private func sendOdmInfo() {
		guard !odmInfoString.isEmpty else {
			alert = ("Empty ODM Info", "Please enter an ODM info string.")
			isDisplayingAlert = true
			return
		}

		let odmInfo = odmInfoString
		odmInfoLog.insert(odmInfo, at: 0)
		sdk.set(odmInfo: odmInfo).observe(on: .main) { result in
			switch result {
			case .success:
				alert = ("ODM Info Set", "Successfully set ODM info: \(odmInfo)")
				isDisplayingAlert = true
			case let .failure(error):
				alert = ("ODM Info Failed", "Failed to set ODM info: \(error.localizedDescription)")
				isDisplayingAlert = true
			}
		}
		odmInfoString = ""
	}
}
