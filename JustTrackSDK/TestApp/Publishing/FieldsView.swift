import SwiftUI

struct FieldsView: View {
	@State private var keyValuePairs: [(key: String, value: String)] = []
	@Binding var fields: [String: String]

	let title: String

	var body: some View {
		List {
			ForEach(0..<keyValuePairs.count, id: \.self) { index in
				HStack {
					TextField(
						"Key",
						text: Binding(
							get: {
								keyValuePairs[index].key
							},
							set: { newKey in
								keyValuePairs[index].key = newKey
							}
						)
					)
					.fontForListItemText()
					.textFieldStyle(RoundedBorderTextFieldStyle())
					.padding(.trailing, 8)

					TextField(
						"Value",
						text: Binding(
							get: {
								keyValuePairs[index].value
							},
							set: { newValue in
								keyValuePairs[index].value = newValue
							}
						)
					)
					.fontForListItemText()
					.textFieldStyle(RoundedBorderTextFieldStyle())
				}
			}
			.onDelete { indices in
				keyValuePairs.remove(atOffsets: indices)
			}
		}
		.onAppear {
			keyValuePairs = fields.map { (key: $0.key, value: $0.value) }
		}
		.onDisappear {
			fields.removeAll()
			for pair in keyValuePairs {
				guard !pair.key.isEmpty && !pair.value.isEmpty else {
					continue
				}
				fields[pair.key] = pair.value
			}
		}
		.navigationTitle(title)
		.navigationBarItems(
			trailing: Button(
				action: {
					keyValuePairs.append((key: "", value: ""))
				},
				label: {
					Image(systemName: "plus.rectangle.on.rectangle")
				}
			)
		)
	}
}
