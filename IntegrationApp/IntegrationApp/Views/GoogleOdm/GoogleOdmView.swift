import Firebase
import JustTrackSDK
import JustTrackSDKGoogleOdmAdapter
import SwiftUI

struct GoogleOdmView: View {
	@StateObject var model: GoogleOdmModel

	var body: some View {
		ScrollView {
			VStack(alignment: .center, spacing: 16) {
				Section {
					Text("Event Data Variant")
						.font(.headline)
					Text("Not available in EEA/UK/Switzerland")
						.font(.caption)
						.foregroundColor(.orange)

					Text(model.statusMessage)
						.font(.body)
						.foregroundColor(model.isSuccess ? .green : .gray)
						.multilineTextAlignment(.center)
						.padding(.vertical, 4)

					DefaultButton(
						"Integrate Google ODM (Event Data)",
						isEnabled: .constant(!model.isIntegrating),
						action: model.integrateGoogleOdm
					)
				}

				Divider().padding(.vertical, 8)

				Section {
					Text("First-Party Data Variant")
						.font(.headline)
					Text("Works in EEA - requires user email/phone")
						.font(.caption)
						.foregroundColor(.green)

					TextField("Email address", text: $model.emailAddress)
						.textFieldStyle(RoundedBorderTextFieldStyle())
						.autocapitalization(.none)
						.keyboardType(.emailAddress)
						.padding(.horizontal)

					TextField("Phone number (optional)", text: $model.phoneNumber)
						.textFieldStyle(RoundedBorderTextFieldStyle())
						.keyboardType(.phonePad)
						.padding(.horizontal)

					Text(model.firstPartyStatusMessage)
						.font(.body)
						.foregroundColor(model.isFirstPartySuccess ? .green : .gray)
						.multilineTextAlignment(.center)
						.padding(.vertical, 4)

					DefaultButton(
						"Initiate ODM with Email",
						isEnabled: .constant(!model.emailAddress.isEmpty),
						action: model.initiateOdmWithEmail
					)

					DefaultButton(
						"Initiate ODM with Phone",
						isEnabled: .constant(!model.phoneNumber.isEmpty),
						action: model.initiateOdmWithPhone
					)
				}

				Divider().padding(.vertical, 8)

				Section {
					Text("Manual Test")
						.font(.headline)

					DefaultButton(
						"Set ODM Info Manually",
						isEnabled: .constant(true),
						action: model.setOdmInfoManually
					)
				}

				Spacer()
			}
			.padding()
		}
		.navigationTitle("Google ODM")
		.onAppear(perform: model.run)
		.alert(isPresented: $model.isDisplayingError) {
			Alert(title: Text("Error"), message: Text(model.errorMessage), dismissButton: .default(Text("OK")))
		}
	}

	init() {
		_model = StateObject(
			wrappedValue: GoogleOdmModel()
		)
	}
}

final class GoogleOdmModel: ObservableObject {
	@Published var isDisplayingError = false
	@Published var statusMessage = "SDK not initialized"
	@Published var isSuccess = false
	@Published var isIntegrating = false

	@Published var emailAddress = ""
	@Published var phoneNumber = ""
	@Published var firstPartyStatusMessage = "Enter email or phone to initiate ODM"
	@Published var isFirstPartySuccess = false

	private(set) var errorMessage: String = "" {
		didSet {
			isDisplayingError = errorMessage != ""
		}
	}

	private var sdk: JustTrackSdk?
	private var isRunning = false

	func run() {
		if isRunning { return }

		isRunning = true
		runSdk()
	}

	func integrateGoogleOdm() {
		guard let sdk = sdk else {
			display(errorMessage: "SDK not initialized")
			return
		}

		isIntegrating = true
		statusMessage = "Integrating Google ODM..."

		sdk.integrate(with: JusttrackGoogleOdmAdapter()).observe { [weak self] result in
			DispatchQueue.main.async {
				self?.isIntegrating = false
				switch result {
				case let .failure(error):
					self?.statusMessage = "Integration failed: \(error.localizedDescription)"
					self?.isSuccess = false
					print("[IA] Google ODM integration failed: \(error)")
				case .success:
					self?.statusMessage = "Google ODM integrated successfully!"
					self?.isSuccess = true
					print("[IA] Google ODM integrated successfully")
				}
			}
		}
	}

