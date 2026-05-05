import Foundation

/// Protocol representing an attribution response from the justtrack SDK.
public protocol AttributionResponse {
	/// The type of user.
	var userType: String { get }
	/// Indicates whether this is a redownload of the app.
	var isRedownload: Bool { get }
	/// The campaign associated with this attribution.
	var campaign: Campaign { get }
	/// The type of attribution.
	var type: String { get }
	/// The channel through which the attribution occurred.
	var channel: Channel { get }
	/// The partner associated with this attribution.
	var partner: Partner { get }
	/// The source identifier if available.
	var sourceId: String? { get }
	/// The bundle identifier of the source app if available.
	var sourceBundleId: String? { get }
	/// The placement within the source if available.
	var sourcePlacement: String? { get }
	/// The ad set identifier if available.
	var adsetId: String? { get }
	/// The date when the attribution was created.
	var createdAt: Date { get }
}

protocol CompleteAttributionResponse: AttributionResponse {
	var userId: StringID { get }
	var installId: StringID { get }
}

/// Represents a marketing campaign in the attribution system.
public struct Campaign {
	/// The unique identifier of the campaign.
	public let id: Int
	/// The name of the campaign.
	public let name: String
	/// The type of campaign.
	public let type: String
	/// Indicates whether this is an organic campaign.
	public let isOrganic: Bool

	/// Initializes a new Campaign.
	/// - Parameters:
	///   - id: The unique identifier of the campaign.
	///   - name: The name of the campaign.
	///   - type: The type of campaign.
	///   - organic: Whether this is an organic campaign.
	public init(id: Int, name: String, type: String, organic: Bool) {
		self.id = id
		self.name = name
		self.type = type
		self.isOrganic = organic
	}
}

/// Represents a channel through which attribution can occur.
public struct Channel {
	/// The unique identifier of the channel.
	public let id: Int
	/// The name of the channel.
	public let name: String
	/// Indicates whether this is an incentivized channel.
	public let isIncent: Bool

	/// Initializes a new Channel.
	/// - Parameters:
	///   - id: The unique identifier of the channel.
	///   - name: The name of the channel.
	///   - incent: Whether this is an incentivized channel.
	public init(id: Int, name: String, incent: Bool) {
		self.id = id
		self.name = name
		self.isIncent = incent
	}
}

/// Represents a partner in the attribution system.
public struct Partner {
	/// The unique identifier of the partner.
	public let id: Int
	/// The name of the partner.
	public let name: String

	/// Initializes a new Partner.
	/// - Parameters:
	///   - id: The unique identifier of the partner.
	///   - name: The name of the partner.
	public init(id: Int, name: String) {
		self.id = id
		self.name = name
	}
}

class AttributionResponseImpl: CompleteAttributionResponse {
	let userId: StringID
	let installId: StringID
	let userType: String
	let isRedownload: Bool
	let campaign: Campaign
	let type: String
	let channel: Channel
	let partner: Partner
	let sourceId: String?
	let sourceBundleId: String?
	let sourcePlacement: String?
	let adsetId: String?
	let createdAt: Date

	init(
		userId: StringID,
		installId: StringID,
		userType: String,
		redownload: Bool,
		campaign: Campaign,
		type: String,
		channel: Channel,
		partner: Partner,
		sourceId: String?,
		sourceBundleId: String?,
		sourcePlacement: String?,
		adsetId: String?,
		createdAt: Date
	) {
		self.userId = userId
		self.installId = installId
		self.userType = userType
		self.isRedownload = redownload
		self.campaign = campaign
		self.type = type
		self.channel = channel
		self.partner = partner
		self.sourceId = sourceId
		self.sourceBundleId = sourceBundleId
		self.sourcePlacement = sourcePlacement
		self.adsetId = adsetId
		self.createdAt = createdAt
	}
}
