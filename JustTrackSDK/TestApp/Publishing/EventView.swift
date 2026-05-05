import JustTrackSDK
import SwiftUI

struct EventView: View {
	@ObservedObject private var event = Event()

	@State private var selectedUnitIndex: Int = 0
	private let units = ["none"] + Unit.allCases.map(\.rawValue)

	@State private var isDisplayingAlert = false
	@State private var alert: (title: String, message: String?)? {
		didSet {
			isDisplayingAlert = alert != nil
		}
	}

	private var sdk: JustTrackSdk

	init(
		event: Event = Event(),
		sdk: JustTrackSdk
	) {
		self.event = event
		self.sdk = sdk
	}

	var body: some View {
		VStack {
			List {
				VStack(alignment: .leading) {
					ListItemTitleView("Name")
					TextField("", text: $event.name)
						.autocapitalization(.none)
						.fontForListItemText()
				}

				VStack(alignment: .leading) {
					ListItemTitleView("Value")
					TextField(
						"",
						value: $event.value,
						formatter: {
							let formatter = NumberFormatter()
							formatter.maximumFractionDigits = 99
							formatter.decimalSeparator = "."
							return formatter
						}()
					)
					.fontForListItemText()
				}

				VStack(alignment: .leading) {
					Spacer()
					ListItemTitleView("Unit")
					Spacer()
					ForEach(0..<units.count, id: \.self) { index in
						Text(units[index])
							.fontForListItemText()
							.foregroundColor(selectedUnitIndex == index ? .black : .gray)
							.onTapGesture {
								selectedUnitIndex = index
								event.unit = Unit(rawValue: units[index])
							}
						Spacer()
					}
				}

				VStack(alignment: .leading) {
					ListItemTitleView("Currency")
					TextField("none", text: $event.currency).fontForListItemText()
				}

				NavigationLink(
					"Dimensions",
					destination: FieldsView(
						fields: $event.dimensions,
						title: "Dimensions"
					)
				)
				.fontForListItemTitle()
			}
		}
		.navigationTitle("Event")
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
				}
			)
		}
	}

	private func publish() {
		let initialEvent: AppEvent

		if !event.currency.isEmpty {
			initialEvent = AppEvent(name: event.name, money: Money(value: event.value, currency: event.currency))
		} else if let unit = event.unit {
			initialEvent = AppEvent(name: event.name, value: event.value, unit: unit)
		} else {
			initialEvent = AppEvent(event.name)
		}

		let event = event.dimensions.reduce(initialEvent) { event, dimension in
			event.add(dimension: dimension.key, value: dimension.value)
		}

		sdk.track(eventName: "event_click")
		sdk.track(event: AppEvent("event_click"))

		sdk.track(event: event).observe { result in
			switch result {
			case .success:
				alert = ("Success", "The event has been successfully sent.")
			case let .failure(error):
				alert = ("Failure", error.localizedDescription)
			}
		}
	}
}
