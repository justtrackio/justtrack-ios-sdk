import JustTrackSDK
import SwiftUI

struct LogMetricView: View {
	@ObservedObject private var metric = LogMetric()

	@State private var selectedUnitIndex: Int = 0
	private let units = LogMetric.Unit.allCases.map(\.rawValue)

	@State private var isDisplayingAlert = false
	@State private var alert: (title: String, message: String?)? {
		didSet {
			isDisplayingAlert = alert != nil
		}
	}

	@State private var isSending = false

	private let bridge: SdkBridge

	init(
		metric: LogMetric = LogMetric(),
		bridge: SdkBridge
	) {
		self.metric = metric
		self.bridge = bridge
	}

	var body: some View {
		VStack {
			List {
				VStack(alignment: .leading) {
					ListItemTitleView("Metric")

					TextField(
						"Metric_1",
						text: $metric.metric
					)
					.fontForListItemText()
				}

				VStack(alignment: .leading) {
					ListItemTitleView("Value")

					TextField(
						"Value_1",
						value: $metric.value,
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
								metric.unit = LogMetric.Unit(rawValue: units[index]) ?? .count
							}
						Spacer()
					}
				}

				NavigationLink(
					"Dimensions",
					destination: FieldsView(
						fields: $metric.dimensions,
						title: "Dimensions"
					)
				)
				.fontForListItemTitle()
			}
		}
		.navigationTitle("Log Metric")
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
		bridge.sendLogMetric(
			metric: metric.metric,
			value: metric.value,
			unit: metric.unit.rawValue,
			dimensions: metric.dimensions
		)

		alert = ("Success", "The metric has been sent.")
	}
}
