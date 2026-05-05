final class UserDefaultsSequenceNumberProvider: SequenceNumberProvider {
	private let key: String

	init(
		key: String = "io.justtrack.sdk.UserDefaultsSequenceNumberProvider.key"
	) {
		self.key = key
	}

	func provideNext() -> Int {
		let numberToReturn = UserDefaults.standard.integer(forKey: key)
		let nextNumberToReturn = numberToReturn + 1
		UserDefaults.standard.set(nextNumberToReturn, forKey: key)
		return numberToReturn
	}
}
