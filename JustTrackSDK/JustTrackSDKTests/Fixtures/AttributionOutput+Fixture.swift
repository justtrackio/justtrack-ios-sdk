@testable import JustTrackSDK

extension AttributionOutput {
	static func fixture(
		attributionResponse: CompleteAttributionResponse = AttributionResponseImpl.fixture(),
		retargetingParameters: RetargetingParameters? = RetargetingParametersImpl.fixture(),
		testGroup: Int? = 42,
		claimsTimedOut: Bool = false,
		sdkConfig: AttributionOutputSdkConfig? = .fixture()
	) -> AttributionOutput {
		AttributionOutput(
			completeAttributionResponse: attributionResponse,
			retargetingParameters: retargetingParameters,
			testGroup: testGroup,
			claimsTimedOut: claimsTimedOut,
			sdkConfig: sdkConfig
		)
	}

	static let fixtureDict: [String: Any] = [
		"adsetId": "adsetId",
		"channelName": "channel_name",
		"type": "type",
		"userType": "userType",
		"version": 3,
		"sourceBundleId": "sourceBundleId",
		"networkName": "partner_name",
		"installId": "b410a130-b2b5-472b-8e46-449f5450a4f3",
		"campaignName": "campaign_name",
		"redownload": true,
		"channelIncent": true,
		"channelId": 41,
		"userId": "a410a130-b2b5-472b-8e46-449f5450a4f3",
		"createdAt": "1970-01-01T00:00:41Z",
		"testGroup": 42,
		"campaignId": 41,
		"campaignOrganic": true,
		"campaignType": "campaign_type",
		"sourcePlacement": "sourcePlacement",
		"networkId": 42,
		"sourceId": "sourceId",
		"sdkConfig": try! JSONEncoder().encode(AttributionOutputSdkConfig.fixture()),
	]
}

extension AttributionOutput: @retroactive Equatable {
	public static func == (lhs: AttributionOutput, rhs: AttributionOutput) -> Bool {
		lhs.completeAttributionResponse.installId == rhs.completeAttributionResponse.installId
			&& lhs.attributionResponse.userType == rhs.attributionResponse.userType && lhs.attributionResponse.isRedownload == rhs.attributionResponse.isRedownload
			&& lhs.attributionResponse.campaign == rhs.attributionResponse.campaign && lhs.attributionResponse.type == rhs.attributionResponse.type
			&& lhs.attributionResponse.channel == rhs.attributionResponse.channel && lhs.attributionResponse.partner == rhs.attributionResponse.partner
			&& lhs.attributionResponse.sourceId == rhs.attributionResponse.sourceId && lhs.attributionResponse.sourceBundleId == rhs.attributionResponse.sourceBundleId
			&& lhs.attributionResponse.sourcePlacement == rhs.attributionResponse.sourcePlacement && lhs.attributionResponse.adsetId == rhs.attributionResponse.adsetId
			&& lhs.attributionResponse.createdAt == rhs.attributionResponse.createdAt && lhs.retargetingParameters?.wasAlreadyInstalled == rhs.retargetingParameters?.wasAlreadyInstalled
			&& lhs.retargetingParameters?.url == rhs.retargetingParameters?.url && lhs.retargetingParameters?.parameters == rhs.retargetingParameters?.parameters
			&& lhs.testGroup == rhs.testGroup && lhs.claimsTimedOut == rhs.claimsTimedOut && lhs.sdkConfig == rhs.sdkConfig
	}
}

extension Campaign: @retroactive Equatable {
	public static func == (lhs: Campaign, rhs: Campaign) -> Bool {
		lhs.id == rhs.id && lhs.name == rhs.name && lhs.type == rhs.type && lhs.isOrganic == rhs.isOrganic
	}
}

extension Channel: @retroactive Equatable {
	public static func == (lhs: Channel, rhs: Channel) -> Bool {
		lhs.id == rhs.id && lhs.name == rhs.name && lhs.isIncent == rhs.isIncent
	}
}

extension Partner: @retroactive Equatable {
	public static func == (lhs: Partner, rhs: Partner) -> Bool {
		lhs.id == rhs.id && lhs.name == rhs.name
	}
}

extension AttributionResponseImpl {
	static func fixture(
		userId: StringID = StringID(value: "A410A130-B2B5-472B-8E46-449F5450A4F3")!,
		installId: StringID = StringID(value: "B410A130-B2B5-472B-8E46-449F5450A4F3")!,
		userType: String = "userType",
		redownload: Bool = true,
		campaign: Campaign = Campaign(
			id: 41,
			name: "campaign_name",
			type: "campaign_type",
			organic: true
		),
		type: String = "type",
		channel: Channel = Channel(
			id: 41,
			name: "channel_name",
			incent: true
		),
		partner: Partner = Partner(
			id: 42,
			name: "partner_name"
		),
		sourceId: String? = "sourceId",
		sourceBundleId: String? = "sourceBundleId",
		sourcePlacement: String? = "sourcePlacement",
		adsetId: String? = "adsetId",
		createdAt: Date = Date.init(timeIntervalSince1970: 41)
	) -> AttributionResponseImpl {
		AttributionResponseImpl(
			userId: userId,
			installId: installId,
			userType: userType,
			redownload: redownload,
			campaign: campaign,
			type: type,
			channel: channel,
			partner: partner,
			sourceId: sourceId,
			sourceBundleId: sourceBundleId,
			sourcePlacement: sourcePlacement,
			adsetId: adsetId,
			createdAt: createdAt
		)
	}
}

extension RetargetingParametersImpl {
	static func fixture(
		wasAlreadyInstalled: Bool = true,
		url: URL? = URL(string: "https://justtrack.io"),
		parameters: [String: String] = [:]
	) -> RetargetingParametersImpl {
		RetargetingParametersImpl(
			wasAlreadyInstalled: wasAlreadyInstalled,
			url: url,
			parameters: parameters
		)
	}
}
