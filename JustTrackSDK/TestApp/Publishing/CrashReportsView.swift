import JustTrackSDK
import SwiftUI

struct CrashReportsView: View {
	@State private var fromSDK = false

	private let bridge: SdkBridge

	init(
		bridge: SdkBridge
	) {
		self.bridge = bridge
	}

	var body: some View {
		ScrollView {
			VStack {
				HStack {
					VStack(alignment: .leading) {
						ListItemTitleView("From the SDK")
					}

					Spacer()

					Toggle("", isOn: $fromSDK).frame(width: 56, alignment: .trailing)
				}
				.padding()

				DefaultButton("Objective-C Exception") {
					let action = {
						let arr = NSArray(array: [])
						_ = arr[1]
					}
					fromSDK ? bridge.perform(action: action) : action()
				}
				DefaultButton("Unowned access") {
					let action = {
						var value: NSObject? = NSObject()
						unowned let unownedValue = value
						value = nil
						unownedValue?.copy()
					}
					fromSDK ? bridge.perform(action: action) : action()
				}
				DefaultButton("Double free") {
					let action = {
						let data = malloc(16)
						free(data)
						free(data)
					}
					fromSDK ? bridge.perform(action: action) : action()
				}
				DefaultButton("Bad pointer dereference") {
					let action = {
						let data = UnsafePointer<Int>(bitPattern: 32)
						print(data?.pointee as Any)
					}
					fromSDK ? bridge.perform(action: action) : action()
				}
				DefaultButton("Swift Error") {
					let action = {
						let arr = [Any]()
						_ = arr[1]
					}
					fromSDK ? bridge.perform(action: action) : action()
				}
				DefaultButton("Heap overflow") {
					let action = {
						let root = LinkedList()
						var last = root

						while true {
							last = last.grow()
						}
					}
					fromSDK ? bridge.perform(action: action) : action()
				}
				DefaultButton("Stack overflow") {
					let action = {
						_ = callLoop(n: 1)
					}
					fromSDK ? bridge.perform(action: action) : action()
				}
				DefaultButton("SIGSEGV") {
					let action = {
						SignalSimulator.trigger_sigsegv()
					}
					fromSDK ? bridge.perform(action: action) : action()
				}
				DefaultButton("SIGBUS") {
					let action = {
						SignalSimulator.trigger_sigbus()
					}
					fromSDK ? bridge.perform(action: action) : action()
				}
				DefaultButton("SIGPIPE") {
					let action = {
						SignalSimulator.trigger_sigpipe()
					}
					fromSDK ? bridge.perform(action: action) : action()
				}
				DefaultButton("SIGABRT") {
					let action: () -> Void = {
						abort()
					}
					fromSDK ? bridge.perform(action: action) : action()
				}
				DefaultButton("SIGFPE") {
					let action: () -> Void = {
						raise(SIGFPE)
					}
					fromSDK ? bridge.perform(action: action) : action()
				}
				DefaultButton("SIGILL") {
					let action: () -> Void = {
						raise(SIGILL)
					}
					fromSDK ? bridge.perform(action: action) : action()
				}
			}
			.frame(maxWidth: .infinity)
			.padding()
		}
		.navigationTitle("Crash Reports")
	}

	func callLoop(n: Int) -> Int {
		if n == 0 {
			return 0
		}

		return callLoop(n: n + 1) + 1
	}
}

private class LinkedList {
	private var payload: [UInt32]
	private var next: LinkedList?

	init() {
		payload = [UInt32](Array(repeating: 0, count: 65535))

		for i in 0...255 {
			payload[i] = UInt32.random(in: 0...0xFFFF_FFFF)
		}
		for i in 256..<payload.count {
			payload[i] = payload[i - 256] + 1
		}
	}

	func grow() -> LinkedList {
		let next = LinkedList()
		self.next = next

		return next
	}
}
