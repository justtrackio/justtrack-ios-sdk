import JustTrackSDK
import SwiftUI

struct AnrView: View {
	@State private var fromSDK = false

	private let bridge: SdkBridge

	init(
		bridge: SdkBridge
	) {
		self.bridge = bridge
	}

	var body: some View {
		VStack(alignment: .center) {
			HStack {
				VStack(alignment: .leading) {
					ListItemTitleView("From the SDK")
				}

				Spacer()

				Toggle("", isOn: $fromSDK).frame(width: 56, alignment: .trailing)
			}
			.padding()

			DefaultButton("Block for 1s") {
				fromSDK ? bridge.sleep(for: 1) : { sleep(1) }()
			}
			DefaultButton("Block for 10s") {
				fromSDK ? bridge.sleep(for: 10) : { sleep(10) }()
			}
			DefaultButton("Block indefinitely") {
				fromSDK ? bridge.sleep() : { while true {} }()
			}

			Spacer()
		}
	}
}
