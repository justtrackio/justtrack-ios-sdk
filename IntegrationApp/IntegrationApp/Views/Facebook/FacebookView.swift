import AppTrackingTransparency
import FBSDKCoreKit
import JustTrackSDK
import JustTrackSDKFacebookAdapter
import SwiftUI

struct FacebookView: View {
    @StateObject var model: FacebookModel

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            DefaultButton(
                "Start",
                isEnabled: .constant(!model.isRunning),
                action: model.run
            )

            DefaultButton(
                "Start (Postponed ATT)",
                isEnabled: .constant(!model.isRunning),
                action: model.runPostponedATT
            )

            if model.showATTButton {
                DefaultButton(
                    "Request ATT",
                    isEnabled: .constant(true),
                    action: model.requestATT
                )
            }

            DefaultButton(
                "Test Swizzling",
                isEnabled: .constant(!model.isRunning),
                action: model.testSwizzling
            )

            if !model.statusMessage.isEmpty {
                Text(model.statusMessage)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }

            ForEach(Array(model.swizzlingLog.enumerated()), id: \.offset) { _, entry in
                Text(entry)
                    .font(.system(.caption, design: .monospaced))
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .navigationTitle("Facebook")
        .alert(isPresented: $model.isDisplayingError) {
            Alert(title: Text("Error"), message: Text(model.errorMessage), dismissButton: .default(Text("OK")))
        }
    }

    init() {
        _model = StateObject(wrappedValue: FacebookModel())
    }
}

final class FacebookModel: ObservableObject {
    @Published var isDisplayingError = false
    @Published var statusMessage: String = ""
    @Published var swizzlingLog: [String] = []
    @Published var isRunning = false

    private(set) var errorMessage: String = "" {
        didSet {
            isDisplayingError = errorMessage != ""
        }
    }

    @Published var showATTButton: Bool = false

    private var sdk: JustTrackSdk?
    private var adapterNotificationObserver: NSObjectProtocol?

    func run() {
        if isRunning { return }
        isRunning = true

        statusMessage = "Requesting ATT authorization..."

        ATTrackingManager.requestTrackingAuthorization { [weak self] status in
            DispatchQueue.main.async {
                print("[IA] ATT status: \(status.rawValue)")
                self?.statusMessage = "Initializing..."
                self?.initializeFacebookSdk()
                self?.initializeJustTrackSdk()
            }
        }
    }

    func runPostponedATT() {
        if isRunning { return }
        isRunning = true

        statusMessage = "Initializing (waiting for ATT authorization)..."
        showATTButton = true

        initializeFacebookSdk()
        initializeJustTrackSdk()
    }

    func requestATT() {
        statusMessage = "Requesting ATT authorization..."

        ATTrackingManager.requestTrackingAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("[IA] ATT authorized - fetching deferred app link")
                    self?.statusMessage = "ATT authorized - fetching deferred app link..."
                case .denied:
                    print("[IA] ATT denied")
                    self?.statusMessage = "ATT denied"
                case .restricted:
                    print("[IA] ATT restricted")
                    self?.statusMessage = "ATT restricted"
                case .notDetermined:
                    print("[IA] ATT still not determined")
                    self?.statusMessage = "ATT not determined"
                @unknown default:
                    print("[IA] ATT unknown status: \(status.rawValue)")
                    self?.statusMessage = "ATT unknown (\(status.rawValue))"
                }
                self?.showATTButton = false
            }
        }
    }

    /// 1. Request ATT (dialog appears)
    /// 2. While dialog is open: initialize SDK + integrate adapter
    /// 3. User accepts/denies → SDK swizzling fires (attribution) + adapter swizzling fires (deferred link)
    func testSwizzling() {
        if isRunning { return }
        isRunning = true
        swizzlingLog = []

        // Observe the adapter's swizzling notification
        adapterNotificationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("JustTrackFBAdapterATTStatusResolved"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let status = notification.userInfo?["status"] as? Int ?? -1
            let name = Self.attStatusName(status)
            self?.swizzlingLog.append("[Adapter swizzling] \(name)")
            print("[IA] Adapter swizzling notification: \(name)")
        }

        // Step 1: Request ATT – dialog appears
        statusMessage = "ATT dialog shown..."
        swizzlingLog.append("[Step 1] ATT requested")

        ATTrackingManager.requestTrackingAuthorization { [weak self] status in
            DispatchQueue.main.async {
                let name = Self.attStatusName(Int(status.rawValue))
                self?.swizzlingLog.append("[Completion handler] \(name)")
                print("[IA] ATT completion handler: \(name)")

                if let observer = self?.adapterNotificationObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self?.adapterNotificationObserver = nil
                }
            }
        }

        // Step 2: While dialog is open, initialize SDK + adapter
        DispatchQueue.main.async { [self] in
            swizzlingLog.append("[Step 2] SDK + adapter initializing")
            initializeFacebookSdk()
            initializeJustTrackSdk()
        }
    }

    private static func attStatusName(_ rawStatus: Int) -> String {
        switch rawStatus {
        case 0: return "notDetermined"
        case 1: return "restricted"
        case 2: return "denied"
        case 3: return "authorized"
        default: return "unknown(\(rawStatus))"
        }
    }

    private func initializeFacebookSdk() {
        if Settings.shared.appID == nil || Settings.shared.appID?.isEmpty == true {
            Settings.shared.appID = LocalCredentials.facebookAppId
        }
        if Settings.shared.clientToken == nil || Settings.shared.clientToken?.isEmpty == true {
            Settings.shared.clientToken = LocalCredentials.facebookClientToken
        }

        ApplicationDelegate.shared.application(
            UIApplication.shared,
            didFinishLaunchingWithOptions: nil
        )

        Settings.shared.isAdvertiserTrackingEnabled = true

        print("[FB] Facebook SDK initialized")
        print("[FB] App ID: \(Settings.shared.appID ?? "not set")")
        print("[FB] Client Token: \(Settings.shared.clientToken ?? "not set")")
    }

    private func initializeJustTrackSdk() {
        do {
            sdk = try JustTrackSdkBuilder(apiToken: LocalCredentials.apiToken)
                .set(isLoggingEnabled: true)
				.set(serverUrl: LocalCredentials.sandboxServerUrl)
				.build()
            if let sdk {
                print("[IA] JustTrack SDK initialized")

                sdk.integrate(with: JusttrackFacebookAdapter()).observe { [weak self] integrationResult in
                    DispatchQueue.main.async {
                        switch integrationResult {
                        case let .failure(error):
                            print("[IA] SDK failed to integrate Facebook: \(error)")
                            self?.statusMessage = "Integration failed: \(error.localizedDescription)"
                        case .success:
                            print("[IA] SDK successfully integrated Facebook")
                            self?.statusMessage = "Successfully integrated Facebook"
                        }
                    }
                }

                sdk.attribution.observe { result in
                    switch result {
                    case let .success(attribution):
                        print("[IA] Attribution received:")
                        print("  - Campaign: \(attribution.campaign.name ?? "unknown")")
                        print("  - Channel: \(attribution.channel.name ?? "unknown")")
						print("  - Partner: \(attribution.partner.name ?? "unknown")")
                    case let .failure(error):
                        print("[IA] Attribution error: \(error)")
                    }
                }
            }
        } catch {
            display(errorMessage: error.localizedDescription)
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
