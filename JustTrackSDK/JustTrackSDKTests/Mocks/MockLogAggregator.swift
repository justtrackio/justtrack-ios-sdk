@testable import JustTrackSDK

final class MockLogAggregator: LogAggregator {
	enum Call: Equatable {
		case addLogMessage(DTOLogMessage)
		case addLogMetric(DTOLogMetric)
		case addLogBreadcrumb(Breadcrumb)
		case sendLogsAndMetrics
		case getBreadcrumbs
		case moveToBackground
	}

	var calls = [Call]()

	var getBreadcrumbsResult = [Breadcrumb]()

	func reset() {
		calls = []
		getBreadcrumbsResult = []
	}

	func addLog(message: DTOLogMessage) {
		calls.append(.addLogMessage(message))
	}

	func addLog(metric: DTOLogMetric) {
		calls.append(.addLogMetric(metric))
	}

	func addLog(breadcrumb: Breadcrumb) {
		calls.append(.addLogBreadcrumb(breadcrumb))
	}

	func sendLogsAndMetrics(_ sender: @escaping ([DTOLogMessage], [DTOLogMetric]) -> Future<Data>) {
		calls.append(.sendLogsAndMetrics)
	}

	func getBreadcrumbs() -> [Breadcrumb] {
		calls.append(.getBreadcrumbs)
		return getBreadcrumbsResult
	}

	func moveToBackground() {
		calls.append(.moveToBackground)
	}
}
