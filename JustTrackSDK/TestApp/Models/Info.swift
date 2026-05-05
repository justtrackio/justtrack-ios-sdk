import SwiftUI

final class Info: ObservableObject {
	@Published var installIdItem: String = ""
	@Published var advertiserIdItem: String = ""

	let sdkVersionItem: String

	init(
		sdkVersionItem: String,
		installIdItem: String,
		advertiserIdItem: String
	) {
		self.sdkVersionItem = sdkVersionItem
		self.installIdItem = installIdItem
		self.advertiserIdItem = advertiserIdItem
	}
}
