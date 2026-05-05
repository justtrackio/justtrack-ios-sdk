import JustTrackSDK
import JustTrackSDKUnityAdsAdapter
import SwiftUI
import UnityAds

enum UnityAdsType {
    case banner
    case interstitial
    case rewarded
}

struct UnityAdsView: View {
    @StateObject var model: UnityAdsModel
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            VStack {
                Text("Banner Ad").font(.headline)
                HStack {
                    DefaultButton(
                        "Load Banner",
                        isEnabled: $model.isAdAvailable,
                        action: model.loadBannerAd
                    )
                    DefaultButton(
                        "Show Banner",
                        isEnabled: $model.isBannerReady,
                        action: model.showBannerAd
                    )
                }
            }
            
            Divider()

            VStack {
                Text("Interstitial Ad").font(.headline)
                HStack {
                    DefaultButton(
                        "Load Interstitial",
                        isEnabled: $model.isAdAvailable,
                        action: model.loadInterstitialAd
                    )
                    DefaultButton(
                        "Show Interstitial",
                        isEnabled: $model.isInterstitialReady,
                        action: model.showInterstitialAd
                    )
                }
            }
            
            Divider()

            VStack {
                Text("Rewarded Ad").font(.headline)
                HStack {
                    DefaultButton(
                        "Load Rewarded",
                        isEnabled: $model.isAdAvailable,
                        action: model.loadRewardedAd
                    )
                    DefaultButton(
                        "Show Rewarded",
                        isEnabled: $model.isRewardedReady,
                        action: model.showRewardedAd
                    )
                }
            }
        }
        .padding()
        .navigationTitle("UnityAds")
        .onAppear(perform: model.run)
        .alert(isPresented: $model.isDisplayingError) {
            Alert(title: Text("Error"), message: Text(model.errorMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    init(
    ) {
        _model = StateObject(
            wrappedValue: UnityAdsModel()
        )
    }
}

final class UnityAdsModel: NSObject, ObservableObject {
    @Published var isAdAvailable = true
    @Published var isBannerReady = false
    @Published var isInterstitialReady = false
    @Published var isRewardedReady = false
    
    @Published var isDisplayingError = false
    private(set) var errorMessage: String = "" {
        didSet {
            isDisplayingError = errorMessage != ""
        }
    }

    private let gameId = LocalCredentials.unityAdsGameId
    private let bannerPlacementId = "Banner_iOS"
    private let interstitialPlacementId = "Interstitial_iOS"
    private let rewardedPlacementId = "Rewarded_iOS"

    private var sdk: JustTrackSdk?
    private var bannerView: UADSBannerView?

	private var isRunning = false
    
    deinit {
        bannerView?.removeFromSuperview()
    }
    
    func run() {
		if isRunning { return }

		isRunning = true

		runUnityAds()
		runSdk()
    }
    
    func loadBannerAd() {
        if bannerView == nil {
            bannerView = UADSBannerView(placementId: bannerPlacementId, size: CGSize(width: rootVC.view.bounds.width, height: 56))
            bannerView?.delegate = self
        }

        bannerView?.load()
        print("Loading banner ad...")
    }
    
    func loadInterstitialAd() {
        UnityAds.load(interstitialPlacementId, loadDelegate: self)
        print("Loading interstitial ad...")
    }
    
    func loadRewardedAd() {
        UnityAds.load(rewardedPlacementId, loadDelegate: self)
        print("Loading rewarded ad...")
    }
    
    func showBannerAd() {
        guard let bannerView = bannerView else {
            display(errorMessage: "Banner not initialized")
            return
        }

        bannerView.frame = CGRect(
            x: 0,
            y: rootVC.view.bounds.height - rootVC.view.safeAreaInsets.bottom - bannerView.frame.height,
            width: rootVC.view.bounds.width,
            height: bannerView.frame.height
        )

        rootVC.view.addSubview(bannerView)
        
        print("Banner ad displayed")
    }
    
    func showInterstitialAd() {
        UnityAds.show(rootVC, placementId: interstitialPlacementId, showDelegate: self)
    }
    
    func showRewardedAd() {
        UnityAds.show(rootVC, placementId: rewardedPlacementId, showDelegate: self)
    }
    
    private func runSdk() {
        do {
            sdk = try JustTrackSdkBuilder(apiToken: LocalCredentials.apiToken).build()
			if let sdk {
				sdk.integrate(with: JusttrackUnityAdsAdapter()).observe { integrationResult in
					switch integrationResult {
					case let .failure(error):
						print("[IA] SDK failed to integrate UnityAds: \(error)")
					case .success:
						print("[IA] SDK successfully integrated UnityAds")
					}
				}
			} else {
				print("[IA] SDK initialization failed")
			}
        } catch {
            display(errorMessage: error.localizedDescription)
        }
    }
    
    private func runUnityAds() {
        UnityAds.initialize(gameId, testMode: true, initializationDelegate: self)
    }
    
    private func display(errorMessage: String) {
        DispatchQueue.main.async {
            guard !self.isDisplayingError else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.display(errorMessage: errorMessage)
                }
                return
            }
            self.errorMessage = errorMessage
        }
    }
}

