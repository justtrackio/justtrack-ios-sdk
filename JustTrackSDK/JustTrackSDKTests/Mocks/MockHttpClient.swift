@testable import JustTrackSDK

final class MockHttpClient: HttpClient {
	enum Call {
		case sendAttributionRequest(
			request: DTOAttributionRequest,
			userData: UserData
		)
		case sendUserEvents(
			events: DTOUserEvent,
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
		case sendLogs(
			input: DTOLogInput,
			userData: UserData
		)
		case getSignedIpClaim(
			ipProtocol: IPProtocol,
			userData: UserData
		)
		case setRules(
			eventConfig: AttributionOutputSdkConfig.Event
		)
		case sendAnonymizeRequest(
			request: DTOAnonymizeRequest,
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

	var sendAttributionRequestResponseData = Data()
	var sendUserEventsResponseData = Data()
	var sendCustomUserIdResponseData = Data()
	var sendFirebaseAppInstanceIdResponseData = Data()
	var sendLogsResponseData = Data()
	var getSignedIpClaimResponseData = Data()
	var sendAnonymizeRequestResponseData = Data()
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
		sendUserEventsResponseData = Data()
		sendCustomUserIdResponseData = Data()
		sendFirebaseAppInstanceIdResponseData = Data()
		sendLogsResponseData = Data()
		getSignedIpClaimResponseData = Data()
		sendAnonymizeRequestResponseData = Data()
		sendSetExperimentVariantResponseData = Data()
		sendSetExperimentVariantError = nil
		getAssignmentsResponseData = Data()
		getAssignmentsRetryAfterSeconds = nil
		getAssignmentsError = nil
		postEnrollmentsResponseData = Data()
		postEnrollmentsError = nil
	}

	func sendAttributionRequest(
		request: DTOAttributionRequest,
		userData: UserData
	) -> Future<Data> {
		calls.append(.sendAttributionRequest(request: request, userData: userData))
		return FutureImpl<Data>().resolve(sendAttributionRequestResponseData)
	}

	func sendUserEvents(
		events: DTOUserEvent,
		userData: UserData
	) -> Future<Data> {
		calls.append(.sendUserEvents(events: events, userData: userData))
		return FutureImpl<Data>().resolve(sendUserEventsResponseData)
	}

	func sendCustomUserId(
		request: DTOPublishCustomUserIdRequest,
		userData: UserData
	) -> Future<Data> {
		calls.append(.sendCustomUserId(request: request, userData: userData))
		return FutureImpl<Data>().resolve(sendCustomUserIdResponseData)
	}

	func sendFirebaseAppInstanceId(
		request: DTOPublishFirebaseAppInstanceIdRequest,
		userData: UserData
	) -> Future<Data> {
		calls.append(.sendFirebaseAppInstanceId(request: request, userData: userData))
		return FutureImpl<Data>().resolve(sendFirebaseAppInstanceIdResponseData)
	}

	func sendLogs(
		input: DTOLogInput,
		userData: UserData
	) -> Future<Data> {
		calls.append(.sendLogs(input: input, userData: userData))
		return FutureImpl<Data>().resolve(sendLogsResponseData)
	}

	func getSignedIpClaim(
		ipProtocol: IPProtocol,
		userData: UserData
	) -> Future<Data> {
		calls.append(.getSignedIpClaim(ipProtocol: ipProtocol, userData: userData))
		return FutureImpl<Data>().resolve(getSignedIpClaimResponseData)
	}

	func setRules(
		eventConfig: AttributionOutputSdkConfig.Event
	) {
		calls.append(.setRules(eventConfig: eventConfig))
	}

	func sendAnonymizeRequest(
		request: DTOAnonymizeRequest,
		userData: UserData
	) -> Future<Data> {
		calls.append(.sendAnonymizeRequest(request: request, userData: userData))
		return FutureImpl<Data>().resolve(sendAnonymizeRequestResponseData)
	}

	func sendSetExperimentVariant(
		request: DTOSetExperimentVariantRequest,
		userData: UserData
	) -> Future<Data> {
		calls.append(.sendSetExperimentVariant(request: request, userData: userData))

		if let error = sendSetExperimentVariantError {
			return FutureImpl<Data>().reject(error)
		}

		return FutureImpl<Data>().resolve(sendSetExperimentVariantResponseData)
	}

	func getAssignments(
		parameters: GetAssignmentsParameters,
		userData: UserData
	) -> Future<AssignmentsResponse> {
		calls.append(.getAssignments(parameters: parameters, userData: userData))

		if let error = getAssignmentsError {
			return FutureImpl<AssignmentsResponse>().reject(error)
		}

		let response = AssignmentsResponse(data: getAssignmentsResponseData, retryAfterSeconds: getAssignmentsRetryAfterSeconds)
		return FutureImpl<AssignmentsResponse>().resolve(response)
	}

	func postEnrollments(
		request: DTOPostEnrollmentRequest,
		userData: UserData
	) -> Future<Data> {
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
		case let (.sendUserEvents(lhsEvents, lhsUserData), .sendUserEvents(rhsEvents, rhsUserData)):
			return lhsEvents == rhsEvents && lhsUserData == rhsUserData
		case let (.sendCustomUserId(lhsRequest, lhsUserData), .sendCustomUserId(rhsRequest, rhsUserData)):
			return lhsRequest == rhsRequest && lhsUserData == rhsUserData
		case let (.sendFirebaseAppInstanceId(lhsRequest, lhsUserData), .sendFirebaseAppInstanceId(rhsRequest, rhsUserData)):
			return lhsRequest == rhsRequest && lhsUserData == rhsUserData
		case let (.sendLogs(lhsInput, lhsUserData), .sendLogs(rhsInput, rhsUserData)):
			return lhsInput == rhsInput && lhsUserData == rhsUserData
		case let (.getSignedIpClaim(lhsIpProtocol, lhsUserData), .getSignedIpClaim(rhsIpProtocol, rhsUserData)):
			return lhsIpProtocol == rhsIpProtocol && lhsUserData == rhsUserData
		case let (.setRules(lhsEventConfig), .setRules(rhsEventConfig)):
			return lhsEventConfig == rhsEventConfig
		case let (.sendAnonymizeRequest(lhsRequest, lhsUserData), .sendAnonymizeRequest(rhsRequest, rhsUserData)):
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
