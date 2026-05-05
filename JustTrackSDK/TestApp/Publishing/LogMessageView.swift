import JustTrackSDK
import SwiftUI

struct LogMessageView: View {
	@ObservedObject private var message = LogMessage()

	@State private var selectedLevelIndex: Int = 0
	private let levels = LogMessage.Level.allCases.map(\.rawValue)

	@State private var isDisplayingAlert = false
	@State private var alert: (title: String, message: String?)? {
		didSet {
			isDisplayingAlert = alert != nil
		}
	}

	@State private var isSending = false

	private let bridge: SdkBridge

	init(
		message: LogMessage = LogMessage(),
		bridge: SdkBridge
	) {
		self.message = message
		self.bridge = bridge
	}

	var body: some View {
		VStack {
			List {
				VStack(alignment: .leading) {
					Spacer()

					ListItemTitleView("Level")

					Spacer()

					ForEach(0..<levels.count, id: \.self) { index in
						Text(levels[index])
							.fontForListItemText()
							.foregroundColor(selectedLevelIndex == index ? .black : .gray)
							.onTapGesture {
								selectedLevelIndex = index
								message.level = LogMessage.Level(rawValue: levels[index]) ?? .debug
							}
						Spacer()
					}
				}

				VStack(alignment: .leading) {
					ListItemTitleView("Message")

					TextField(
						"Message_1",
						text: $message.message
					)
					.fontForListItemText()
				}

				NavigationLink(
					"Fields",
					destination: FieldsView(
						fields: $message.fields,
						title: "Fields"
					)
				)
				.fontForListItemTitle()
			}
		}
		.navigationTitle("Log Message")
		.navigationBarItems(
			trailing: Button(action: publish) {
				Text("Send")
					.fontWeight(.bold)
			}
		)
		.alert(isPresented: $isDisplayingAlert) {
			Alert(
				title: Text(alert?.title ?? ""),
				message: Text(alert?.message ?? ""),
				dismissButton: .default(Text("OK")) {
					alert = nil
					isSending = false
				}
			)
		}
	}

	private func publish() {
		bridge.sendLogMessage(
			level: message.level.rawValue,
			message: message.message,
			fields: message.fields
		)

		alert = ("Success", "The message has been sent.")
	}
}