// MARK: UnityAdsInitializationDelegate

extension UnityAdsModel: UnityAdsInitializationDelegate {
    func initializationComplete() {
        print("Unity Ads initialization complete")
        isAdAvailable = true
    }
    
    func initializationFailed(_ error: UnityAdsInitializationError, withMessage message: String) {
        display(errorMessage: "Unity Ads initialization failed: \(message)")
        isAdAvailable = false
    }
}

// MARK: UnityAdsLoadDelegate

extension UnityAdsModel: UnityAdsLoadDelegate {
    func unityAdsAdLoaded(_ placementId: String) {
        print("Unity Ads loaded for placement: \(placementId)")
        DispatchQueue.main.async {
            switch placementId {
            case self.interstitialPlacementId:
                self.isInterstitialReady = true
            case self.rewardedPlacementId:
                self.isRewardedReady = true
            default:
                break
            }
        }
    }
    
    func unityAdsAdFailed(toLoad placementId: String, withError error: UnityAdsLoadError, withMessage message: String) {
        display(errorMessage: "Failed to load ad for placement \(placementId): \(message)")
        DispatchQueue.main.async {
            switch placementId {
            case self.interstitialPlacementId:
                self.isInterstitialReady = false
            case self.rewardedPlacementId:
                self.isRewardedReady = false
            default:
                break
            }
        }
    }
}

// MARK: UnityAdsShowDelegate

extension UnityAdsModel: UnityAdsShowDelegate {
    func unityAdsShowComplete(_ placementId: String, withFinish state: UnityAdsShowCompletionState) {
        print("Unity Ads show completed for placement \(placementId) with state: \(state.rawValue)")
        DispatchQueue.main.async {
            switch placementId {
            case self.interstitialPlacementId:
                self.isInterstitialReady = false
            case self.rewardedPlacementId:
                self.isRewardedReady = false
            default:
                break
            }
        }
    }
    
    func unityAdsShowFailed(_ placementId: String, withError error: UnityAdsShowError, withMessage message: String) {
        display(errorMessage: "Failed to show ad for placement \(placementId): \(message)")
    }
    
    func unityAdsShowStart(_ placementId: String) {
        print("Unity Ads show started for placement: \(placementId)")
    }
    
    func unityAdsShowClick(_ placementId: String) {
        print("Unity Ads clicked for placement: \(placementId)")
    }
}

// MARK: UADSBannerViewDelegate

extension UnityAdsModel: UADSBannerViewDelegate {
    func bannerViewDidLoad(_ bannerView: UADSBannerView!) {
        print("Banner view loaded successfully")
        DispatchQueue.main.async {
            self.isBannerReady = true
        }
    }
    
    func bannerViewDidError(_ bannerView: UADSBannerView!, error: UADSBannerError!) {
        display(errorMessage: "Banner error: \(error.localizedDescription)")
        print("Banner error code: \(error.code)")
        DispatchQueue.main.async {
            self.isBannerReady = false
        }
    }
    
    func bannerViewDidClick(_ bannerView: UADSBannerView!) {
        print("Banner clicked")
    }
    
    func bannerViewDidLeaveApplication(_ bannerView: UADSBannerView!) {
        print("Banner left application")
    }
}
