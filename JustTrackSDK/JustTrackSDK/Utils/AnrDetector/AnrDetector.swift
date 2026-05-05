protocol AnrDetector: AnyObject {
	func setHandler(_ handler: @escaping (AnrReport) -> Void)

	func removeHandler()
}
