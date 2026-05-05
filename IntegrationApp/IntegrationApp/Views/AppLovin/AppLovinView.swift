import AppLovinSDK
import JustTrackSDK
import JustTrackSDKAppLovinAdapter
import SwiftUI

struct AppLovinView: View {
    @StateObject var model: AppLovinModel

    var body: some View {
        VStack(alignment: .center) {
            DefaultButton(
                "Interstitials",
                isEnabled: $model.providesInterstitials,
                action: model.displayInterstitials
            )
            DefaultButton(
                "App Open Ads",
                isEnabled: $model.providesAppOpenAds,
                action: model.displayAppOpenAds
            )
            DefaultButton(
                "Rewarded",
                isEnabled: $model.providesRewarded,
                action: model.displayRewarded
            )
            DefaultButton(
                "Banners",
                isEnabled: $model.providesBanners,
                action: model.displayBanners
            )
        }
        .navigationTitle("AppLovin")
        .onAppear(perform: model.run)
        .alert(isPresented: $model.isDisplayingError) {
            Alert(title: Text("Error"), message: Text(model.errorMessage), dismissButton: .default(Text("OK")))
        }
    }

    init(
		customUserId: String? = nil
    ) {
        _model = StateObject(
			wrappedValue: AppLovinModel(customUserId: customUserId)
        )
    }
}

final class AppLovinModel: NSObject, ObservableObject {
    @Published var providesInterstitials = false
    @Published var providesAppOpenAds = false
    @Published var providesRewarded = false
    @Published var providesBanners = true

    @Published var isDisplayingError = false
    private(set) var errorMessage: String = "" {
        didSet {
            isDisplayingError = errorMessage != ""
        }
    }

    private let interstitialAd = MAInterstitialAd(adUnitIdentifier: "YOUR_AD_UNIT_ID")
    private let appOpenAd = MAAppOpenAd(adUnitIdentifier: "YOUR_AD_UNIT_ID")
    private let rewardedAd = MARewardedAd.shared(withAdUnitIdentifier: "YOUR_AD_UNIT_ID")
    private let adView = MAAdView(adUnitIdentifier: "YOUR_AD_UNIT_ID")

	private let customUserId: String?

    private var sdk: JustTrackSdk?

	private var isRunning = false

    init(
		customUserId: String? = nil
    ) {
		self.customUserId = customUserId
    }

    deinit {
        adView.removeFromSuperview()
    }

    func run() {
		if isRunning { return }

		isRunning = true

        runAppLovin()
		runSdk()
    }

    func displayInterstitials() {
        interstitialAd.show()
    }

    func displayAppOpenAds() {
        appOpenAd.load()
        appOpenAd.show()
    }

    func displayRewarded() {
        rewardedAd.show()
    }

    func displayBanners() {
        let adViewHeight = 50.0
        adView.frame = CGRect(
            x: 0,
            y: rootVC.view.bounds.height - rootVC.view.safeAreaInsets.bottom - adViewHeight,
            width: rootVC.view.bounds.width,
            height: adViewHeight
        )
        rootVC.view.addSubview(adView)
        adView.delegate = self
        adView.revenueDelegate = self
        adView.loadAd()
    }

    private func runSdk() {
        do {
            sdk = try JustTrackSdkBuilder(apiToken: LocalCredentials.apiToken)
				.set(isLoggingEnabled: true)
				.set(serverUrl: LocalCredentials.sandboxServerUrl)
				.build()
			if let sdk {
				sdk.integrate(with: JusttrackAppLovinAdapter(customUserId: customUserId)).observe { integrationResult in
					switch integrationResult {
					case let .failure(error):
						print("[IA] SDK failed to integrate AppLovin: \(error)")
					case .success:
						print("[IA] SDK successfully integrated AppLovin")
					}
				}
			} else {
				print("[IA] SDK initialization failed")
			}
        } catch {
            display(errorMessage: error.localizedDescription)
        }
    }

    private func runAppLovin() {
        let initConfig = ALSdkInitializationConfiguration(sdkKey: LocalCredentials.appLovinSdkKey) { builder in
            builder.mediationProvider = ALMediationProviderMAX
            if let currentIDFV = UIDevice.current.identifierForVendor?.uuidString {
                builder.testDeviceAdvertisingIdentifiers = [currentIDFV]
            }
        }
        ALSdk.shared().initialize(with: initConfig) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.interstitialAd.delegate = self
                self.interstitialAd.revenueDelegate = self
                self.interstitialAd.load()
            }
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

extension AppLovinModel: MAAdViewAdDelegate, MAAdRevenueDelegate, MARewardedAdDelegate {
    func didExpand(_ ad: MAAd) {
    }

    func didCollapse(_ ad: MAAd) {
    }

    func didPayRevenue(for ad: MAAd) {
    }

    func didLoad(_ ad: MAAd) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            switch ad.format {
            case .interstitial:
                self.providesInterstitials = true
                self.appOpenAd.delegate = self
                self.appOpenAd.revenueDelegate = self
                self.appOpenAd.load()
            case .appOpen:
                self.providesAppOpenAds = true
                self.rewardedAd.delegate = self
                self.rewardedAd.revenueDelegate = self
                self.rewardedAd.load()
            case .rewarded:
                self.providesRewarded = true
            default:
                break
            }
        }
    }

    func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        display(errorMessage: "Failed to load the ad unit with identifier: \(adUnitIdentifier). Error: [\(error.code.rawValue)] \(error.message)")
    }

    func didDisplay(_ ad: MAAd) {
    }

    func didHide(_ ad: MAAd) {
    }

    func didClick(_ ad: MAAd) {
    }

    func didFail(toDisplay ad: MAAd, withError error: MAError) {
    }

    func didRewardUser(for ad: MAAd, with reward: MAReward) {
    }
}
