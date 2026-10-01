import IronSource
import JustTrackSDK
import JustTrackSDKIronSourceAdapter
import SwiftUI

struct IronSourceView: View {
    @StateObject var model: IronSourceModel

    var body: some View {
        VStack(alignment: .center) {
            DefaultButton(
                "Launch Test Suite",
                isEnabled: $model.isInitialized,
                action: model.launchTestSuite
            )
        }
        .navigationTitle("ironSource")
        .onAppear(perform: model.run)
    }

	init() {
        _model = StateObject(wrappedValue: IronSourceModel())
    }
}

final class IronSourceModel: NSObject, ObservableObject {
    @Published var isInitialized = false

    private var sdk: JustTrackSdk?

	private var isRunning = false

	override init() {
        super.init()
    }

    func run() {
		if isRunning { return }

		isRunning = true

		runIronSource()
        runSdk()
    }

    func launchTestSuite() {
        LevelPlay.launchTestSuite(rootVC)
    }

    private func runSdk() {
        do {
            sdk = try JustTrackSdkBuilder(apiToken: LocalCredentials.apiToken)
                .set(isLoggingEnabled: true)
                .set(serverUrl: LocalCredentials.sandboxServerUrl)
                .build()
			if let sdk {
				sdk.integrate(with: JusttrackIronSourceAdapter()).observe { integrationResult in
					switch integrationResult {
					case let .failure(error):
						print("[IA] SDK failed to integrate IronSource: \(error)")
					case .success:
						print("[IA] SDK successfully integrated IronSource")
					}
				}
			} else {
				print("[IA] SDK initialization failed")
			}
        } catch {
            print("[IA] SDK initialization failed: \(error)")
        }
    }

    private func runIronSource() {
        LevelPlay.setMetaDataWithKey("is_test_suite", value: "enable")

        let requestBuilder = LPMInitRequestBuilder(appKey: LocalCredentials.ironSourceAppKey)
        let initRequest = requestBuilder.build()

        LevelPlay.initWith(initRequest) { [weak self] config, error in
            if let error {
                print("IronSource initialization failed: \(error)")
                return
            }

            print("IronSource initialization succeeded")
            DispatchQueue.main.async {
                self?.isInitialized = true
            }
        }
    }
}
