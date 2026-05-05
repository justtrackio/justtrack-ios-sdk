import Foundation

private let dispatchSpecificKey = DispatchSpecificKey<DispatchQueue>()

extension DispatchQueue {
	var isCurrent: Bool {
		DispatchQueue.getSpecific(key: dispatchSpecificKey) === self
	}

	func makeIdentifiable() {
		setSpecific(key: dispatchSpecificKey, value: self)
	}
}
