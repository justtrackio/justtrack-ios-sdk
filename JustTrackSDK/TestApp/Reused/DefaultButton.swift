import SwiftUI

struct DefaultButton: View {
	var title: String
	var action: () -> Void
	let background: Color

	init(_ title: String, background: Color = .blue, action: @escaping () -> Void = {}) {
		self.title = title
		self.action = action
		self.background = background
	}

	var body: some View {
		Button(action: action) {
			Text(title)
				.font(.system(size: 14, weight: .heavy))
				.padding(.horizontal, 30)
				.padding(.vertical, 12)
				.frame(height: 60)
				.background(background)
				.foregroundColor(.white)
				.cornerRadius(10)
		}
	}
}