	func initiateOdmWithEmail() {
		guard !emailAddress.isEmpty else {
			firstPartyStatusMessage = "Please enter an email address"
			return
		}

		firstPartyStatusMessage = "Step 1: Initiating ODM with email..."
		print("[IA] Initiating ODM with email: \(emailAddress)")

		Analytics.initiateOnDeviceConversionMeasurement(emailAddress: emailAddress)
		print("[IA] ODM initiated with email")

		firstPartyStatusMessage = "Step 2: Fetching ODM info..."
		fetchAndSendOdmInfo()
	}

	func initiateOdmWithPhone() {
		guard !phoneNumber.isEmpty else {
			firstPartyStatusMessage = "Please enter a phone number"
			return
		}

		firstPartyStatusMessage = "Step 1: Initiating ODM with phone..."
		print("[IA] Initiating ODM with phone: \(phoneNumber)")

		Analytics.initiateOnDeviceConversionMeasurement(phoneNumber: phoneNumber)
		print("[IA] ODM initiated with phone")

		firstPartyStatusMessage = "Step 2: Fetching ODM info..."
		fetchAndSendOdmInfo()
	}

	private func fetchAndSendOdmInfo() {
		guard let sdk = sdk else {
			firstPartyStatusMessage = "SDK not initialized"
			return
		}

		sdk.integrate(with: JusttrackGoogleOdmAdapter()).observe { [weak self] result in
			DispatchQueue.main.async {
				switch result {
				case let .failure(error):
					self?.firstPartyStatusMessage = "Failed to fetch ODM info:\n\(error.localizedDescription)"
					self?.isFirstPartySuccess = false
					print("[IA] Failed to fetch ODM info after first-party init: \(error)")
				case .success:
					self?.firstPartyStatusMessage = "Success! ODM info fetched and sent to justtrack."
					self?.isFirstPartySuccess = true
					print("[IA] ODM info fetched and sent after first-party init")
				}
			}
		}
	}

	func setOdmInfoManually() {
		guard let sdk = sdk else {
			display(errorMessage: "SDK not initialized")
			return
		}

		let testOdmInfo = "{\"test_odm_info\":\"manual_test_value\",\"timestamp\":\(Date().timeIntervalSince1970)}"

		statusMessage = "Setting ODM info manually..."

		sdk.set(odmInfo: testOdmInfo).observe { [weak self] result in
			DispatchQueue.main.async {
				switch result {
				case let .failure(error):
					self?.statusMessage = "Failed to set ODM info: \(error.localizedDescription)"
					self?.isSuccess = false
					print("[IA] Failed to set ODM info: \(error)")
				case .success:
					self?.statusMessage = "ODM info set successfully!\nRe-attribution triggered."
					self?.isSuccess = true
					print("[IA] ODM info set successfully")
				}
			}
		}
	}

	private func runSdk() {
		initializeFirebase()

		do {
			sdk = try JustTrackSdkBuilder(apiToken: LocalCredentials.apiToken)
				.set(serverUrl: LocalCredentials.sandboxServerUrl)
				.set(isLoggingEnabled: true)
				.build()
			statusMessage = "Ready to test Event Data variant"
			print("[IA] SDK initialized for Google ODM testing")
		} catch {
			display(errorMessage: error.localizedDescription)
		}
	}

	private func initializeFirebase() {
		if FirebaseApp.app() == nil {
			let options = FirebaseOptions(
				googleAppID: LocalCredentials.firebaseGoogleAppId,
				gcmSenderID: LocalCredentials.firebaseGcmSenderId
			)
			options.projectID = LocalCredentials.firebaseProjectId
			options.apiKey = LocalCredentials.firebaseApiKey

			FirebaseApp.configure(options: options)
			print("[IA] Firebase initialized for ODM")
		} else {
			print("[IA] Firebase already initialized")
		}
	}

	private func display(errorMessage: String) {
		guard !isDisplayingError else {
			DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
				self?.display(errorMessage: errorMessage)
			}
			return
		}
		self.errorMessage = errorMessage
	}
}
