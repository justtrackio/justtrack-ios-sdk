import Foundation
import StoreKit

@testable import JustTrackSDK

class MockJustTrackSdk: JustTrackSdk {
	var attribution: Future<AttributionResponse> {
		fatalError("Unused")
	}

	var retargetingParameters: Future<RetargetingParameters?> {
		fatalError("Unused")
	}

	var preliminaryRetargetingParameters: PreliminaryRetargetingParameters? {
		fatalError("Unused")
	}

	var appVersionAtInstall: AppVersion {
		fatalError("Unused")
	}

	var sdkVersion: any Version {
		fatalError("Unused")
	}

	var remoteConfig: JusttrackRemoteConfig {
		fatalError("Unused")
	}

	func anonymize() -> Future<Void> {
		fatalError("Unused")
	}

	func isRunning() -> Bool {
		fatalError("Unused")
	}

	func register(attributionListener: @escaping (AttributionResponse) -> Void) -> Subscription {
		fatalError("Unused")
	}

	func register(retargetingParametersListener: @escaping (RetargetingParameters) -> Void) -> Subscription {
		fatalError("Unused")
	}

	func register(preliminaryRetargetingParametersListener: @escaping (PreliminaryRetargetingParameters) -> Void) -> Subscription {
		fatalError("Unused")
	}

	func shutdown() {
		fatalError("Unused")
	}

	func set(userId: String) -> Future<Void> {
		fatalError("Unused")
	}

	func set(firebaseAppInstanceId: String) -> Future<Void> {
		fatalError("Unused")
	}

	func set(odmInfo: String) -> Future<Void> {
		fatalError("Unused")
	}

	func handle(deeplink url: URL) {
		fatalError("Unused")
	}

	func set(automaticInAppPurchaseTracking: Bool) {
		fatalError("Unused")
	}

	func start() {
		fatalError("Unused")
	}

	func stop() {
		fatalError("Unused")
	}

	func publish(event: AppEvent) -> Future<Void> {
		fatalError("Unused")
	}

	func track(event: AppEvent) -> Future<Void> {
		fatalError("Unused")
	}

	func forward(adImpression: AdImpression) -> Future<Void> {
		fatalError("Unused")
	}

	func getInstallInstanceId() -> Future<String> {
		fatalError("Unused")
	}

	func getAdvertiserIdInfo() -> Future<AdvertiserIdInfo> {
		fatalError("Unused")
	}

	func setExperimentVariant(experiment: String, variant: String, tags: [String], happenedAt: Date?) -> Future<Void> {
		fatalError("Unused")
	}

	@available(iOS 15.0, *)
	func forward(transaction: Transaction) -> Result<Void, Error> {
		fatalError("Unused")
	}

	@available(iOS 15.0, *)
	func forward(transactionId: String, productId: String, quantity: Int) -> Result<Void, Error> {
		fatalError("Unused")
	}

	func integrate(with adapter: JusttrackAdapter) -> Future<Void> {
		fatalError("Unused")
	}

	func set(globalDimension0 value: String?) {
		fatalError("Unused")
	}

	func set(globalDimension1 value: String?) {
		fatalError("Unused")
	}

	func set(globalDimension2 value: String?) {
		fatalError("Unused")
	}
}
