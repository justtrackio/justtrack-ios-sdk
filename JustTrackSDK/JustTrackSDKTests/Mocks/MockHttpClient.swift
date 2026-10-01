import Foundation

@testable import JustTrackSDK

// MARK: - MockAttributionApi

final class MockAttributionApi: AttributionApi {
	enum Call {
		case sendAttributionRequest(
			request: DTOAttributionRequest,
			userData: UserData
		)
		case getSignedIpClaim(
			ipProtocol: IPProtocol,
			userData: UserData
		)
	}

	var calls: [Call] = []

	var sendAttributionRequestResponseData = Data()
	var getSignedIpClaimResponseData = Data()

	func reset() {
		calls = []
		sendAttributionRequestResponseData = Data()
		getSignedIpClaimResponseData = Data()
	}

	func sendAttributionRequest(request: DTOAttributionRequest, userData: UserData) -> Future<Data> {
		calls.append(.sendAttributionRequest(request: request, userData: userData))
		return FutureImpl<Data>().resolve(sendAttributionRequestResponseData)
	}

	func getSignedIpClaim(ipProtocol: IPProtocol, userData: UserData) -> Future<Data> {
		calls.append(.getSignedIpClaim(ipProtocol: ipProtocol, userData: userData))
		return FutureImpl<Data>().resolve(getSignedIpClaimResponseData)
	}
}

extension MockAttributionApi.Call: Equatable {
	static func == (lhs: MockAttributionApi.Call, rhs: MockAttributionApi.Call) -> Bool {
		switch (lhs, rhs) {
		case let (.sendAttributionRequest(lhsRequest, lhsUserData), .sendAttributionRequest(rhsRequest, rhsUserData)):
			return lhsRequest == rhsRequest && lhsUserData == rhsUserData
		case let (.getSignedIpClaim(lhsIpProtocol, lhsUserData), .getSignedIpClaim(rhsIpProtocol, rhsUserData)):
			return lhsIpProtocol == rhsIpProtocol && lhsUserData == rhsUserData
		default:
			return false
		}
	}
}

// MARK: - MockPrivacyApi

final class MockPrivacyApi: PrivacyApi {
	enum Call {
		case sendAnonymizeRequest(
			request: DTOAnonymizeRequest,
			userData: UserData
		)
	}

	var calls: [Call] = []

	var sendAnonymizeRequestResponseData = Data()

	func reset() {
		calls = []
		sendAnonymizeRequestResponseData = Data()
	}

	func sendAnonymizeRequest(request: DTOAnonymizeRequest, userData: UserData) -> Future<Data> {
		calls.append(.sendAnonymizeRequest(request: request, userData: userData))
		return FutureImpl<Data>().resolve(sendAnonymizeRequestResponseData)
	}
}

extension MockPrivacyApi.Call: Equatable {
	static func == (lhs: MockPrivacyApi.Call, rhs: MockPrivacyApi.Call) -> Bool {
		switch (lhs, rhs) {
		case let (.sendAnonymizeRequest(lhsRequest, lhsUserData), .sendAnonymizeRequest(rhsRequest, rhsUserData)):
			return lhsRequest == rhsRequest && lhsUserData == rhsUserData
		default:
			return false
		}
	}
}

// MARK: - MockEventApi

final class MockEventApi: EventApi {
	enum Call {
		case sendUserEvents(
			events: DTOUserEvent,
			userData: UserData
		)
	}

	var calls: [Call] = []

	var sendUserEventsResponseData = Data()

	func reset() {
		calls = []
		sendUserEventsResponseData = Data()
	}

	func sendUserEvents(events: DTOUserEvent, userData: UserData) -> Future<Data> {
		calls.append(.sendUserEvents(events: events, userData: userData))
		return FutureImpl<Data>().resolve(sendUserEventsResponseData)
	}
}

extension MockEventApi.Call: Equatable {
	static func == (lhs: MockEventApi.Call, rhs: MockEventApi.Call) -> Bool {
		switch (lhs, rhs) {
		case let (.sendUserEvents(lhsEvents, lhsUserData), .sendUserEvents(rhsEvents, rhsUserData)):
			return lhsEvents == rhsEvents && lhsUserData == rhsUserData
		default:
			return false
		}
	}
}

// MARK: - MockLogApi

