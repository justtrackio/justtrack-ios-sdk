import IronSource
import JustTrackSDK
import JustTrackSDKIronSourceAdapter
import SwiftUI

struct IronSourceView: View {
    @StateObject var model: IronSourceModel

    var body: some View {
        VStack(alignment: .center) {
            DefaultButton(
                "Video",
                isEnabled: $model.providesVideo,
                action: model.displayVideo
            )
            DefaultButton(
                "Interstitial",
                isEnabled: $model.providesInterstitial,
                action: model.displayInterstitial
            )
            DefaultButton(
                "Banner",
                isEnabled: $model.providesBanner,
                action: model.displayBanner
            )
        }
        .navigationTitle("ironSource")
        .onAppear(perform: model.run)
    }

	init(
		customUserId: String? = nil
	) {
        _model = StateObject(wrappedValue: IronSourceModel(customUserId: customUserId))
    }
}

final class IronSourceModel: NSObject, ObservableObject {
    @Published var providesVideo = false
    @Published var providesInterstitial = false
    @Published var providesBanner = true

    private var customUserId: String?

    private var sdk: JustTrackSdk?

	private var isRunning = false

	init(
		customUserId: String? = nil
	) {
        self.customUserId = customUserId
    }

    func run() {
		if isRunning { return }

		isRunning = true

		runIronSource()
        runSdk()
    }

    func displayVideo() {
        IronSource.showRewardedVideo(with: rootVC)
    }
    
    func displayInterstitial() {
        IronSource.showInterstitial(with: rootVC)
    }

    func displayBanner() {
        IronSource.loadBanner(with: rootVC, size: ISBannerSize(width: Int(rootVC.view.bounds.width), andHeight: Int(rootVC.view.bounds.height)))
    }

    private func runSdk() {
        do {
            sdk = try JustTrackSdkBuilder(apiToken: LocalCredentials.apiToken).build()
			if let sdk {
				sdk.integrate(with: JusttrackIronSourceAdapter(customUserId: customUserId)).observe { integrationResult in
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
        IronSource.setLevelPlayRewardedVideoDelegate(self)
        IronSource.setLevelPlayInterstitialDelegate(self)
        IronSource.setLevelPlayBannerDelegate(self)

        IronSource.initWithAppKey(LocalCredentials.ironSourceAppKey, delegate: self)
    }
}

extension IronSourceModel: ISInitializationDelegate {
    func initializationDidComplete() {
        IronSource.loadRewardedVideo()
        IronSource.loadInterstitial()
    }
}

extension IronSourceModel: LevelPlayRewardedVideoDelegate {
    func hasAvailableAd(with adInfo: ISAdInfo) {
        providesVideo = true
    }
    
    func hasNoAvailableAd() {
        print(#function)
    }
    
    func didReceiveReward(forPlacement placementInfo: ISPlacementInfo, with adInfo: ISAdInfo) {
    }
    
    func didFailToShowWithError(_ error: (any Error), andAdInfo adInfo: ISAdInfo) {
    }
    
    func didOpen(with adInfo: ISAdInfo) {
    }
    
    func didClick(_ placementInfo: ISPlacementInfo, with adInfo: ISAdInfo) {
    }
    
    func didClose(with adInfo: ISAdInfo) {
    }
}

extension IronSourceModel: LevelPlayInterstitialDelegate {
    func didLoad(with adInfo: ISAdInfo) {
        providesInterstitial = true
    }
    
    func didFailToLoadWithError(_ error: (any Error)) {
        print(#function, error)
    }
    
    func didShow(with adInfo: ISAdInfo) {
    }
    
    func didClick(with adInfo: ISAdInfo) {
    }
}

extension IronSourceModel: LevelPlayBannerDelegate {
    func didLoad(_ bannerView: ISBannerView, with adInfo: ISAdInfo) {
        providesBanner = true
    }
    
    func didLeaveApplication(with adInfo: ISAdInfo) {
    }
    
    func didPresentScreen(with adInfo: ISAdInfo) {
    }
    
    func didDismissScreen(with adInfo: ISAdInfo) {
    }
}
