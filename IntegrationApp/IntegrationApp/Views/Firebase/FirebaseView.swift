import Firebase
import JustTrackSDK
import JustTrackSDKFirebaseAdapter
import SwiftUI

struct FirebaseView: View {
    @StateObject var model: FirebaseModel

    var body: some View {
        VStack(alignment: .center) {
            DefaultButton(
                "Log Custom Event",
                isEnabled: .constant(true),
                action: model.logCustomEvent
            )
            DefaultButton(
                "Log Purchase Event",
                isEnabled: .constant(true),
                action: model.logPurchaseEvent
            )
            DefaultButton(
                "Log Level Up Event",
                isEnabled: .constant(true),
                action: model.logLevelUpEvent
            )
            DefaultButton(
                "Log Achievement Event",
                isEnabled: .constant(true),
                action: model.logAchievementEvent
            )
        }
        .navigationTitle("Firebase")
        .onAppear(perform: model.run)
        .alert(isPresented: $model.isDisplayingError) {
            Alert(title: Text("Error"), message: Text(model.errorMessage), dismissButton: .default(Text("OK")))
        }
    }

    init() {
        _model = StateObject(
            wrappedValue: FirebaseModel()
        )
    }
}

final class FirebaseModel: ObservableObject {
    @Published var isDisplayingError = false

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

		runFirebase()
        runSdk()
    }

    func logCustomEvent() {
        Analytics.logEvent("custom_event", parameters: [
            "parameter": "value"
        ])
        print("Logged custom event to Firebase")
    }
    
    func logPurchaseEvent() {
        Analytics.logEvent(AnalyticsEventPurchase, parameters: [
            AnalyticsParameterCurrency: "USD",
            AnalyticsParameterValue: 9.99,
            AnalyticsParameterItems: [
                [AnalyticsParameterItemName: "Premium Subscription"]
            ]
        ])
        print("Logged purchase event to Firebase")
    }
    
    func logLevelUpEvent() {
        Analytics.logEvent(AnalyticsEventLevelUp, parameters: [
            AnalyticsParameterLevel: 5,
            "character": "wizard"
        ])
        print("Logged level up event to Firebase")
    }
    
    func logAchievementEvent() {
        Analytics.logEvent(AnalyticsEventUnlockAchievement, parameters: [
            AnalyticsParameterAchievementID: "achievement_master"
        ])
        print("Logged achievement event to Firebase")
    }
    
    private func runSdk() {
        do {
            sdk = try JustTrackSdkBuilder(apiToken: LocalCredentials.apiToken)
				.set(serverUrl: LocalCredentials.sandboxServerUrl)
				.set(isLoggingEnabled: true)
				.build()
			if let sdk {
				sdk.integrate(with: JusttrackFirebaseAdapter()).observe { integrationResult in
					switch integrationResult {
					case let .failure(error):
						print("[IA] SDK failed to integrate Firebase: \(error)")
					case .success:
						print("[IA] SDK successfully integrated Firebase")
					}
				}
			} else {
				print("[IA] SDK initialization failed")
			}
        } catch {
            display(errorMessage: error.localizedDescription)
        }
    }
    
    private func runFirebase() {
        if FirebaseApp.app() == nil {
            let options = FirebaseOptions(
                googleAppID: LocalCredentials.firebaseGoogleAppId,
                gcmSenderID: LocalCredentials.firebaseGcmSenderId
            )
            options.projectID = LocalCredentials.firebaseProjectId
            options.apiKey = LocalCredentials.firebaseApiKey

            FirebaseApp.configure(options: options)
            print("Firebase initialized with project ID: \(LocalCredentials.firebaseProjectId)")
        } else {
            print("Firebase already initialized")
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