final class MockLogApi: LogApi {
	enum Call {
		case sendLogs(
			input: DTOLogInput,
			userData: UserData
		)
	}

	var calls: [Call] = []

	var sendLogsResponseData = Data()

	func reset() {
		calls = []
		sendLogsResponseData = Data()
	}

	func sendLogs(input: DTOLogInput, userData: UserData) -> Future<Data> {
		calls.append(.sendLogs(input: input, userData: userData))
		return FutureImpl<Data>().resolve(sendLogsResponseData)
	}
}

extension MockLogApi.Call: Equatable {
	static func == (lhs: MockLogApi.Call, rhs: MockLogApi.Call) -> Bool {
		switch (lhs, rhs) {
		case let (.sendLogs(lhsInput, lhsUserData), .sendLogs(rhsInput, rhsUserData)):
			return lhsInput == rhsInput && lhsUserData == rhsUserData
		default:
			return false
		}
	}
}

// MARK: - MockUserPropertyApi

final class MockUserPropertyApi: UserPropertyApi {
	enum Call {
		case sendCustomUserId(
			request: DTOPublishCustomUserIdRequest,
			userData: UserData
		)
		case sendFirebaseAppInstanceId(
			request: DTOPublishFirebaseAppInstanceIdRequest,
			userData: UserData
		)
	}

	var calls: [Call] = []

	var sendCustomUserIdResponseData = Data()
	var sendFirebaseAppInstanceIdResponseData = Data()

	func reset() {
		calls = []
		sendCustomUserIdResponseData = Data()
		sendFirebaseAppInstanceIdResponseData = Data()
	}

	func sendCustomUserId(request: DTOPublishCustomUserIdRequest, userData: UserData) -> Future<Data> {
		calls.append(.sendCustomUserId(request: request, userData: userData))
		return FutureImpl<Data>().resolve(sendCustomUserIdResponseData)
	}

	func sendFirebaseAppInstanceId(request: DTOPublishFirebaseAppInstanceIdRequest, userData: UserData) -> Future<Data> {
		calls.append(.sendFirebaseAppInstanceId(request: request, userData: userData))
		return FutureImpl<Data>().resolve(sendFirebaseAppInstanceIdResponseData)
	}
}

extension MockUserPropertyApi.Call: Equatable {
	static func == (lhs: MockUserPropertyApi.Call, rhs: MockUserPropertyApi.Call) -> Bool {
		switch (lhs, rhs) {
		case let (.sendCustomUserId(lhsRequest, lhsUserData), .sendCustomUserId(rhsRequest, rhsUserData)):
			return lhsRequest == rhsRequest && lhsUserData == rhsUserData
		case let (.sendFirebaseAppInstanceId(lhsRequest, lhsUserData), .sendFirebaseAppInstanceId(rhsRequest, rhsUserData)):
			return lhsRequest == rhsRequest && lhsUserData == rhsUserData
		default:
			return false
		}
	}
}

// MARK: - MockRemoteConfigApi

final class MockRemoteConfigApi: RemoteConfigApi {
	enum Call {
		case sendSetExperimentVariant(
			request: DTOSetExperimentVariantRequest,
			userData: UserData
		)
		case getAssignments(
			parameters: GetAssignmentsParameters,
			userData: UserData
		)
		case postEnrollments(
			request: DTOPostEnrollmentRequest,
			userData: UserData
		)
	}

	var calls: [Call] = []

	var sendSetExperimentVariantResponseData = Data()
	var sendSetExperimentVariantError: Error?
	var getAssignmentsResponseData = Data()
	var getAssignmentsRetryAfterSeconds: Int?
	var getAssignmentsError: Error?
	var postEnrollmentsResponseData = Data()
	var postEnrollmentsError: Error?

	func reset() {
		calls = []
		sendSetExperimentVariantResponseData = Data()
		sendSetExperimentVariantError = nil
		getAssignmentsResponseData = Data()
		getAssignmentsRetryAfterSeconds = nil
		getAssignmentsError = nil
		postEnrollmentsResponseData = Data()
		postEnrollmentsError = nil
	}

