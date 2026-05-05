import SwiftUI

struct SectionHeaderView: View {
	var header: String = ""

	init(_ header: String) {
		self.header = header
	}

	var body: some View {
		Text(header).bold()
	}
}
