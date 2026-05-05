import SwiftUI

struct ListItemTextView: View {
	var text: String = ""

	init(_ text: String) {
		self.text = text
	}

	var body: some View {
		Text(text)
			.fontForListItemText()
			.lineLimit(nil)
	}
}

extension View {
	func fontForListItemText() -> some View {
		self.font(.system(size: 15, design: .monospaced))
	}
}
