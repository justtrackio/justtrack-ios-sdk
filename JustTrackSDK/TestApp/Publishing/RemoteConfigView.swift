import JustTrackSDK
import SwiftUI

struct RemoteConfigView: View {
	private let sdk: JustTrackSdk

	@State private var assignments: [JusttrackExperimentAssignment] = []
	@State private var fetchIntervalText: String = ""
	@State private var statusMessage: String = ""
	@State private var isError: Bool = false
	@State private var isLoading: Bool = false

	init(sdk: JustTrackSdk) {
		self.sdk = sdk
	}

	var body: some View {
		ScrollView {
			VStack(spacing: 16) {
				Text("Remote Config")
					.font(.title2)
					.fontWeight(.bold)
					.padding(.top)

				VStack(alignment: .leading, spacing: 8) {
					Text("Fetch Interval")
						.font(.headline)

					HStack {
						TextField("Seconds", text: $fetchIntervalText)
							.textFieldStyle(RoundedBorderTextFieldStyle())
							.keyboardType(.numberPad)
							.frame(width: 100)

						DefaultButton("Set") {
							setFetchInterval()
						}
					}
				}
				.padding()
				.background(Color(.systemBackground))
				.cornerRadius(12)
				.shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)

				VStack(alignment: .leading, spacing: 12) {
					Text("Actions")
						.font(.headline)

					HStack(spacing: 12) {
						DefaultButton("Fetch") {
							Task { await fetchConfig() }
						}
						.disabled(isLoading)

						DefaultButton("Fetch & Activate") {
							Task { await fetchAndActivate() }
						}
						.disabled(isLoading)
					}
				}
				.padding()
				.background(Color(.systemBackground))
				.cornerRadius(12)
				.shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)

				if !statusMessage.isEmpty {
					VStack(alignment: .leading, spacing: 8) {
						Text("Status")
							.font(.headline)

						Text(statusMessage)
							.font(.caption)
							.foregroundColor(isError ? .red : .green)
							.padding(8)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(isError ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
							.cornerRadius(8)
					}
					.padding()
					.background(Color(.systemBackground))
					.cornerRadius(12)
					.shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
				}

				if !assignments.isEmpty {
					VStack(alignment: .leading, spacing: 12) {
						Text("Assignments (\(assignments.count))")
							.font(.headline)

						ForEach(assignments, id: \.experimentId) { assignment in
							AssignmentCard(assignment: assignment, isLoading: isLoading) {
								await activateExperiment(assignment)
							}
						}
					}
					.padding()
					.background(Color(.systemBackground))
					.cornerRadius(12)
					.shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
				}

				Spacer(minLength: 32)
			}
			.padding(.horizontal)
		}
		.navigationBarTitle("Remote Config", displayMode: .inline)
	}

	private func setFetchInterval() {
		guard let interval = TimeInterval(fetchIntervalText) else {
			showStatus("Invalid interval value", isError: true)
			return
		}
		sdk.remoteConfig.setConfig(JusttrackRemoteConfigSettings(minFetchIntervalInSec: interval))
		showStatus("Fetch interval set to \(Int(interval))s", isError: false)
		fetchIntervalText = ""
	}

	private func fetchConfig() async {
		isLoading = true
		do {
			try await sdk.remoteConfig.fetch()
			await MainActor.run {
				assignments = sdk.remoteConfig.allAssignments
				showStatus("Fetched \(assignments.count) assignment(s)", isError: false)
				isLoading = false
			}
		} catch {
			await MainActor.run {
				showStatus("Fetch failed: \(error.localizedDescription)", isError: true)
				isLoading = false
			}
		}
	}

	private func fetchAndActivate() async {
		isLoading = true
		do {
			try await sdk.remoteConfig.fetchAndActivate()
			await MainActor.run {
				assignments = sdk.remoteConfig.allAssignments
				showStatus("Fetched and activated successfully", isError: false)
				isLoading = false
			}
		} catch {
			await MainActor.run {
				showStatus("Fetch and activate failed: \(error.localizedDescription)", isError: true)
				isLoading = false
			}
		}
	}

	private func activateExperiment(_ assignment: JusttrackExperimentAssignment) async {
		isLoading = true
		do {
			try await sdk.remoteConfig.activate([assignment])
			await MainActor.run {
				assignments = Array(assignments)
				showStatus("Activated experiment", isError: false)
				isLoading = false
			}
		} catch {
			await MainActor.run {
				showStatus("Activation failed: \(error.localizedDescription)", isError: true)
				isLoading = false
			}
		}
	}

	private func showStatus(_ message: String, isError: Bool) {
		self.statusMessage = message
		self.isError = isError
	}
}

struct AssignmentCard: View {
	let assignment: JusttrackExperimentAssignment
	let isLoading: Bool
	let onActivate: () async -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				Text("Some experiment")
					.font(.subheadline)
					.fontWeight(.semibold)

				Spacer()

				Text(assignment.isPending ? "Pending" : "Active")
					.font(.caption2)
					.padding(.horizontal, 8)
					.padding(.vertical, 4)
					.background(assignment.isPending ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
					.foregroundColor(assignment.isPending ? .orange : .green)
					.cornerRadius(4)
			}

			VStack(alignment: .leading, spacing: 4) {
				HStack {
					Text("ID:")
						.font(.caption2)
						.foregroundColor(.secondary)
					Text(assignment.experimentId)
						.font(.caption2)
						.lineLimit(1)
				}

				HStack {
					Text("Variant:")
						.font(.caption2)
						.foregroundColor(.secondary)
					Text("Some variant")
						.font(.caption2)
				}

				HStack {
					Text("Config:")
						.font(.caption2)
						.foregroundColor(.secondary)
					Text("\(assignment.configKey) = \(assignment.stringValue)")
						.font(.caption2)
				}
			}

			if assignment.isPending {
				DefaultButton("Activate") {
					Task { await onActivate() }
				}
				.disabled(isLoading)
			}
		}
		.padding()
		.background(Color(.secondarySystemBackground))
		.cornerRadius(8)
	}
}
