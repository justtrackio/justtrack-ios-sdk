protocol AppDelegateWatcherReportee: AnyObject {
	func moveToForeground()
	func moveToBackground()
	func applicationWillTerminate()
}
