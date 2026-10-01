import StoreKit
import XCTest

@testable import JustTrackSDK

/// Tests for default implementations on the `JustTrackSdk` protocol declared in `JustTrackSDK.swift`.
/// Each convenience overload forwards to a primary method on the protocol; we verify the forwarding
/// by recording the call arguments on a lightweight test double.
final class JustTrackSdkProtocolExtensionTests: XCTestCase {
	func testTrackEventNameForwardsToTrackEventWithMatchingName() {
		let sdk = RecordingJustTrackSdk()

		_ = sdk.track(eventName: "level_up")

		guard let event = sdk.trackedEvents.first, sdk.trackedEvents.count == 1 else {
			XCTFail("Expected exactly one tracked event")
			return
		}
		XCTAssertEqual(event.name, "level_up")
	}

	func testTrackEventNameWithDimensionsForwardsWithSameDimensions() {
		let sdk = RecordingJustTrackSdk()
		let dimensions: Dimensions = ["source": "ad"]

		_ = sdk.track(eventName: "purchase", dimensions: dimensions)

		guard let event = sdk.trackedEvents.first else {
			XCTFail("Expected a tracked event")
			return
		}
		XCTAssertEqual(event.name, "purchase")
		XCTAssertEqual(event.dimensions["source"], "ad")
	}

	func testSetExperimentVariantTwoArgForwardsWithEmptyTagsAndNilHappenedAt() {
		let sdk = RecordingJustTrackSdk()

		_ = sdk.setExperimentVariant(experiment: "exp_a", variant: "control")

		guard let call = sdk.experimentCalls.first else {
			XCTFail("Expected a setExperimentVariant call")
			return
		}
		XCTAssertEqual(call.experiment, "exp_a")
		XCTAssertEqual(call.variant, "control")
		XCTAssertEqual(call.tags, [])
		XCTAssertNil(call.happenedAt)
	}

	func testSetExperimentVariantThreeArgForwardsWithProvidedTagsAndNilHappenedAt() {
		let sdk = RecordingJustTrackSdk()

		_ = sdk.setExperimentVariant(experiment: "exp_b", variant: "treatment", tags: ["t1", "t2"])

		guard let call = sdk.experimentCalls.first else {
			XCTFail("Expected a setExperimentVariant call")
			return
		}
		XCTAssertEqual(call.experiment, "exp_b")
		XCTAssertEqual(call.variant, "treatment")
		XCTAssertEqual(call.tags, ["t1", "t2"])
		XCTAssertNil(call.happenedAt)
	}
}

/// Records the calls forwarded by the protocol extension in `JustTrackSDK.swift`.
/// Only the methods exercised by the protocol-extension tests are implemented;
/// the rest are stubbed with `fatalError` to keep the test surface small.
private final class RecordingJustTrackSdk: JustTrackSdk {
	struct ExperimentCall {
		let experiment: String
		let variant: String
		let tags: [String]
		let happenedAt: Date?
	}

	var trackedEvents: [AppEvent] = []
	var experimentCalls: [ExperimentCall] = []

	var attribution: Future<AttributionResponse> { fatalError("Unused") }
	var retargetingParameters: Future<RetargetingParameters?> { fatalError("Unused") }
	var preliminaryRetargetingParameters: PreliminaryRetargetingParameters? { nil }
	var appVersionAtInstall: AppVersion { AppVersionImpl(code: "1", name: "1.0") }
	var sdkVersion: any Version { currentSdkVersion() }
	var remoteConfig: JusttrackRemoteConfig { fatalError("Unused") }

	func anonymize() -> Future<Void> { fatalError("Unused") }
	func isRunning() -> Bool { false }
	func register(attributionListener: @escaping (AttributionResponse) -> Void) -> Subscription { fatalError("Unused") }
	func register(retargetingParametersListener: @escaping (RetargetingParameters) -> Void) -> Subscription { fatalError("Unused") }
	func register(preliminaryRetargetingParametersListener: @escaping (PreliminaryRetargetingParameters) -> Void) -> Subscription { fatalError("Unused") }
	func shutdown() {}
	func set(userId: String) -> Future<Void> { fatalError("Unused") }
	func set(firebaseAppInstanceId: String) -> Future<Void> { fatalError("Unused") }
	func set(odmInfo: String) -> Future<Void> { fatalError("Unused") }
	func handle(deeplink url: URL) {}
	func set(automaticInAppPurchaseTracking: Bool) {}
	func start() {}
	func stop() {}
	func publish(event: AppEvent) -> Future<Void> { fatalError("Unused") }

	func track(event: AppEvent) -> Future<Void> {
		trackedEvents.append(event)
		return FutureImpl<Void>().resolve(())
	}

	func forward(adImpression: AdImpression) -> Future<Void> { fatalError("Unused") }
	func getInstallInstanceId() -> Future<String> { fatalError("Unused") }
	func getAdvertiserIdInfo() -> Future<AdvertiserIdInfo> { fatalError("Unused") }

	func setExperimentVariant(experiment: String, variant: String, tags: [String], happenedAt: Date?) -> Future<Void> {
		experimentCalls.append(ExperimentCall(experiment: experiment, variant: variant, tags: tags, happenedAt: happenedAt))
		return FutureImpl<Void>().resolve(())
	}

	@available(iOS 15.0, *)
	func forward(transaction: Transaction) -> Result<Void, Error> { fatalError("Unused") }

	@available(iOS 15.0, *)
	func forward(transactionId: String, productId: String, quantity: Int) -> Result<Void, Error> { fatalError("Unused") }

	func integrate(with adapter: JusttrackAdapter) -> Future<Void> { fatalError("Unused") }

	func set(globalDimension0 value: String?) {}

	func set(globalDimension1 value: String?) {}

	func set(globalDimension2 value: String?) {}
}
