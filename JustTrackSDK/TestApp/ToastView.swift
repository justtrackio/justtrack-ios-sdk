import SwiftUI

struct ToastView: View {
	var text: String

	var body: some View {
		Text(text)
			.font(.system(size: 17, weight: .medium, design: .rounded))
			.lineLimit(nil)
			.multilineTextAlignment(.center)
			.padding(9)
			.background(Color.black.opacity(0.33))
			.foregroundColor(Color.white)
			.cornerRadius(12)
	}
}
