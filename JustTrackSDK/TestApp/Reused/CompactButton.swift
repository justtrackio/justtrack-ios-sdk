import SwiftUI

/// A small button meant to sit inline next to a text field in a list row.
/// Use `DefaultButton` for full-width, standalone actions.
struct CompactButton: View {
	@Environment(\.isEnabled) private var isEnabled

	private let title: String
	private let action: () -> Void

	init(_ title: String, action: @escaping () -> Void = {}) {
		self.title = title
		self.action = action
	}

	var body: some View {
		Button(action: action) {
			Text(title)
				.font(.system(size: 13, weight: .semibold))
				.padding(.horizontal, 16)
				.padding(.vertical, 8)
				.background(isEnabled ? Color.blue : Color.gray.opacity(0.3))
				.foregroundColor(.white)
				.cornerRadius(8)
		}
		.buttonStyle(PlainButtonStyle())
	}
}
