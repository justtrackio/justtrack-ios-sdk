import StoreKit

/// Protocol defining the interface for building the justtrack SDK configuration.
public protocol SDKBuilder {
	/// Sets the bundle identifier of your application.
	///
	/// This allows the application developer to set their application bundle identifier that the SDK will associate with.
	/// By default, the SDK will fetch the bundle identifier of the application automatically.
	///
	/// - Parameter bundleId: The bundle identifier to be associated with the SDK.
	/// - Returns: The builder for method chaining.
	func set(bundleId: String) -> Self
	/// Sets the application version.
	///
	/// This allows the application developer to set a custom application version that the SDK will use.
	/// By default, the SDK will fetch the version from the application's Info.plist automatically.
	///
	/// - Parameters:
	///   - versionName: The version name (e.g., marketing version like "1.0.0").
	///   - versionCode: The version code (e.g., build number like "1").
	/// - Returns: The builder for method chaining.
	func set(applicationVersion versionName: String, versionCode: String) -> Self
	/// Sets a custom logger for the SDK.
	/// - Parameter logger: The logger implementation to use.
	/// - Returns: The builder for method chaining.
	func set(logger: Logger) -> Self
	/// Sets tracking ID and provider for the SDK.
	/// - Parameters:
	///   - trackingId: The tracking identifier.
	///   - trackingProvider: The tracking provider name.
	/// - Returns: The builder for method chaining.
	/// - Throws: Error if the values are invalid.
	func set(trackingId: String, trackingProvider: String) throws -> Self
	/// Sets a custom user ID.
	/// - Parameter userId: The user identifier.
	/// - Returns: The builder for method chaining.
	/// - Throws: Error if the user ID is invalid.
	func set(userId: String) throws -> Self
	/// Sets the Firebase App Instance ID.
	/// - Parameter firebaseAppInstanceId: The Firebase App Instance ID.
	/// - Returns: The builder for method chaining.
	func set(firebaseAppInstanceId: String) -> Self
	/// Sets the ODM (On Device Measurement) info from Google Ads.
	/// - Parameter odmInfo: The ODM info string.
	/// - Returns: The builder for method chaining.
	func set(odmInfo: String) -> Self
	/// Sets the inactivity time frame in hours.
	/// - Parameter inactivityTimeFrameHours: The number of hours of inactivity.
	/// - Returns: The builder for method chaining.
	func set(inactivityTimeFrameHours: Int) -> Self
	/// Sets the re-attribution time frame in days.
	/// - Parameter reAttributionTimeFrameDays: The number of days for re-attribution.
	/// - Returns: The builder for method chaining.
	func set(reAttributionTimeFrameDays: Int) -> Self
	/// Sets the delay before re-fetching re-attribution in seconds.
	/// - Parameter reFetchReAttributionDelaySeconds: The delay in seconds.
	/// - Returns: The builder for method chaining.
	func set(reFetchReAttributionDelaySeconds: Int) -> Self
	/// Sets the delay between attribution retry attempts in seconds.
	/// - Parameter attributionRetryDelaySeconds: The delay in seconds.
	/// - Returns: The builder for method chaining.
	func set(attributionRetryDelaySeconds: Int) -> Self
	/// Enables or disables automatic in-app purchase tracking.
	/// - Parameter automaticInAppPurchaseTracking: Whether to automatically track in-app purchases.
	/// - Returns: The builder for method chaining.
	func set(automaticInAppPurchaseTracking: Bool) -> Self
	/// Sets the platform type for the SDK.
	/// - Parameter platformType: The platform type.
	/// - Returns: The builder for method chaining.
	func set(platformType: PlatformType) -> Self
	/// Sets whether the SDK should be manually started.
	/// - Parameter manualStart: Whether to require manual start.
	/// - Returns: The builder for method chaining.
	func set(manualStart: Bool) -> Self
	/// Sets whether the SDK should print its logs in the console.
	/// - Parameter isLoggingEnabled: Whether the SDK should print its logs in the console.
	/// - Returns: The builder for method chaining.
	func set(isLoggingEnabled: Bool) -> Self
	/// Set the server URL for the SDK to query.
	/// - Parameter serverUrl: The server URL with scheme. e.g. https://justtrack.io
	/// - Returns: The builder for method chaining.
	func set(serverUrl: String) throws -> Self
	/// Create a new instance of the justtrack SDK. This method can only be called from the main thread.
	func build() throws -> JustTrackSdk
}

