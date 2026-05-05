@testable import JustTrackSDK

final class MockSequenceNumberProvider: SequenceNumberProvider {
	enum Call: Equatable {
		case provideNext(Int)
	}

	var calls = [Call]()

	func reset() {
		calls = []
	}

	var next = -1

	func provideNext() -> Int {
		next += 1
		calls.append(.provideNext(next))
		return next
	}
}
