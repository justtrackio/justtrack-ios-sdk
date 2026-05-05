import JustTrackSDK
import SwiftUI

struct SpamView: View {
	@State private var enventsNumberString = ""
	@State private var messagesNumberString = ""
	@State private var metricsNumberString = ""
	@State private var isConcurrent = false

	@State private var isDisplayingAlert = false
	@State private var alert: (title: String, message: String?)? {
		didSet {
			isDisplayingAlert = alert != nil
		}
	}

	@State private var isSending = false

	private var sdk: JustTrackSdk
	private let bridge: SdkBridge

	init(
		sdk: JustTrackSdk,
		bridge: SdkBridge
	) {
		self.sdk = sdk
		self.bridge = bridge
	}

	var body: some View {
		VStack {
			List {
				VStack(alignment: .leading) {
					ListItemTitleView("Number of events")

					TextField("500", text: $enventsNumberString)
						.keyboardType(.numberPad)
						.fontForListItemText()
				}

				#if DEBUG
					VStack(alignment: .leading) {
						ListItemTitleView("Number of log messages")

						TextField("500", text: $messagesNumberString)
							.keyboardType(.numberPad)
							.fontForListItemText()
					}

					VStack(alignment: .leading) {
						ListItemTitleView("Number of log metrics")

						TextField("500", text: $metricsNumberString)
							.keyboardType(.numberPad)
							.fontForListItemText()
					}
				#endif

				Toggle(isOn: $isConcurrent) {
					Text("Concurrently")
						.font(.system(size: 12, weight: .bold, design: .monospaced))
						.foregroundStyle(.gray)
				}
			}
		}
		.navigationTitle("Spam")
		.navigationBarItems(
			trailing: Button(action: publish) {
				Text("Send").fontWeight(.bold)
			}
		)
		.overlay(
			Group {
				if isSending {
					Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
					ProgressView()
						.progressViewStyle(CircularProgressViewStyle(tint: .white))
						.scaleEffect(2)
				}
			}
			.animation(.easeInOut, value: isSending)
			.transition(.opacity)
		)
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

	private func publish() {
		isSending = true

		DispatchQueue.global(qos: .userInteractive).async {
			let dispatchGroup = isConcurrent ? DispatchGroup() : nil
			let enventsNumber = Int(enventsNumberString) ?? 500
			for number in lastEventNumber..<(lastEventNumber + enventsNumber) {
				lastEventNumber = number
				let eventName = "spam_event_\(number)"
				if isConcurrent {
					dispatchGroup?.enter()
					DispatchQueue(label: "event_queue_\(number)").async {
						sdk.track(eventName: eventName)
						dispatchGroup?.leave()
					}
				} else {
					sdk.track(eventName: eventName)
				}
			}

			let messagesNumber = Int(messagesNumberString) ?? 500
			for number in lastMessageNumber..<(lastMessageNumber + messagesNumber) {
				lastMessageNumber = number
				bridge.sendLogMessage(level: "warn", message: "spam_message_\(number)", fields: [:])
			}
			let metricsNumber = Int(metricsNumberString) ?? 500
			for number in lastMetricNumber..<(lastMetricNumber + metricsNumber) {
				lastMetricNumber = number
				bridge.sendLogMetric(metric: "spam_metric_\(number)", value: Double(number), unit: "count", dimensions: [:])
			}

			if let dispatchGroup {
				dispatchGroup.notify(queue: .main) {
					completeSending(enventsNumber: enventsNumber, messagesNumber: messagesNumber, metricsNumber: metricsNumber)
				}
			} else {
				completeSending(enventsNumber: enventsNumber, messagesNumber: messagesNumber, metricsNumber: metricsNumber)
			}
		}
	}

	private func completeSending(enventsNumber: Int, messagesNumber: Int, metricsNumber: Int) {
		isSending = false
		alert = ("Success", "\(enventsNumber) events, \(messagesNumber) messages, and \(metricsNumber) metrics have been sent.")
	}
}

private var lastEventNumber = 0
private var lastMessageNumber = 0
private var lastMetricNumber = 0