	func sendSetExperimentVariant(request: DTOSetExperimentVariantRequest, userData: UserData) -> Future<Data> {
		calls.append(.sendSetExperimentVariant(request: request, userData: userData))

		if let error = sendSetExperimentVariantError {
			return FutureImpl<Data>().reject(error)
		}

		return FutureImpl<Data>().resolve(sendSetExperimentVariantResponseData)
	}

	func getAssignments(parameters: GetAssignmentsParameters, userData: UserData) -> Future<AssignmentsResponse> {
		calls.append(.getAssignments(parameters: parameters, userData: userData))

		if let error = getAssignmentsError {
			return FutureImpl<AssignmentsResponse>().reject(error)
		}

		let response = AssignmentsResponse(data: getAssignmentsResponseData, retryAfterSeconds: getAssignmentsRetryAfterSeconds)
		return FutureImpl<AssignmentsResponse>().resolve(response)
	}

	func postEnrollments(request: DTOPostEnrollmentRequest, userData: UserData) -> Future<Data> {
		calls.append(.postEnrollments(request: request, userData: userData))

		if let error = postEnrollmentsError {
			return FutureImpl<Data>().reject(error)
		}

		return FutureImpl<Data>().resolve(postEnrollmentsResponseData)
	}
}

extension MockRemoteConfigApi.Call: Equatable {
	static func == (lhs: MockRemoteConfigApi.Call, rhs: MockRemoteConfigApi.Call) -> Bool {
		switch (lhs, rhs) {
		case let (.sendSetExperimentVariant(lhsRequest, lhsUserData), .sendSetExperimentVariant(rhsRequest, rhsUserData)):
			return lhsRequest == rhsRequest && lhsUserData == rhsUserData
		case let (.getAssignments(lhsParameters, lhsUserData), .getAssignments(rhsParameters, rhsUserData)):
			return lhsParameters.appVersion.equals(rhsParameters.appVersion) && lhsUserData == rhsUserData
		case let (.postEnrollments(lhsRequest, lhsUserData), .postEnrollments(rhsRequest, rhsUserData)):
			return lhsRequest == rhsRequest && lhsUserData == rhsUserData
		default:
			return false
		}
	}
}

// MARK: - MockHttpClient (Combined mock for integration tests)

/// Combined mock implementing all 5 API protocols with a shared `calls` array.
/// Used by integration tests (JustTrackSdkTests) that need to verify calls across multiple domains.
final class MockHttpClient: AttributionApi, PrivacyApi, EventApi, LogApi, UserPropertyApi, RemoteConfigApi, HttpClient {
	enum Call {
		case sendAttributionRequest(
			request: DTOAttributionRequest,
			userData: UserData
		)
		case sendAnonymizeRequest(
			request: DTOAnonymizeRequest,
			userData: UserData
		)
		case getSignedIpClaim(
			ipProtocol: IPProtocol,
			userData: UserData
		)
		case sendUserEvents(
			events: DTOUserEvent,
			userData: UserData
		)
		case sendLogs(
			input: DTOLogInput,
			userData: UserData
		)
		case sendCustomUserId(
			request: DTOPublishCustomUserIdRequest,
			userData: UserData
		)
		case sendFirebaseAppInstanceId(
			request: DTOPublishFirebaseAppInstanceIdRequest,
			userData: UserData
		)
		case sendSetExperimentVariant(
			request: DTOSetExperimentVariantRequest,
			userData: UserData
		)
		case getAssignments(
			parameters: GetAssignmentsParameters,
			userData: UserData
		)
		case postEnrollments(
			request: DTOPostEnrollmentRequest,
			userData: UserData
		)
	}

	var calls: [Call] = []

	// Response data / errors
	var sendAttributionRequestResponseData = Data()
	var sendAnonymizeRequestResponseData = Data()
	var getSignedIpClaimResponseData = Data()
	var sendUserEventsResponseData = Data()
	var sendLogsResponseData = Data()
	var sendCustomUserIdResponseData = Data()
	var sendFirebaseAppInstanceIdResponseData = Data()
	var sendSetExperimentVariantResponseData = Data()
	var sendSetExperimentVariantError: Error?
	var getAssignmentsResponseData = Data()
	var getAssignmentsRetryAfterSeconds: Int?
	var getAssignmentsError: Error?
	var postEnrollmentsResponseData = Data()
	var postEnrollmentsError: Error?

