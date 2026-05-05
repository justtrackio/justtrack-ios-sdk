import JustTrackSDK
import SwiftUI

struct GameView: View {
	@State private var isDisplayingAlert = false
	@State private var alert: (title: String, message: String?)? {
		didSet {
			isDisplayingAlert = alert != nil
		}
	}

	@State private var gameId = UUID()

	@State private var level = 1

	@State private var numberOfPublishedEvents = 0
	@State private var shouldPublishEvents = false
	@State private var readyForPublishing = true

	private var sdk: JustTrackSdk

	init(
		sdk: JustTrackSdk
	) {
		self.sdk = sdk
	}

	var body: some View {
		ScrollView {
			VStack {
				HStack {
					VStack(alignment: .leading) {
						ListItemTitleView("Publish random events")
						ListItemTextView("\(numberOfPublishedEvents) events published")
					}

					Spacer()

					Toggle("", isOn: $shouldPublishEvents)
						.onChange(of: shouldPublishEvents) { _ in
							guard shouldPublishEvents && readyForPublishing else { return }
							readyForPublishing = false
							publishRandomEventIfNeeded(currentGameId: gameId)
						}
						.frame(width: 56, alignment: .trailing)
				}
				.padding()

				VStack(alignment: .center) {
					DefaultButton("Win Level", action: onWin)
					DefaultButton("Fail Level", action: onFail)
					DefaultButton("Restart Game", action: onRestart)
				}
				.frame(maxWidth: .infinity)
				.padding()
			}
		}
		.navigationTitle("Game")
		.onDisappear {
			shouldPublishEvents = false
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

	private func onWin() {
		sdk.track(event: JtProgressionEvent(jtAction: "complete", jtProgression1: "level_\(level)")).observe { result in
			switch result {
			case .success:
				level += 1
				sdk.track(event: JtProgressionEvent(jtAction: "start", jtProgression1: "level_\(level)")).observe { result in
					_ = sdk.forward(
						adImpression: AdImpression(unit: "custom_impression_unit", sdkName: "custom_sdk_name")
							.set(placement: "custom_placement")
							.set(testGroup: "custom_test_group")
							.set(segmentName: "custom_segment_name")
							.set(instanceName: "custom_instance_name")
							.set(network: "custom_network")
							.set(bundleId: "custom_bundle_id")
							.set(revenue: Money(value: 41, currency: "USD"))
					)

					switch result {
					case .success:
						alert = ("Success", "The level \(level - 1) has been passed, the level \(level) has begun.")
					case let .failure(error):
						alert = ("Failure", error.justTrackGetErrorDescription())
					}
				}
			case let .failure(error):
				alert = ("Failure", error.justTrackGetErrorDescription())
			}
		}
	}

	private func onFail() {
		sdk.track(event: JtProgressionEvent(jtAction: "fail", jtProgression1: "level_\(level)")).observe { result in
			switch result {
			case .success:
				sdk.track(event: JtProgressionEvent(jtAction: "start", jtProgression1: "level_\(level)")).observe { result in
					switch result {
					case .success:
						alert = ("Success", "The level \(level) has been failed and started again.")
					case let .failure(error):
						alert = ("Failure", error.justTrackGetErrorDescription())
					}
				}
			case let .failure(error):
				alert = ("Failure", error.justTrackGetErrorDescription())
			}
		}
	}

	private func onRestart() {
		gameId = UUID()
		level = 1
		shouldPublishEvents = false
		numberOfPublishedEvents = 0
		readyForPublishing = true

		sdk.track(event: JtProgressionEvent(jtAction: "start", jtProgression1: "level_\(level)")).observe { result in
			switch result {
			case .success:
				alert = ("Success", "The first level of a new game has been started.")
			case let .failure(error):
				alert = ("Failure", error.justTrackGetErrorDescription())
			}
		}
	}

	private func publishRandomEventIfNeeded(currentGameId: UUID) {
		guard shouldPublishEvents else {
			readyForPublishing = true
			return
		}

		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			let nextEventNumber = numberOfPublishedEvents + 1
			sdk.track(event: AppEvent("random_game_event_\(nextEventNumber)").add(dimension: "level", value: "\(level)")).observe { result in
				guard currentGameId == gameId else { return }
				switch result {
				case .success:
					numberOfPublishedEvents = nextEventNumber
				case .failure:
					break
				}
				publishRandomEventIfNeeded(currentGameId: currentGameId)
			}
		}
	}
}
