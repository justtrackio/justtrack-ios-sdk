import JustTrackSDK
import SwiftUI

struct TestGroupView: View {
	private let sdk: JustTrackSdk
	@State private var lastResult: String = ""
	@State private var lastError: String = ""

	private let testScenarios = [
		ExperimentVariantScenario(
			name: "Button Color Test",
			experiment: "button_color_test",
			variant: "red_button",
			tags: ["ui", "color"],
			description: "Testing red button variant with UI tags"
		),
		ExperimentVariantScenario(
			name: "Checkout Flow Test",
			experiment: "checkout_flow_test",
			variant: "control",
			tags: [],
			description: "Control variant for checkout flow"
		),
		ExperimentVariantScenario(
			name: "Premium Feature Test",
			experiment: "premium_features_test",
			variant: "variant_a",
			tags: ["premium", "features", "test_a"],
			description: "Testing premium features variant A with multiple tags"
		),
		ExperimentVariantScenario(
			name: "Custom Date Test",
			experiment: "retention_test",
			variant: "week_2",
			tags: ["retention"],
			description: "Testing with custom date (1 hour ago) and retention tag"
		),
	]

	init(sdk: JustTrackSdk) {
		self.sdk = sdk
	}

	var body: some View {
		ScrollView {
			VStack(spacing: 16) {
				Text("Experiment Variant Assignment")
					.font(.title2)
					.fontWeight(.bold)
					.padding(.top)

				Text("Test the setExperimentVariant functionality with predefined scenarios")
					.font(.subheadline)
					.foregroundColor(.secondary)
					.multilineTextAlignment(.center)
					.padding(.horizontal)

				LazyVStack(spacing: 12) {
					ForEach(Array(testScenarios.enumerated()), id: \.offset) { index, scenario in
						ExperimentVariantCard(
							scenario: scenario,
							onTest: {
								testScenario(scenario, index: index)
							}
						)
					}
				}
				.padding(.horizontal)

				if !lastResult.isEmpty || !lastError.isEmpty {
					VStack(alignment: .leading, spacing: 8) {
						Text("Last Result:")
							.font(.headline)

						if !lastResult.isEmpty {
							Text(lastResult)
								.font(.caption)
								.foregroundColor(.green)
								.padding(8)
								.background(Color.green.opacity(0.1))
								.cornerRadius(8)
						}

						if !lastError.isEmpty {
							Text(lastError)
								.font(.caption)
								.foregroundColor(.red)
								.padding(8)
								.background(Color.red.opacity(0.1))
								.cornerRadius(8)
						}
					}
					.padding()
				}

				Spacer(minLength: 32)
			}
		}
		.navigationBarTitle("Experiment Variants", displayMode: .inline)
	}

	private func testScenario(_ scenario: ExperimentVariantScenario, index: Int) {
		lastResult = ""
		lastError = ""

		let happenedAt = index == 3 ? Date().addingTimeInterval(-3600) : nil  // 1 hour ago for custom date test

		sdk.setExperimentVariant(
			experiment: scenario.experiment,
			variant: scenario.variant,
			tags: scenario.tags,
			happenedAt: happenedAt
		).observe { result in
			DispatchQueue.main.async {
				switch result {
				case .success:
					self.lastResult = "✅ Successfully assigned to variant '\(scenario.variant)' for experiment '\(scenario.experiment)'"
					self.lastError = ""
				case .failure(let error):
					self.lastError = "❌ Failed: \(error.localizedDescription)"
					self.lastResult = ""
				}
			}
		}
	}
}

struct ExperimentVariantScenario {
	let name: String
	let experiment: String
	let variant: String
	let tags: [String]
	let description: String
}

struct ExperimentVariantCard: View {
	let scenario: ExperimentVariantScenario
	let onTest: () -> Void

	var body: some View {
		HStack {
			VStack(alignment: .leading, spacing: 8) {
				VStack(alignment: .leading, spacing: 4) {
					Text(scenario.name)
						.font(.headline)
						.foregroundColor(.primary)

					Text(scenario.description)
						.font(.caption)
						.foregroundColor(.secondary)
				}

				Divider()

				VStack(alignment: .leading, spacing: 2) {
					HStack {
						Text("Experiment:")
							.font(.caption2)
							.foregroundColor(.secondary)
						Text(scenario.experiment)
							.font(.caption2)
					}

					HStack {
						Text("Variant:")
							.font(.caption2)
							.foregroundColor(.secondary)
						Text(scenario.variant)
							.font(.caption2)
					}

					HStack {
						Text("Tags:")
							.font(.caption2)
							.foregroundColor(.secondary)
						Text(scenario.tags.joined(separator: ", "))
							.font(.caption2)
							.foregroundColor(scenario.tags.isEmpty ? .gray : .blue)
					}
				}
			}

			Spacer()

			VStack {
				Spacer()
				DefaultButton("Test", action: onTest)
				Spacer()
			}
		}
		.padding()
		.background(Color(.systemBackground))
		.cornerRadius(12)
		.shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
	}
}