	func reset() {
		calls = []
		sendAttributionRequestResponseData = Data()
		sendAnonymizeRequestResponseData = Data()
		getSignedIpClaimResponseData = Data()
		sendUserEventsResponseData = Data()
		sendLogsResponseData = Data()
		sendCustomUserIdResponseData = Data()
		sendFirebaseAppInstanceIdResponseData = Data()
		sendSetExperimentVariantResponseData = Data()
		sendSetExperimentVariantError = nil
		getAssignmentsResponseData = Data()
		getAssignmentsRetryAfterSeconds = nil
		getAssignmentsError = nil
		postEnrollmentsResponseData = Data()
		postEnrollmentsError = nil
	}

	// MARK: HttpClient

	func execute(
		requestName: String,
		urlString: String,
		headers: [String: String],
		body: Data?,
		retries: Int,
		classifier: ErrorClassifier
	) -> Future<Data> {
		return FutureImpl<Data>().resolve(Data())
	}

	func execute<T>(
		requestName: String,
		urlString: String,
		headers: [String: String],
		body: Data?,
		retries: Int,
		classifier: ErrorClassifier,
		transform: @escaping (Data, HTTPURLResponse) -> T
	) -> Future<T> {
		return FutureImpl<T>().reject(NetworkError.networkError(NSError(domain: "MockHttpClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "MockHttpClient does not support execute<T>"])))
	}

	func execute(
		requestName: String,
		urlString: String,
		headers: [String: String],
		body: Data,
		retryDelaySeconds: [TimeInterval],
		classifier: ErrorClassifier
	) -> Future<Data> {
		return FutureImpl<Data>().resolve(Data())
	}

	// MARK: AttributionApi

	func sendAttributionRequest(request: DTOAttributionRequest, userData: UserData) -> Future<Data> {
		calls.append(.sendAttributionRequest(request: request, userData: userData))
		return FutureImpl<Data>().resolve(sendAttributionRequestResponseData)
	}

	func sendAnonymizeRequest(request: DTOAnonymizeRequest, userData: UserData) -> Future<Data> {
		calls.append(.sendAnonymizeRequest(request: request, userData: userData))
		return FutureImpl<Data>().resolve(sendAnonymizeRequestResponseData)
	}

	func getSignedIpClaim(ipProtocol: IPProtocol, userData: UserData) -> Future<Data> {
		calls.append(.getSignedIpClaim(ipProtocol: ipProtocol, userData: userData))
		return FutureImpl<Data>().resolve(getSignedIpClaimResponseData)
	}

	// MARK: EventApi

	func sendUserEvents(events: DTOUserEvent, userData: UserData) -> Future<Data> {
		calls.append(.sendUserEvents(events: events, userData: userData))
		return FutureImpl<Data>().resolve(sendUserEventsResponseData)
	}

	// MARK: LogApi

	func sendLogs(input: DTOLogInput, userData: UserData) -> Future<Data> {
		calls.append(.sendLogs(input: input, userData: userData))
		return FutureImpl<Data>().resolve(sendLogsResponseData)
	}

	// MARK: UserPropertyApi

	func sendCustomUserId(request: DTOPublishCustomUserIdRequest, userData: UserData) -> Future<Data> {
		calls.append(.sendCustomUserId(request: request, userData: userData))
		return FutureImpl<Data>().resolve(sendCustomUserIdResponseData)
	}

	func sendFirebaseAppInstanceId(request: DTOPublishFirebaseAppInstanceIdRequest, userData: UserData) -> Future<Data> {
		calls.append(.sendFirebaseAppInstanceId(request: request, userData: userData))
		return FutureImpl<Data>().resolve(sendFirebaseAppInstanceIdResponseData)
	}

	// MARK: RemoteConfigApi

	func sendSetExperimentVariant(request: DTOSetExperimentVariantRequest, userData: UserData) -> Future<Data> {
		calls.append(.sendSetExperimentVariant(request: request, userData: userData))

		if let error = sendSetExperimentVariantError {
			return FutureImpl<Data>().reject(error)
		}

		return FutureImpl<Data>().resolve(sendSetExperimentVariantResponseData)
	}

	func getAssignments(parameters: GetAssignmentsParameters, userData: UserData) -> Future<AssignmentsResponse> {
		calls.append(.getAssignments(parameters: parameters, userData: userData))

		if let error = getAssignmentsError {
			return FutureImpl<AssignmentsResponse>().reject(error)
		}

		let response = AssignmentsResponse(data: getAssignmentsResponseData, retryAfterSeconds: getAssignmentsRetryAfterSeconds)
		return FutureImpl<AssignmentsResponse>().resolve(response)
	}

	func postEnrollments(request: DTOPostEnrollmentRequest, userData: UserData) -> Future<Data> {
		calls.append(.postEnrollments(request: request, userData: userData))

		if let error = postEnrollmentsError {
			return FutureImpl<Data>().reject(error)
		}

		return FutureImpl<Data>().resolve(postEnrollmentsResponseData)
	}
}

extension MockHttpClient.Call: Equatable {
	static func == (lhs: MockHttpClient.Call, rhs: MockHttpClient.Call) -> Bool {
		switch (lhs, rhs) {
		case let (.sendAttributionRequest(lhsRequest, lhsUserData), .sendAttributionRequest(rhsRequest, rhsUserData)):
			return lhsRequest == rhsRequest && lhsUserData == rhsUserData
		case let (.sendAnonymizeRequest(lhsRequest, lhsUserData), .sendAnonymizeRequest(rhsRequest, rhsUserData)):
			return lhsRequest == rhsRequest && lhsUserData == rhsUserData
		case let (.getSignedIpClaim(lhsIpProtocol, lhsUserData), .getSignedIpClaim(rhsIpProtocol, rhsUserData)):
			return lhsIpProtocol == rhsIpProtocol && lhsUserData == rhsUserData
		case let (.sendUserEvents(lhsEvents, lhsUserData), .sendUserEvents(rhsEvents, rhsUserData)):
			return lhsEvents == rhsEvents && lhsUserData == rhsUserData
		case let (.sendLogs(lhsInput, lhsUserData), .sendLogs(rhsInput, rhsUserData)):
			return lhsInput == rhsInput && lhsUserData == rhsUserData
		case let (.sendCustomUserId(lhsRequest, lhsUserData), .sendCustomUserId(rhsRequest, rhsUserData)):
			return lhsRequest == rhsRequest && lhsUserData == rhsUserData
		case let (.sendFirebaseAppInstanceId(lhsRequest, lhsUserData), .sendFirebaseAppInstanceId(rhsRequest, rhsUserData)):
			return lhsRequest == rhsRequest && lhsUserData == rhsUserData
		case let (.sendSetExperimentVariant(lhsRequest, lhsUserData), .sendSetExperimentVariant(rhsRequest, rhsUserData)):
			return lhsRequest == rhsRequest && lhsUserData == rhsUserData
		case let (.getAssignments(lhsParameters, lhsUserData), .getAssignments(rhsParameters, rhsUserData)):
			return lhsParameters.appVersion.equals(rhsParameters.appVersion) && lhsUserData == rhsUserData
		case let (.postEnrollments(lhsRequest, lhsUserData), .postEnrollments(rhsRequest, rhsUserData)):
			return lhsRequest == rhsRequest && lhsUserData == rhsUserData
		default:
			return false
		}
	}
}

// MARK: - StubHttpClient

/// Minimal HttpClient stub for tests that need an HttpClient parameter but don't use it for API calls.
final class StubHttpClient: HttpClient {
	func execute(
		requestName: String,
		urlString: String,
		headers: [String: String],
		body: Data?,
		retries: Int,
		classifier: ErrorClassifier
	) -> Future<Data> {
		return FutureImpl<Data>().resolve(Data())
	}

	func execute<T>(
		requestName: String,
		urlString: String,
		headers: [String: String],
		body: Data?,
		retries: Int,
		classifier: ErrorClassifier,
		transform: @escaping (Data, HTTPURLResponse) -> T
	) -> Future<T> {
		return FutureImpl<T>().reject(NetworkError.networkError(NSError(domain: "StubHttpClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "StubHttpClient does not support execute<T>"])))
	}

	func execute(
		requestName: String,
		urlString: String,
		headers: [String: String],
		body: Data,
		retryDelaySeconds: [TimeInterval],
		classifier: ErrorClassifier
	) -> Future<Data> {
		return FutureImpl<Data>().resolve(Data())
	}
}