/// Implementation of SDKBuilder for configuring the justtrack SDK.
public class JustTrackSdkBuilder: SDKBuilder {
	private var logger: Logger?
	private let apiToken: String
	private var attributionSettings: AttributionSettings
	private var automaticInAppPurchaseTracking: Bool
	private var platformType: PlatformType
	private var clientId = Bundle.main.bundleIdentifier ?? ""
	private var applicationVersion: AppVersion = readAppVersion()
	private var adTrackingEventPublisher: AdTrackingEventPublishing?
	private var manualStart = false
	private var config: JustTrackSdkConfig = .default
	private var databaseName: String?
	private var firebaseAppInstanceId: String?
	private var odmInfo: String?
	private var isConsoleLoggingEnabled: Bool = false
	private var serverUrl: URL?

	/// Initializes a new SDK builder with an API token.
	/// - Parameter apiToken: The API token for the justtrack SDK.
	public init(
		apiToken: String
	) {
		self.apiToken = apiToken
		self.attributionSettings = AttributionSettings()
		self.automaticInAppPurchaseTracking = true
		self.platformType = .native
	}

	convenience init(
		apiToken: String,
		clientId: String,
		adTrackingEventPublisher: AdTrackingEventPublishing? = nil,
		databaseName: String = StringID().value
	) {
		self.init(apiToken: apiToken)
		self.clientId = clientId
		self.adTrackingEventPublisher = adTrackingEventPublisher
		self.databaseName = databaseName
	}

	/// Sets the bundle identifier of your application.
	///
	/// This allows the application developer to set their application bundle identifier that the SDK will associate with.
	/// By default, the SDK will fetch the bundle identifier of the application automatically.
	///
	/// - Parameter bundleId: The bundle identifier to be associated with the SDK.
	/// - Returns: The builder for method chaining.
	public func set(bundleId: String) -> Self {
		self.clientId = bundleId

		return self
	}

	/// Sets the application version.
	///
	/// This allows the application developer to set a custom application version that the SDK will use.
	/// By default, the SDK will fetch the version from the application's Info.plist automatically.
	///
	/// - Parameters:
	///   - versionName: The version name (e.g., marketing version like "1.0.0").
	///   - versionCode: The version code (e.g., build number like "1").
	/// - Returns: The builder for method chaining.
	public func set(applicationVersion versionName: String, versionCode: String) -> Self {
		self.applicationVersion = AppVersionImpl(code: versionCode, name: versionName)

		return self
	}

	/// Sets a custom logger for the SDK.
	/// - Parameter logger: The logger implementation to use.
	/// - Returns: The builder for method chaining.
	public func set(logger: Logger) -> Self {
		self.logger = logger

		return self
	}

	/// Sets tracking ID and provider for the SDK.
	/// - Parameters:
	///   - trackingId: The tracking identifier.
	///   - trackingProvider: The tracking provider name.
	/// - Returns: The builder for method chaining.
	/// - Throws: Error if the values are invalid.
	public func set(trackingId: String, trackingProvider: String) throws -> Self {
		config.trackingInfo = try JustTrackSdkConfig.TrackingInfo(id: trackingId, provider: trackingProvider)

		return self
	}

	/// Sets a custom user ID.
	/// - Parameter userId: The user identifier.
	/// - Returns: The builder for method chaining.
	/// - Throws: Error if the user ID is invalid.
	public func set(userId: String) throws -> Self {
		try config.set(userId: userId)

		return self
	}

	/// Sets the Firebase App Instance ID.
	/// - Parameter firebaseAppInstanceId: The Firebase App Instance ID.
	/// - Returns: The builder for method chaining.
	public func set(firebaseAppInstanceId: String) -> Self {
		self.firebaseAppInstanceId = firebaseAppInstanceId

		return self
	}

	/// Sets the ODM (On Device Measurement) info from Google Ads.
	/// - Parameter odmInfo: The ODM info string.
	/// - Returns: The builder for method chaining.
	public func set(odmInfo: String) -> Self {
		self.odmInfo = odmInfo

		return self
	}

	/// Sets the inactivity time frame in hours.
	/// - Parameter inactivityTimeFrameHours: The number of hours of inactivity.
	/// - Returns: The builder for method chaining.
	public func set(inactivityTimeFrameHours: Int) -> Self {
		self.attributionSettings.inactivityTimeFrameHours = inactivityTimeFrameHours

		return self
	}

	/// Sets the re-attribution time frame in days.
	/// - Parameter reAttributionTimeFrameDays: The number of days for re-attribution.
	/// - Returns: The builder for method chaining.
	public func set(reAttributionTimeFrameDays: Int) -> Self {
		self.attributionSettings.reAttributionTimeFrameDays = reAttributionTimeFrameDays

		return self
	}

