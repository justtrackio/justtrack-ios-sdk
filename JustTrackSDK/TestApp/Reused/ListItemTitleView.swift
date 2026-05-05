import SwiftUI

struct ListItemTitleView: View {
	var title: String = ""

	init(_ title: String) {
		self.title = title
	}

	var body: some View {
		Text(title)
			.fontForListItemTitle()
			.padding(.bottom, 0.5)
	}
}

extension View {
	func fontForListItemTitle() -> some View {
		self
			.font(.system(size: 12, weight: .bold, design: .monospaced))
			.foregroundStyle(.gray)
	}
}