	/// Sets the delay before re-fetching re-attribution in seconds.
	/// - Parameter reFetchReAttributionDelaySeconds: The delay in seconds.
	/// - Returns: The builder for method chaining.
	public func set(reFetchReAttributionDelaySeconds: Int) -> Self {
		self.attributionSettings.reFetchReAttributionDelaySeconds = reFetchReAttributionDelaySeconds

		return self
	}

	/// Sets the delay between attribution retry attempts in seconds.
	/// - Parameter attributionRetryDelaySeconds: The delay in seconds.
	/// - Returns: The builder for method chaining.
	public func set(attributionRetryDelaySeconds: Int) -> Self {
		self.attributionSettings.attributionRetryDelaySeconds = attributionRetryDelaySeconds

		return self
	}

	/// Enables or disables automatic in-app purchase tracking.
	/// - Parameter automaticInAppPurchaseTracking: Whether to automatically track in-app purchases.
	/// - Returns: The builder for method chaining.
	public func set(automaticInAppPurchaseTracking: Bool) -> Self {
		self.automaticInAppPurchaseTracking = automaticInAppPurchaseTracking

		return self
	}

	/// Sets the platform type for the SDK.
	/// - Parameter platformType: The platform type.
	/// - Returns: The builder for method chaining.
	public func set(platformType: PlatformType) -> Self {
		self.platformType = platformType

		return self
	}

	/// Sets whether the SDK should be manually started.
	/// - Parameter manualStart: Whether to require manual start.
	/// - Returns: The builder for method chaining.
	public func set(manualStart: Bool) -> Self {
		self.manualStart = manualStart

		return self
	}

	/// Sets whether the SDK should print its logs in the console.
	/// - Parameter isLoggingEnabled: Whether the SDK should print its logs in the console.
	/// - Returns: The builder for method chaining.
	public func set(isLoggingEnabled: Bool) -> Self {
		self.isConsoleLoggingEnabled = isLoggingEnabled

		return self
	}

	/// Set the server URL for the SDK to query.
	/// - Parameter serverUrl: The server URL with scheme. e.g. https://justtrack.io
	/// - Returns: The builder for method chaining.
	public func set(serverUrl: String) throws -> Self {
		guard let url = URL(string: serverUrl) else {
			throw URLError(.badURL)
		}

		self.serverUrl = url
		return self
	}

	/// Create a new instance of the justtrack SDK. This method can only be called from the main thread.
	/// - Returns: A configured JustTrackSdk instance.
	/// - Throws: Error if configuration is invalid or not on main thread.
	public func build() throws -> JustTrackSdk {
		return try JustTrack.provideInstance(self)
	}

	func createSdk() throws -> JustTrackSdkImpl {
		return try JustTrackSdkImpl(
			platformType: platformType,
			prefixedApiToken: apiToken,
			attributionSettings: attributionSettings,
			logger: logger,
			skAdNetwork: {
				if #available(iOS 11.3, *) {
					return SKAdNetwork.self
				}
				return nil
			}(),
			clientId: clientId,
			applicationVersion: applicationVersion,
			adTrackingEventPublisher: adTrackingEventPublisher,
			sqliteDriver: {
				guard let databaseName else { return nil }
				return try DefaultSqliteDriver(databaseName: databaseName)
			}(),
			config: config,
			manualStart: manualStart,
			isConsoleLoggingEnabled: logger == nil ? isConsoleLoggingEnabled : false,
			serverUrl: serverUrl
		)
	}

	func configure(sdk: JustTrackSdkImpl) {
		if automaticInAppPurchaseTracking {
			sdk.set(automaticInAppPurchaseTracking: true)
		}

		if let firebaseAppInstanceId {
			_ = sdk.set(firebaseAppInstanceId: firebaseAppInstanceId)
		}

		if let odmInfo {
			_ = sdk.set(odmInfo: odmInfo)
		}
	}
}

struct AttributionSettings {
	var inactivityTimeFrameHours: Int
	var reAttributionTimeFrameDays: Int
	var reFetchReAttributionDelaySeconds: Int
	var attributionRetryDelaySeconds: Int

	init() {
		self.inactivityTimeFrameHours = 48
		self.reAttributionTimeFrameDays = 14
		self.reFetchReAttributionDelaySeconds = 5
		self.attributionRetryDelaySeconds = 120
	}
}
