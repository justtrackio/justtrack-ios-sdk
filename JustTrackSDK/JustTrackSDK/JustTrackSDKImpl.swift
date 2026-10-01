import AdServices
import AppTrackingTransparency
import StoreKit

#if DEBUG
	import Darwin
#endif

final class JustTrackSdkImpl: JustTrackSdk, AppDelegateWatcherReportee, AdIdsProvider, EventPublisher, AdTrackingEventPublisherObserver {

	private static let attributionDurationMetric = Metric(metric: "AttributionDuration", unit: .seconds)

	var attribution: Future<AttributionResponse> {
		TransformingFuture(getAttributionOutput(forcedDecision: nil), { $0.attributionResponse }).toFuture()
	}

	var completeAttribution: Future<CompleteAttributionResponse> {
		TransformingFuture(getAttributionOutput(forcedDecision: nil), { $0.completeAttributionResponse }).toFuture()
	}

	var retargetingParameters: Future<RetargetingParameters?> {
		TransformingFuture(getAttributionOutput(forcedDecision: nil), { $0.retargetingParameters }).toFuture()
	}

	var preliminaryRetargetingParameters: PreliminaryRetargetingParameters? {
		preliminaryRetargetingParametersImpl
	}

	let appVersionAtInstall: AppVersion

	var sdkVersion: any Version {
		currentSdkVersion()
	}

	let remoteConfig: JusttrackRemoteConfig

	private let logger: HttpLogger
	private let bundleId: String
	private let platformType: PlatformType
	private let applicationVersion: AppVersion
	private var installId: StringID
	private let adTrackingProvider: AdTrackingProvider
	private var trackingId: String?
	private var trackingProvider: String?
	private var attributionOutput: Future<AttributionOutput>?
	private var attributionCanRetryAt: Date?
	private var preliminaryRetargetingParametersImpl: PreliminaryRetargetingParametersImpl?
	private let appVersionUpdateInfo: AppVersionUpdateInfo
	private var firebaseAppInstanceId: String?
	private var odmInfo: String?
	private var gbraid: String?
	private let httpClient: HttpClient
	private let attributionApi: AttributionApi
	private let privacyApi: PrivacyApi
	private let eventApi: EventApi
	private let logApi: LogApi
	private let userPropertyApi: UserPropertyApi
	private let remoteConfigApi: RemoteConfigApi
	private let periodicLogsPublisher: PeriodicLogsPublisher
	private let claimsProvider: ClaimsProvider
	private let store: Store
	private weak var adIdsProviderWrapper: AdIdsProviderWrapper?
	private var adTrackingEventPublisher: AdTrackingEventPublishing?
	private var sessionManager: SessionManager?
	private var userEventQueue: PublishEventsQueue?
	// last install id of a successful (!) attribution. don't just read the install id from the store if it isn't a full attribution
	private var lastInstallId: StringID?
	private let attributionSubscriptions: SubscriptionManager<AttributionResponse>
	private let retargetingParamsSubscriptions: SubscriptionManager<RetargetingParameters>
	private let preliminaryRetargetingParamsSubscriptions: SubscriptionManager<PreliminaryRetargetingParameters>
	private let reAttributionDecider: ReAttributionDecider
	private let reFetchReAttributionDelay: TimeInterval
	private let attributionRetryDelay: TimeInterval
	private var connectivityManager: ConnectivityManager?
	private let delegateWatcher: AppDelegateWatcher
	private var purchaseTracker: InAppPurchaseTracker
	private var inAppPurchaseHandler: InAppPurchaseHandler?
	private var getAdIdsResult: FutureImpl<AdIds>
	private var needsToGetIdfa = true
	private let crashReporter: CrashReporter
	private let anrDetector: AnrDetector
	private let sqliteDriver: SqliteDriver
	private let logAggregator: LogAggregator
	private var config: JustTrackSdkConfig?
	private var pendingAdapters: [(JusttrackAdapter, FutureImpl<Void>)] = []

	private let customUserIdStore = PendingIdStore(key: PendingIdStoreKey.customUserIdKey)
	private let firebaseAppInstanceIdStore = PendingIdStore(key: PendingIdStoreKey.firebaseAppInstanceIdKey)
	private var isStarted = false
	private let enableConnectionTracking: Bool
	private let globalDimensionsStore = GlobalDimensionsStore()

	/*
	 We do not support multiple calls of the start() method yet. Once we implement such support, we will remove this property.
	 */
	private var hasAlreadyBeenStarted = false

	convenience init(
		platformType: PlatformType,
		prefixedApiToken: String,
		attributionSettings: AttributionSettings,
		logger: Logger? = nil,
		httpClient: HttpClient? = nil,
		skAdNetwork: SkAdNetwork.Type?,
		clientId: String = Bundle.main.bundleIdentifier ?? "",
		applicationVersion: AppVersion = readAppVersion(),
		adTrackingEventPublisher: AdTrackingEventPublishing?,
		sqliteDriver: SqliteDriver? = nil,
		config: JustTrackSdkConfig? = nil,
		manualStart: Bool = false,
		enableConnectionTracking: Bool = false,
		isConsoleLoggingEnabled: Bool = true,
		serverUrl: URL? = nil
	) throws {
		let environmentSettings = EnvironmentSettings(
			prefixedApiToken: prefixedApiToken,
			serverUrl: serverUrl
		)

		let httpClientImpl = HttpClientImpl(
			retryConfig: RetryConfig.defaultConfig,
			urlSession: URLSession.shared,
			isConsoleLoggingEnabled: isConsoleLoggingEnabled
		)

		let httpClient: HttpClient = httpClient ?? httpClientImpl
		let requestFactory: RequestFactory = RequestFactoryImpl(
			environment: environmentSettings.environment,
			platformType: platformType,
			appVersion: applicationVersion.name,
			apiToken: environmentSettings.apiToken,
			clientId: clientId
		)
		let retryConfig = httpClientImpl.retryConfig

		let attributionApi: AttributionApi = AttributionApiImpl(httpClient: httpClient, requestFactory: requestFactory, retryConfig: retryConfig)
		let privacyApi: PrivacyApi = PrivacyApiImpl(httpClient: httpClient, requestFactory: requestFactory)
		let logApi: LogApi = LogApiImpl(httpClient: httpClient, requestFactory: requestFactory)
		let userPropertyApi: UserPropertyApi = UserPropertyApiImpl(httpClient: httpClient, requestFactory: requestFactory)
		let remoteConfigApi: RemoteConfigApi = RemoteConfigApiImpl(httpClient: httpClient, requestFactory: requestFactory)

		var loggers = [Logger]()
		if let logger {
			loggers.append(logger)
		}
		if isConsoleLoggingEnabled {
			loggers.append(LoggerImpl())
		}

		let logger = CompositeLogger(loggers: loggers)

		let eventApi: EventApi = EventApiImpl(httpClient: httpClient, requestFactory: requestFactory, retryConfig: retryConfig, logger: logger)

		try self.init(
			attributionSettings: attributionSettings,
			logger: logger,
			httpClient: httpClient,
			attributionApi: attributionApi,
			privacyApi: privacyApi,
			eventApi: eventApi,
			logApi: logApi,
			userPropertyApi: userPropertyApi,
			remoteConfigApi: remoteConfigApi,
			platformType: platformType,
			sessionManagerBuilder: { sdk in
				SessionManagerImpl(sdk)
			},
			connectivityManagerBuilder: { _ in
				do {
					return try ConnectivityManagerImpl()
				} catch {
					logger.error("Failed to initialize connectivity manager: \(error.justTrackGetErrorDescription())")
					return nil
				}
			},
			adTrackingProvider: AdTrackingProviderImpl.instance,
			skAdNetwork: skAdNetwork,
			bundleId: clientId,
			applicationVersion: applicationVersion,
			adTrackingEventPublisher: adTrackingEventPublisher ?? AdTrackingEventPublisher.shared,
			sqliteDriver: try sqliteDriver ?? DefaultSqliteDriver(),
			config: config ?? .default,
			manualStart: manualStart,
			enableConnectionTracking: enableConnectionTracking,
			isConsoleLoggingEnabled: isConsoleLoggingEnabled
		)
	}

	init(
		attributionSettings: AttributionSettings,
		logger: Logger,
		httpClient: HttpClient,
		attributionApi: AttributionApi,
		privacyApi: PrivacyApi,
		eventApi: EventApi,
		logApi: LogApi,
		userPropertyApi: UserPropertyApi,
		remoteConfigApi: RemoteConfigApi,
		platformType: PlatformType = .native,
		sessionManagerBuilder: (_ sdk: JustTrackSdkImpl) -> SessionManager,
		connectivityManagerBuilder: (_ sdk: JustTrackSdkImpl) -> ConnectivityManager?,
		adTrackingProvider: AdTrackingProvider,
		skAdNetwork: SkAdNetwork.Type?,
		claimsProvider: ClaimsProvider? = nil,
		crashReporter: CrashReporter = DefaultCrashReporter.shared,
		logAggregator: LogAggregator? = nil,
		bundleId: String? = nil,
		applicationVersion: AppVersion = readAppVersion(),
		adTrackingEventPublisher: AdTrackingEventPublishing,
		sqliteDriver: SqliteDriver,
		config: JustTrackSdkConfig,
		manualStart: Bool,
		enableConnectionTracking: Bool = false,
		isConsoleLoggingEnabled: Bool = true
	) throws {
		guard let resolvedBundleId = bundleId ?? Bundle.main.bundleIdentifier else {
			throw JustTrackError.missingBundleIdentifier
		}
		guard Thread.isMainThread else {
			throw JustTrackError.notOnMainThread
		}

		if !UserDefaults.standard.bool(forKey: Store.postbackConversionValueSetKey) {
			if #available(iOS 15.4, *) {
				skAdNetwork?.updatePostbackConversionValue(0, completionHandler: nil)
			} else if #available(iOS 11.3, *) {
				skAdNetwork?.registerAppForAdNetworkAttribution()
			}
		}

		self.bundleId = resolvedBundleId
		self.platformType = platformType
		self.applicationVersion = applicationVersion
		self.store = Store()
		self.appVersionUpdateInfo = self.store.getAppVersionUpdateInfo(currentVersion: applicationVersion)
		self.appVersionAtInstall = self.store.readAppVersionAtInstall(currentVersion: applicationVersion)
		self.store.setFirstSdkInitTimestamp(Date())
		self.reAttributionDecider = ChainedReAttributionDecider(
			ResolveOrganicAttributionDecider(),
			TimeBasedReAttributionDecider(inactivityTimeFrameHours: attributionSettings.inactivityTimeFrameHours, reAttributionTimeFrameDays: attributionSettings.reAttributionTimeFrameDays)
		)
		self.reFetchReAttributionDelay = TimeInterval(attributionSettings.reFetchReAttributionDelaySeconds)
		self.attributionRetryDelay = TimeInterval(attributionSettings.attributionRetryDelaySeconds)
		self.installId = store.getInstallId()
		self.adTrackingProvider = adTrackingProvider
		self.httpClient = httpClient
		self.attributionApi = attributionApi
		self.privacyApi = privacyApi
		self.eventApi = eventApi
		self.logApi = logApi
		self.userPropertyApi = userPropertyApi
		self.remoteConfigApi = remoteConfigApi
		let getAdIdsResult = FutureImpl<AdIds>()
		self.getAdIdsResult = getAdIdsResult
		let adIdsProviderWrapper = AdIdsProviderWrapper()
		self.logAggregator = logAggregator ?? LogAggregatorImpl(sqliteDriver: sqliteDriver, isConsoleLoggingEnabled: isConsoleLoggingEnabled)
		let httpLogger = HttpLoggerImpl(
			fallback: logger,
			logApi: logApi,
			logAggregator: self.logAggregator,
			installId: installId,
			adIdsProvider: adIdsProviderWrapper.provideAdIds,
			appVersionProvider: { applicationVersion }
		)
		self.adTrackingEventPublisher = adTrackingEventPublisher
		self.adIdsProviderWrapper = adIdsProviderWrapper
		self.logger = httpLogger
		self.adTrackingProvider.setLogger(self.logger)
		let currentInstallId = self.installId
		let store = self.store
		self.remoteConfig = RemoteConfigImpl(
			remoteConfigApi: remoteConfigApi,
			logger: httpLogger,
			sdkVersion: currentSdkVersion(),
			appVersion: applicationVersion,
			getInstallId: { currentInstallId },
			getAdIds: { getAdIdsResult.toFuture() },
			getDeviceInfo: { [adTrackingProvider] in DeviceInfo(idfvProvider: adTrackingProvider) },
			getAttributionTimestamp: { store.getAttributionTimestamps()?.firstAttributedAt },
			getFirstSdkInitTimestamp: { store.getFirstSdkInitTimestamp() },
			getInstallTimestamp: {
				guard let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
					return nil
				}
				return (try? FileManager.default.attributesOfItem(atPath: documentsUrl.path)[.creationDate]) as? Date
			}
		)
		self.periodicLogsPublisher = PeriodicLogsPublisher(fallback: logger, httpLogger: self.logger)
		self.claimsProvider = claimsProvider ?? ClaimsProviderImpl(logger: self.logger)
		self.attributionCanRetryAt = nil
		self.attributionSubscriptions = SubscriptionManager()
		self.retargetingParamsSubscriptions = SubscriptionManager()
		self.preliminaryRetargetingParamsSubscriptions = SubscriptionManager()
		self.preliminaryRetargetingParametersImpl = nil
		self.delegateWatcher = AppDelegateWatcher()
		self.purchaseTracker = InAppPurchaseTrackerImpl(logger: self.logger)
		self.crashReporter = crashReporter
		if #available(iOS 14, *) {
			self.anrDetector = MetricKitAnrDetector(logger: self.logger)
		} else {
			self.anrDetector = DefaultAnrDetector(logger: self.logger)
		}
		self.sqliteDriver = sqliteDriver
		self.enableConnectionTracking = enableConnectionTracking
		self.connectivityManager = connectivityManagerBuilder(self)
		self.userEventQueue = PublishEventsQueue(
			connectivityManager: self.connectivityManager,
			logger: httpLogger,
			publisher: self,
			sequenceNumberProvider: UserDefaultsSequenceNumberProvider(),
			sqliteDriver: sqliteDriver
		)
		self.sessionManager = sessionManagerBuilder(self)
		self.inAppPurchaseHandler = InAppPurchaseHandler(sdk: self, logger: self.logger)
		self.config = config

		httpLogger.sdkIsRunning = { [weak self] in
			self?.isRunning() ?? false
		}
		(self.remoteConfig as? RemoteConfigImpl)?.isRunning = { [weak self] in
			self?.isRunning() ?? false
		}

		anrDetector.setHandler { [weak self, weak anrDetector] report in
			guard let self else {
				anrDetector?.removeHandler()
				return
			}
			self.logger.error("App is unresponsive! \(report.errorFields.getFields())")
		}

		if !manualStart {
			start()
		}

		#if DEBUG
			sdkBridge = SdkBridge(
				sdk: self,
				httpLogger: self.logger,
				getAdIdsResult: getAdIdsResult
			)
		#endif
	}

	func anonymize() -> Future<Void> {
		guard isRunning() else {
			return FutureImpl().reject(JustTrackError.stopped)
		}
		let result = FutureImpl<Void>()
		getAdIds().observe { [privacyApi] adIdsResult in
			switch adIdsResult {
			case let .failure(error):
				result.reject(error)
			case let .success(adIds):
				let deviceInfo = DeviceInfo(idfvProvider: self.adTrackingProvider)
				let request = DTOAnonymizeRequest(
					installInstanceId: self.installId,
					deviceId: adIds.idfa,
					idfv: deviceInfo.idfv
				)
				let userData = UserData(
					idfa: adIds.idfa,
					userId: adIds.userId,
					installId: self.installId
				)
				privacyApi.sendAnonymizeRequest(request: request, userData: userData).observe { anonymizeResult in
					switch anonymizeResult {
					case let .failure(error):
						result.reject(error)
					case .success:
						result.resolve(Void())
					}
				}
			}
		}
		return result.toFuture()
	}

	func isRunning() -> Bool {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }
		return isStarted
	}

	func register(attributionListener listener: @escaping (AttributionResponse) -> Void) -> Subscription {
		return attributionSubscriptions.subscribe(listener: listener)
	}

	func register(retargetingParametersListener listener: @escaping (RetargetingParameters) -> Void) -> Subscription {
		return retargetingParamsSubscriptions.subscribe(listener: listener)
	}

	func register(preliminaryRetargetingParametersListener listener: @escaping (PreliminaryRetargetingParameters) -> Void) -> Subscription {
		return preliminaryRetargetingParamsSubscriptions.subscribe(listener: listener)
	}

	func shutdown() {
		moveToBackground()
		sessionManager = nil
		delegateWatcher.uninstall()
		periodicLogsPublisher.stop()
		userEventQueue?.shutdown()
		connectivityManager?.shutdown()
		connectivityManager = nil
		crashReporter.stopMonitoring()
	}

	func set(userId customUserId: String) -> Future<Void> {
		if !isValid(customUserId: customUserId) {
			let error = InvalidFieldError(name: "customUserId", value: customUserId, minLength: 1, maxLength: 4096, encoding: "ASCII")
			logger.warn("Not publishing invalid custom user id: \(error)")

			return FutureImpl().reject(error)
		}

		if !customUserIdStore.storeNewId(installId: lastInstallId, newId: customUserId) {
			let fields = LoggerFieldsImpl().with("customUserId", customUserId)
			logger.debug("Not publishing a custom user id twice", fields)

			return FutureImpl<Void>().resolve(Void())
		}

		return performCustomUserIdSend(customUserId, reason: "send")
	}

	func set(firebaseAppInstanceId: String) -> Future<Void> {
		if !isValid(firebaseAppInstanceId: firebaseAppInstanceId) {
			let error = InvalidFieldError(
				name: "firebaseAppInstanceId",
				value: firebaseAppInstanceId,
				minLength: 8,
				maxLength: 256,
				encoding: "ASCII"
			)
			logger.warn("Not publishing invalid Firebase app instance id: \(error)")

			return FutureImpl().reject(error)
		}

		self.firebaseAppInstanceId = firebaseAppInstanceId

		if !firebaseAppInstanceIdStore.storeNewId(installId: lastInstallId, newId: firebaseAppInstanceId) {
			let fields = LoggerFieldsImpl().with("firebaseAppInstanceId", firebaseAppInstanceId)
			logger.debug("Not publishing Firebase app instance id twice", fields)

			return FutureImpl<Void>().resolve(Void())
		}

		return performFirebaseAppInstanceIdSend(firebaseAppInstanceId, reason: "send")
	}

	private func performFirebaseAppInstanceIdSend(_ firebaseAppInstanceId: String, reason: String) -> Future<Void> {
		let result = FutureImpl<Void>()
		let fields = LoggerFieldsImpl().with("firebaseAppInstanceId", firebaseAppInstanceId).with("reason", reason)

		getAdIds().observe { [weak self] adIdsResult in
			switch adIdsResult {
			case let .failure(error):
				self?.logger.info("Failed to get idfa", fields.with("exception", error))
				result.reject(error)
			case let .success(adIds):
				self?.performFirebaseAppInstanceIdSend(
					firebaseAppInstanceId: firebaseAppInstanceId,
					adIds: adIds,
					fields: fields,
					result: result
				)
			}
		}

		return result.toFuture()
	}

	private func performFirebaseAppInstanceIdSend(
		firebaseAppInstanceId: String,
		adIds: AdIds,
		fields: LoggerFieldsBuilder,
		result: FutureImpl<Void>
	) {
		if firebaseAppInstanceIdStore.getPendingId() == nil {
			_ = result.resolve(Void())
			return
		}

		logger.info("Publishing new Firebase app instance id", fields)
		let body = DTOPublishFirebaseAppInstanceIdRequest(uuid: adIds.userId.value, firebaseInstanceId: firebaseAppInstanceId)
		userPropertyApi.sendFirebaseAppInstanceId(
			request: body,
			userData: UserData(
				idfa: adIds.idfa,
				userId: adIds.userId,
				installId: installId
			)
		).observe { response in
			switch response {
			case .failure(let error):
				self.logger.warn("Failed to publish new Firebase app instance id", fields.with("exception", error))
				_ = result.reject(error)
			case .success:
				self.firebaseAppInstanceIdStore.setStoredAtBackend(installId: self.installId, storedId: firebaseAppInstanceId)
				_ = result.resolve(Void())
			}
		}
	}

	func set(odmInfo: String) -> Future<Void> {
		let fields = LoggerFieldsImpl().with("odmInfo", odmInfo)

		if self.odmInfo == odmInfo {
			logger.debug("Not publishing ODM info twice", fields)
			return FutureImpl<Void>().resolve(Void())
		}

		self.odmInfo = odmInfo
		logger.info("Setting new ODM info, triggering re-attribution", fields)

		return TransformingFuture(getAttributionOutput(forcedDecision: .fetchAttributionAfterGettingIdfa)) { _ in
			Void()
		}.toFuture()
	}

	func handle(deeplink url: URL) {
		logger.debug("Handling deeplink URL", LoggerFieldsImpl().with("url", url.absoluteString))

		if let gbraid = GoogleDeeplinkHandler.handle(url: url) {
			if self.gbraid == gbraid {
				logger.debug("Not setting gbraid twice", LoggerFieldsImpl().with("gbraid", gbraid))
				return
			}

			self.gbraid = gbraid
			_ = getAttributionOutput(forcedDecision: .fetchAttributionAfterGettingIdfa)
		}
	}

	func set(automaticInAppPurchaseTracking: Bool) {
		self.purchaseTracker.set(enabled: automaticInAppPurchaseTracking)
	}

	func start() {
		start(config: config)
	}

	func start(config: JustTrackSdkConfig?) {
		objc_sync_enter(self)
		guard !isStarted else {
			objc_sync_exit(self)
			return
		}
		guard !hasAlreadyBeenStarted else {
			isStarted = true
			objc_sync_exit(self)
			logger.getFallback().warn(
				"The justtrack SDK does not currently support multiple starts with different configurations. The SDK has been started again, but it continues to use the previously set configuration.",
				LoggerFieldsImpl()
			)
			return
		}
		isStarted = true
		hasAlreadyBeenStarted = true
		objc_sync_exit(self)

		let config = config ?? .default
		self.config = config

		if let userId = config.userId {
			_ = set(userId: userId)
		}

		if let trackingInfo = config.trackingInfo {
			trackingId = trackingInfo.id
			trackingProvider = trackingInfo.provider
		}

		for (adapter, promise) in pendingAdapters {
			adapter.integrate(sdk: self, logger: logger).observe { result in
				switch result {
				case let .failure(error):
					promise.reject(error)
				case .success:
					promise.resolve(())
				}
			}
		}
		pendingAdapters.removeAll()

		self.sessionManager?.start()
		purchaseTracker.start(handler: inAppPurchaseHandler)
		delegateWatcher.reportee = self
		_ = self.connectivityManager?.registerOnReconnect(self.onReconnect)
		self.lastInstallId = getCachedAttribution()?.installId
		adIdsProviderWrapper?.adIdsProvider = self

		JustTrack.setSdk(self)
		retrySendCustomUserId(reason: "app start")
		retrySendFirebaseAppInstanceId(reason: "app start")
		#if DEBUG
			self.logger.debug("Initializing SDK with version \(sdkVersion.name)", LoggerFieldsImpl())
		#endif

		_ = getAttributionOutput(forcedDecision: nil)

		// We set the observer to get the most relevant ATT authorization status.
		//
		// Once we set an observer, the publisher notifies the observer of the current ATT status via the methods of the `AdTrackingEventPublisherObserver` protocol.
		adTrackingEventPublisher?.set(observer: self)

		crashReporter.checkJsReport { [weak self] result in
			guard let self else { return }
			switch result {
			case let .success(report):
				let fields = LoggerFieldsImpl()
					.with("message", report.message)
					.with("stack_trace", report.stackTrace)
					.with("timestamp", formatDateMilliseconds(report.timestamp))
				self.logger.publishMetric(Metric(metric: "crash"), 1, fields)
				self.logger.error("A JS crash report received", fields)
			case let .failure(error):
				self.logger.error(
					"An error during retrieving a JS crash report received",
					LoggerFieldsImpl()
						.with("description", error.justTrackGetErrorDescription())
				)
			}
		}

		crashReporter.checkNativeCrashReport { [weak self] result in
			guard let self else { return }
			switch result {
			case let .success(report):
				switch report.reportType {
				case .exception:
					let exceptionReport = CrashReport.ExceptionReport(
						name: report.name,
						reason: report.reason,
						callStack: report.callStack
					)
					self.logger.publishMetric(
						Metric(metric: "crash"),
						1,
						exceptionReport.metricFields
					)
					self.logger.error(
						"Application shutdown due to crash at \(report.timestamp)",
						exceptionReport.generateErrorFields(breadcrumbs: self.logAggregator.getBreadcrumbs())
					)
				case .signal:
					let signalInfo = report.signalInfo.map { storedInfo in
						CrashReport.SignalReport.Info(
							errorNumber: storedInfo.errorNumber,
							signalCode: storedInfo.signalCode,
							signalNumber: storedInfo.signalNumber,
							sendingProcess: storedInfo.sendingProcess,
							senderRuid: storedInfo.senderRuid,
							exitValue: storedInfo.exitValue,
							signalValue: storedInfo.signalValue,
							faultingAddress: storedInfo.faultingAddress
						)
					}
					let signalReport = CrashReport.SignalReport(
						name: report.name,
						callStack: report.callStack,
						info: signalInfo
					)
					self.logger.publishMetric(
						Metric(metric: "crash"),
						1,
						LoggerFieldsImpl()
							.with("signal_name", signalReport.name)
					)
					self.logger.error(
						"Application shutdown due to crash at \(report.timestamp)",
						signalReport.generateErrorFields(breadcrumbs: self.logAggregator.getBreadcrumbs())
					)
				}
			case let .failure(error):
				self.logger.error(
					"An error during retrieving a native crash report received",
					LoggerFieldsImpl()
						.with("description", error.justTrackGetErrorDescription())
				)
			}
		}

		crashReporter.startMonitoring()
	}

	func stop() {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		isStarted = false
	}

	@available(*, deprecated, renamed: "track")
	@discardableResult
	func publish(event: AppEvent) -> Future<Void> {
		track(event: event)
	}

	@discardableResult
	func track(event: AppEvent) -> Future<Void> {
		guard isRunning() else {
			return FutureImpl().reject(JustTrackError.stopped)
		}

		guard let sessionManager else {
			return FutureImpl().reject(SdkShutdownError())
		}

		let builder = event

		if enableConnectionTracking {
			let currentConnectionType = connectivityManager?.connectionType ?? .unknown
			let dimensionValue = currentConnectionType == .offline ? "offline" : "online"
			_ = builder.add(dimension: .jtConnectionType, value: dimensionValue)
		}

		do {
			try builder.validate()
		} catch {
			logger.warn("Not publishing invalid user event: \(error)")

			return FutureImpl().reject(error)
		}

		// Inject global dimensions after validation so they don't count against maxDimensionSize.
		// Only add if the event doesn't already have a value for that dimension (user-set takes precedence).
		let globalDimensions = globalDimensionsStore.getAll()
		let existingDimensions = builder.getDimensions()
		for (key, value) in globalDimensions where existingDimensions[key] == nil {
			_ = builder.add(dimension: key, value: value)
		}

		let buildEvent = builder.build(sessionId: sessionManager.getLastSessionId(self))
		sessionManager.saveSession()

		return getUserEventQueue().publishEvent(event: buildEvent)
	}

	@discardableResult
	func forward(adImpression: AdImpression) -> Future<Void> {
		let result = FutureImpl<Void>()

		guard isRunning() else {
			return result.reject(JustTrackError.stopped)
		}

		return forward(adImpression: adImpression, extraDimensions: [:])
	}

	func getInstallInstanceId() -> Future<String> {
		guard isRunning() else {
			return FutureImpl().reject(JustTrackError.stopped)
		}
		return FutureImpl().resolve(installId.value)
	}

	func getAdvertiserIdInfo() -> Future<AdvertiserIdInfo> {
		guard isRunning() else {
			return FutureImpl().reject(JustTrackError.stopped)
		}
		return TransformingFuture(getAdIds()) { adIds in
			AdvertisingIdInfoImpl(advertiserId: adIds.idfa?.value)
		}.toFuture()
	}

	func setExperimentVariant(experiment: String, variant: String, tags: [String], happenedAt: Date?) -> Future<Void> {
		guard isRunning() else {
			return FutureImpl().reject(JustTrackError.stopped)
		}

		guard experiment.count > 0 && experiment.count <= 256 && experiment.isASCII else {
			let error = InvalidFieldError(name: "experiment", value: experiment, minLength: 1, maxLength: 256, encoding: "ASCII")
			logger.warn("Not setting experiment variant with invalid experiment: \(error)")
			return FutureImpl().reject(error)
		}
		guard variant.count > 0 && variant.count <= 256 && variant.isASCII else {
			let error = InvalidFieldError(name: "variant", value: variant, minLength: 1, maxLength: 256, encoding: "ASCII")
			logger.warn("Not setting experiment variant with invalid variant: \(error)")
			return FutureImpl().reject(error)
		}

		guard tags.count <= 5 else {
			let error = JustTrackError.custom("Invalid tags: array exceeds maximum of 5 elements (provided: \(tags.count))")
			logger.warn("Not setting experiment variant with too many tags: \(error)")
			return FutureImpl().reject(error)
		}

		for (index, tag) in tags.enumerated() {
			guard tag.count > 0 && tag.count <= 64 && tag.isASCII else {
				let error = InvalidFieldError(name: "tags[\(index)]", value: tag, minLength: 1, maxLength: 64, encoding: "ASCII")
				logger.warn("Not setting experiment variant with invalid tag: \(error)")
				return FutureImpl().reject(error)
			}
		}

		let request = DTOSetExperimentVariantRequest(
			installId: installId,
			sdkVersion: sdkVersion,
			appVersion: appVersionAtInstall,
			osVersion: DeviceInfo(idfvProvider: adTrackingProvider).osVersion,
			experiment: experiment,
			variant: variant,
			tags: tags,
			happenedAt: happenedAt
		)

		let fields = LoggerFieldsImpl()
			.with("experiment", experiment)
			.with("variant", variant)
			.with("tags", tags.joined(separator: ","))

		logger.info("Sending experiment variant assignment", fields)

		let result = FutureImpl<Void>()

		getAdIds().observe { [weak self] adIdsResult in
			guard let self else {
				result.reject(JustTrackError.custom("SDK instance deallocated"))
				return
			}

			switch adIdsResult {
			case let .failure(error):
				self.logger.warn("Failed to get ad ids for experiment variant assignment", fields.with("error", error))
				result.reject(error)

			case let .success(adIds):
				self.remoteConfigApi.sendSetExperimentVariant(
					request: request,
					userData: UserData(
						idfa: adIds.idfa,
						userId: adIds.userId,
						installId: self.installId
					)
				).observe { response in
					switch response {
					case let .failure(error):
						self.logger.warn("Failed to send experiment variant assignment", fields.with("error", error))
						result.reject(error)
					case .success:
						self.logger.info("Successfully sent experiment variant assignment", fields)
						result.resolve(Void())
					}
				}
			}
		}

		return result.toFuture()
	}

	@available(iOS 15.0, *)
	@discardableResult
	func forward(transaction: Transaction) -> Result<Void, Error> {
		guard isRunning() else {
			return .failure(JustTrackError.stopped)
		}
		inAppPurchaseHandler?.reportOnTransactionId(
			transaction.id,
			productId: transaction.productID,
			quantity: transaction.purchasedQuantity
		)
		return .success(Void())
	}

	@available(iOS 15.0, *)
	@discardableResult
	func forward(transactionId: String, productId: String, quantity: Int) -> Result<Void, Error> {
		guard isRunning() else {
			return .failure(JustTrackError.stopped)
		}
		guard let transactionId = UInt64(transactionId) else {
			return .failure(JustTrackError.custom("Wrong transactionId"))
		}
		inAppPurchaseHandler?.reportOnTransactionId(transactionId, productId: productId, quantity: quantity)
		return .success(Void())
	}

	@discardableResult
	func integrate(with adapter: JusttrackAdapter) -> Future<Void> {
		if isRunning() {
			return adapter.integrate(sdk: self, logger: logger)
		}

		let promise = FutureImpl<Void>()
		pendingAdapters.append((adapter, promise))
		return promise.toFuture()
	}

	func set(globalDimension0 value: String?) {
		setGlobalDimension(.jtGlobal0, value: value)
	}

	func set(globalDimension1 value: String?) {
		setGlobalDimension(.jtGlobal1, value: value)
	}

	func set(globalDimension2 value: String?) {
		setGlobalDimension(.jtGlobal2, value: value)
	}

	private func setGlobalDimension(_ dimension: Dimension, value: String?) {
		if !globalDimensionsStore.set(dimension: dimension, value: value), let value {
			logger.warn("Ignoring invalid global dimension value for '\(dimension.rawValue)': '\(value)'. It needs to be shorter than 4096 characters and only include ISO 8859-1 characters.")
		}
	}

	func getUserEventQueue() -> PublishEventsQueue {
		guard let userEventQueue = userEventQueue else {
			// should normally not happen, but if it happens, just setup the queue and use it
			let userEventQueue = PublishEventsQueue(
				connectivityManager: self.connectivityManager,
				logger: logger,
				publisher: self,
				sequenceNumberProvider: UserDefaultsSequenceNumberProvider(),
				sqliteDriver: sqliteDriver
			)
			self.userEventQueue = userEventQueue

			return userEventQueue
		}

		return userEventQueue
	}

	func publishEventBatch(batch: PublishingBatch) -> Future<Void> {
		let result = FutureImpl<Void>()

		getAdIds().observe { [weak self] adIdsResult in
			switch adIdsResult {
			case let .failure(error):
				self?.logger.info("Failed to get idfa", LoggerFieldsImpl().with("exception", error))

			case let .success(adIds):
				self?.publishEventBatch(batch: batch, adIds: adIds, result: result)
			}
		}

		return result.toFuture()
	}

	private func publishEventBatch(
		batch: PublishingBatch,
		adIds: AdIds,
		result: FutureImpl<Void>
	) {
		attribution.observe { [weak self] attribution in
			guard let self else { return }

			switch attribution {
			case let .failure(error):
				self.logger.debug("Not publishing events batch, attribution failed", LoggerFieldsImpl().with("exception", error))
				_ = result.reject(error)

			case .success:
				let events = PublishableUserEvent.build(
					batch: batch,
					idfa: adIds.idfa?.value,
					userId: adIds.userId,
					installId: self.installId,
					idfvProvider: self.adTrackingProvider,
					applicationVersion: self.applicationVersion,
					platformType: self.platformType
				)
				let request = self.eventApi.sendUserEvents(
					events: events,
					userData: UserData(
						idfa: adIds.idfa,
						userId: adIds.userId,
						installId: self.installId
					)
				)
				request.observe { eventResponse in
					switch eventResponse {
					case let .failure(error):
						self.logger.debug(
							"Publishing events in batch failed",
							LoggerFieldsImpl()
								.with("exception", error.justTrackGetErrorDescription())
						)
						_ = result.reject(error)
					case .success:
						#if DEBUG
							for event in batch.events {
								self.logger.getFallback().debug("Successfully published \(event.baseEvent()) at \(event.happenedAt()) in batch")
							}
						#endif
						_ = result.resolve(Void())
					}
				}
			}
		}
	}

	func spawnFetchClaimTask(ipProtocol: IPProtocol) -> Future<String> {
		let result = FutureImpl<String>()
		let connectionType = getNetworkType()
		let start = Date()

		getAdIds().observe { [weak self] adIdsResult in
			switch adIdsResult {
			case let .failure(error):
				self?.logger.info("Failed to get idfa", LoggerFieldsImpl().with("exception", error))

			case let .success(adIds):
				self?.spawnFetchClaimTask(ipProtocol: ipProtocol, adIds: adIds, connectionType: connectionType, start: start, result: result)
			}
		}

		return result.toFuture()
	}

	private func spawnFetchClaimTask(
		ipProtocol: IPProtocol,
		adIds: AdIds,
		connectionType: ConnectionType,
		start: Date,
		result: FutureImpl<String>
	) {
		attributionApi.getSignedIpClaim(
			ipProtocol: ipProtocol,
			userData: UserData(
				idfa: adIds.idfa,
				userId: adIds.userId,
				installId: installId
			)
		).observe { response in
			switch response {
			case .failure(let error):
				_ = result.reject(error)
			case .success(let responseData):
				do {
					let response = try DTOSignIPResponse(data: responseData)
					let timeTaken = Date().timeIntervalSince(start)
					let dimensions = LoggerFieldsImpl().with("Network", connectionType.stringValue)
					self.logger.publishMetric(ipProtocol.claimDurationMetric, timeTaken, dimensions)
					self.logger.debug("Got IP claim", LoggerFieldsImpl().with("ip", response.ip).with("type", response.type))
					_ = result.resolve(response.token)
				} catch {
					_ = result.reject(error)
				}
			}
		}
	}

	func notifyAppStart(_ event: AppStateEvent) {
		guard let sessionManager = sessionManager else { return }
		let sessionId = sessionManager.getLastSessionId(self)
		let duration = event.startingTook
		let happenedAt = event.startedAt
		_ = track(event: JtAppOpenEvent(sessionId: sessionId, duration: duration, unit: .milliseconds, happenedAt: happenedAt))
		switch appVersionUpdateInfo.kind {
		case .installedApp:
			_ = track(event: JtAppInstallEvent(sessionId: sessionId, duration: duration, unit: .milliseconds, happenedAt: happenedAt))
		case .updatedApp:
			let previousVersion = appVersionUpdateInfo.lastAppVersion.name
			logger.info("App was updated", LoggerFieldsImpl().with("previous_app_version_code", previousVersion))
		case .noChange:
			// no change
			break
		}
	}

	func moveToForeground() {
		sessionManager?.moveToForeground()
		periodicLogsPublisher.start()
	}

	func moveToBackground() {
		sessionManager?.moveToBackground()
		periodicLogsPublisher.pause()
		logAggregator.moveToBackground()
		userEventQueue?.moveToBackground()
	}

	func applicationWillTerminate() {
		sessionManager?.saveSession()
		shutdown()
	}

	func getAdIds() -> Future<AdIds> {
		return getAdIdsResult.toFuture()
	}

	private func attributionIsOldFail() -> Bool {
		guard let attributionCanRetryAt = attributionCanRetryAt else {
			return false
		}

		return attributionCanRetryAt < Date()
	}

	private func getAttributionOutput(forcedDecision: AttributionDecision?) -> Future<AttributionOutput> {
		guard isRunning() else {
			return FutureImpl().reject(JustTrackError.stopped)
		}

		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		if forcedDecision == nil {
			if let response = attributionOutput {
				if attributionIsOldFail() {
					attributionCanRetryAt = nil
					attributionOutput = nil
					logger.debug("Retrying old failed attribution")
				} else {
					return response
				}
			}
		}

		let attributionTimestamps = store.getAttributionTimestamps()
		// after getting the last timestamps we can write into the store our open timestamp so we know the
		// next time whether the user opened the app not for quite some time
		store.setLastOpen()

		let attributionDecision = forcedDecision ?? reAttributionDecider.needsReAttribution(attributionTimestamps: attributionTimestamps)
		let storedOutput = store.getStoredOutput()

		if !attributionDecision.shouldFetchAttribution {
			if let storedOutput {
				let storedResponse = storedOutput.attributionResponse
				let attributionOutput = FutureImpl(storedOutput).toFuture()
				self.attributionOutput = attributionOutput
				logger.debug("Using cached attribution")
				attributionSubscriptions.call(value: storedResponse)
				return attributionOutput
			}
		}

		let attributionStart = Date()
		let connectionType = getNetworkType()
		let attributionOutputPromise = FutureImpl<AttributionOutput>()
		let attributionOutput = attributionOutputPromise.toFuture()
		self.attributionOutput = attributionOutput

		getAdIds().observe { [weak self] adIdsResult in
			switch adIdsResult {
			case let .failure(error):
				self?.logger.info("Failed to get idfa", LoggerFieldsImpl().with("exception", error))

			case let .success(adIds):
				self?.getAttributionOutput(
					forcedDecision: forcedDecision,
					adIds: adIds,
					attributionDecision: attributionDecision,
					attributionOutputPromise: attributionOutputPromise,
					attributionOutput: attributionOutput,
					attributionStart: attributionStart,
					connectionType: connectionType,
					attributionTimestamps: attributionTimestamps,
					storedOutput: storedOutput
				)
			}
		}

		return attributionOutput
	}

	private func getAttributionOutput(
		forcedDecision: AttributionDecision?,
		adIds: AdIds,
		attributionDecision: AttributionDecision,
		attributionOutputPromise: FutureImpl<AttributionOutput>,
		attributionOutput: Future<AttributionOutput>,
		attributionStart: Date,
		connectionType: ConnectionType,
		attributionTimestamps: AttributionTimestamps?,
		storedOutput: AttributionOutput?
	) {
		let deviceInfo = DeviceInfo(idfvProvider: adTrackingProvider)
		let user = DTOAttributionRequestUser(
			userId: adIds.userId,
			installInstanceId: installId,
			idfv: deviceInfo.idfv,
			idfa: adIds.idfa,
			hasLimitedAdTracking: adIds.idfa == nil,
			trackingId: trackingId,
			trackingProvider: trackingProvider,
			countryIso: getCurrentCountry()
		)
		let device = DTOAttributionRequestDevice(
			name: deviceInfo.name,
			model: deviceInfo.model,
			product: deviceInfo.product,
			type: deviceInfo.type,
			os: DTOAttributionRequestDeviceOS(version: deviceInfo.osVersion, name: deviceInfo.osName),
			display: DTOAttributionRequestDeviceDisplay(width: deviceInfo.displayWidth, height: deviceInfo.displayHeight)
		)
		claimsProvider.refreshClaims(sdk: self)
		claimsProvider.provideClaims(timeout: attributionDecision.getClaimsTimeout()) { (claims, didTimeOut) in
			var parameters: [String: String] = [:]

			// for some reason, the following hangs in the simulator. We don't really need it there anyway.
			#if !targetEnvironment(simulator)
				if #available(iOS 14.3, *) {
					do {
						let token = try AAAttribution.attributionToken()
						parameters["appleSearchAdsToken"] = token
					} catch {
						self.logger.warn("Failed to lookup apple search ads token", LoggerFieldsImpl().with("error", error))
					}
				}
			#endif

			if let odmInfo = self.odmInfo {
				parameters["odmInfo"] = odmInfo
			}

			if let gbraid = self.gbraid {
				parameters["gbraid"] = gbraid
			}

			let request = DTOAttributionRequest(
				appVersion: DTOAppVersion(self.applicationVersion),
				sdkVersion: DTOSdkVersion(currentSdkVersion()),
				user: user,
				device: device,
				claims: claims,
				parameters: parameters
			)
			self.attributionApi.sendAttributionRequest(
				request: request,
				userData: UserData(idfa: adIds.idfa, userId: adIds.userId, installId: self.installId)
			).observe { result in
				switch result {
				case .failure(let error):
					_ = attributionOutputPromise.reject(error)
				case .success(let responseData):
					do {
						let response = try DTOAttributionResponse(userId: adIds.userId, data: responseData, wasAlreadyInstalled: false)

						objc_sync_enter(self)
						self.installId = response.installId
						let output = AttributionOutput(
							completeAttributionResponse: response,
							retargetingParameters: response.retargetingParameters,
							claimsTimedOut: didTimeOut
						)
						self.store.storeAttribution(attribution: output)
						objc_sync_exit(self)

						_ = attributionOutputPromise.resolve(output)
					} catch {
						_ = attributionOutputPromise.reject(error)
					}
				}
			}
		}

		attributionOutput.observe { result in
			switch result {
			case .failure(let error):
				switch RetryingFuture<Data>.classifyError(error: error, errorClassifier: AttributionErrorClassifier()) {
				case .recoverable(let waitTime):
					// retry only after at least the wait time is over
					self.attributionCanRetryAt = Date(timeIntervalSinceNow: max(self.attributionRetryDelay, waitTime))
				case .retryDefault:
					self.attributionCanRetryAt = Date(timeIntervalSinceNow: self.attributionRetryDelay)
				case .unrecoverable:
					// use an hour as "infinity" - if the app is still running after 1h, we can take the hit, if not, we don't leave the chance
					// that something lingers in memory and the next time we run we can't handle this
					self.attributionCanRetryAt = Date(timeIntervalSinceNow: 3600)
				}
				self.logger.warn("Failed to get attribution", LoggerFieldsImpl().with("exception", error))
			case .success(let response):
				self.logger.set(installId: response.completeAttributionResponse.installId)
				let attributionDuration = Date().timeIntervalSince(attributionStart)
				let networkDimension = LoggerFieldsImpl().with("Network", connectionType.stringValue)
				self.logger.publishMetric(Self.attributionDurationMetric, attributionDuration, networkDimension)
				self.onAttributionDone(response)

				self.attributionCanRetryAt = nil
				if let attributionTimestamps {
					if !attributionDecision.shouldFetchAttribution {
						self.logger.info("Attribution was not needed, but was not cached")
					} else {
						let attributionAge = attributionTimestamps.lastAttributedAt.timeIntervalSince(attributionTimestamps.firstAttributedAt)
						let now = Date()
						let sinceLastOpen = now.timeIntervalSince(attributionTimestamps.lastOpenAt)
						let sinceLastAttribution = now.timeIntervalSince(attributionTimestamps.lastAttributedAt)
						let fields = LoggerFieldsImpl()
							.with("attributionAge", attributionAge)
							.with("sinceLastOpen", sinceLastOpen)
							.with("sinceLastAttribution", sinceLastAttribution)
							.with("force", forcedDecision != nil)
						self.logger.debug("Attribution was fetched again because re-attribution was needed", fields)
					}
				} else {
					self.logger.debug("Fetched first attribution")
				}
				self.attributionSubscriptions.call(value: response.attributionResponse)
				self.callRetargetingParametersSubscriptions(retargetingParameters: response.retargetingParameters)

				let needsClaimRefetch = response.attributionResponse.campaign.isOrganic && response.claimsTimedOut && attributionDecision.isFastClaimsTimeout()
				let needsReAttribution =
					attributionDecision.isFetchRetargetingAttribution()
					&& self.hasOldInstallId(
						storedResponse: storedOutput?.completeAttributionResponse,
						newResponse: response
					) && self.reFetchReAttributionDelay > 0

				// check if we expected a re-attribution and did not get one
				if needsReAttribution {
					self.fetchAttributionAgainAfter(
						message: needsClaimRefetch
							? "Fetching attribution again (with longer claims timeout) because the retargeting delay expired and previously the attribution did not change"
							: "Fetching attribution again because the retargeting delay expired and previously the attribution did not change",
						forcedDecision: needsClaimRefetch
							? AttributionDecision.fetchRetargetingAttributionDelayed.withSlowClaimsTimeout()
							: AttributionDecision.fetchRetargetingAttributionDelayed,
						delay: self.reFetchReAttributionDelay
					)
				} else {
					if let preliminaryRetargetingParametersImpl = self.preliminaryRetargetingParametersImpl {
						_ = preliminaryRetargetingParametersImpl.resolve(response)
					}
					if needsClaimRefetch {
						self.fetchAttributionAgainAfter(
							message: "Fetching attribution again with longer timeout while waiting for claims",
							forcedDecision: AttributionDecision.fetchFirstAttribution.withSlowClaimsTimeout(),
							delay: 3  // we don't really need to wait for a long time before trying again
						)
					}
				}
			}
		}
	}

	private func hasOldInstallId(storedResponse: CompleteAttributionResponse?, newResponse: AttributionOutput) -> Bool {
		guard let storedResponse = storedResponse else {
			return true
		}

		return storedResponse.installId == newResponse.completeAttributionResponse.installId
	}

	private func onAttributionDone(_ output: AttributionOutput) {
		let installId = output.completeAttributionResponse.installId

		objc_sync_enter(self)
		if installId == lastInstallId {
			objc_sync_exit(self)

			return
		}

		lastInstallId = installId
		objc_sync_exit(self)

		onInstallIdChange(installId)
	}

	private func onInstallIdChange(_ installId: StringID) {
		if let customUserId = customUserIdStore.getPendingWithNewInstallId(installId: installId) {
			_ = performCustomUserIdSend(customUserId, reason: "installId changed")
		}
		if let firebaseAppInstanceId = firebaseAppInstanceIdStore.getPendingWithNewInstallId(installId: installId) {
			_ = performFirebaseAppInstanceIdSend(firebaseAppInstanceId, reason: "installId changed")
		}
	}

	private func fetchAttributionAgainAfter(message: String, forcedDecision: AttributionDecision, delay: TimeInterval) {
		DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
			self.logger.info(message)
			_ = self.getAttributionOutput(forcedDecision: forcedDecision)
		}
	}

	private func onReconnect() {
		self.retryAttributionAfterReconnect()
		self.retrySendCustomUserId(reason: "reconnect")
		self.retrySendFirebaseAppInstanceId(reason: "reconnect")
	}

	private func retryAttributionAfterReconnect() {
		guard attributionCanRetryAt != nil else { return }
		attributionOutput = nil
		attributionCanRetryAt = nil
		logger.info("Fetching attribution again as it failed and we got a new network connection")
		_ = getAttributionOutput(forcedDecision: AttributionDecision.fetchFirstAttribution)
	}

	private func retrySendCustomUserId(reason: String) {
		guard let pendingCustomUserId = customUserIdStore.getPendingId() else { return }
		_ = performCustomUserIdSend(pendingCustomUserId, reason: reason)
	}

	private func retrySendFirebaseAppInstanceId(reason: String) {
		guard let pendingFirebaseAppInstanceId = firebaseAppInstanceIdStore.getPendingId() else { return }
		_ = performFirebaseAppInstanceIdSend(pendingFirebaseAppInstanceId, reason: reason)
	}

	private func callRetargetingParametersSubscriptions(retargetingParameters: RetargetingParameters?) {
		guard let retargetingParameters = retargetingParameters else { return }

		retargetingParamsSubscriptions.call(value: retargetingParameters)
	}

	private func getCachedAttribution() -> CompleteAttributionResponse? {
		return store.getStoredOutput()?.completeAttributionResponse
	}

	private func performCustomUserIdSend(_ customUserId: String, reason: String) -> Future<Void> {
		let result = FutureImpl<Void>()
		let fields = LoggerFieldsImpl().with("customUserId", customUserId).with("reason", reason)

		getAdIds().observe { [weak self] adIdsResult in
			switch adIdsResult {
			case let .failure(error):
				self?.logger.info("Failed to get idfa", fields.with("exception", error))

			case let .success(adIds):
				self?.performCustomUserIdSend(
					customUserId: customUserId,
					adIds: adIds,
					fields: fields,
					result: result
				)
			}
		}

		return result.toFuture()
	}

	private func performCustomUserIdSend(
		customUserId: String,
		adIds: AdIds,
		fields: LoggerFieldsBuilder,
		result: FutureImpl<Void>
	) {
		completeAttribution.observe { [weak self] attribution in
			guard let self else { return }

			switch attribution {
			case .failure(let error):
				self.logger.warn("Failed to publish custom user id", fields.with("exception", error))
				_ = result.reject(error)

			case .success(let response):
				if let existingRequest = RunningCustomUserIdRequests.offer(
					installId: response.installId,
					customUserId: customUserId,
					future: result.toFuture()
				) {
					existingRequest.observe { existingRequestResult in
						_ = result.fulfill(existingRequestResult)
					}
					return
				}

				// ensure we didn't already finish publishing the user id at this point
				if customUserIdStore.getPendingId() == nil {
					_ = result.resolve(Void())
					return
				}

				self.logger.info("Publishing new custom user id", fields)
				let body = DTOPublishCustomUserIdRequest(installId: self.installId.value, customUserId: customUserId)
				self.userPropertyApi.sendCustomUserId(
					request: body,
					userData: UserData(
						idfa: adIds.idfa,
						userId: adIds.userId,
						installId: self.installId
					)
				).observe { customUserIdResponse in
					switch customUserIdResponse {
					case .failure(let error):
						self.logger.warn("Failed to publish custom user id", fields.with("exception", error))
						_ = result.reject(error)
					case .success:
						self.customUserIdStore.setStoredAtBackend(installId: self.installId, storedId: customUserId)
						_ = result.resolve(Void())
					}
				}
			}
		}
	}

	private func forward(adImpression: AdImpression, extraDimensions: [String: String]) -> Future<Void> {
		let result = FutureImpl<Void>()

		if let revenue = adImpression.revenue, revenue.value < 0 {
			logger.warn(
				"Negative revenue for AdFormat",
				LoggerFieldsImpl()
					.with("adUnit", adImpression.unit)
					.with("revenue", revenue.value)
					.with("currency", revenue.currency)
			)

			return result.reject(JustTrackError.custom("Negative revenue for AdFormat"))
		}

		var event: AppEvent = JtAdInternalEvent(
			jtAction: "success",
			jtAdBundleId: adImpression.bundleId,
			jtAdInstanceName: adImpression.instanceName,
			jtAdNetwork: adImpression.network,
			jtAdPlacement: adImpression.placement,
			jtAdSdk: adImpression.sdkName,
			jtAdSegment: adImpression.segmentName,
			jtAdUnit: adImpression.unit,
			jtAdTestGroup: adImpression.testGroup,
			revenue: adImpression.revenue,
			happenedAt: Date()
		)

		for (k, v) in extraDimensions {
			event = event.add(dimension: k, value: v)
		}

		do {
			try event.validate()
		} catch {
			logger.warn(
				"Not publishing invalid ad impression: \(error)",
				LoggerFieldsImpl()
					.with("adUnit", adImpression.unit)
					.with("revenue", adImpression.revenue?.value ?? 0.0)
					.with("currency", adImpression.revenue?.currency ?? "USD")
			)

			return result.reject(JustTrackError.custom("Invalid ad impression"))
		}

		return track(event: event)
	}

	private func proceedWithTrackingAuthorizationRequest() {
		let idfa = adTrackingProvider.provideIDFA()
		let deviceInfo = DeviceInfo(idfvProvider: adTrackingProvider)
		let uniqueId = getUniqueId(advertiserId: idfa?.value ?? "", trackingId: trackingId ?? "", deviceId: deviceInfo.idfv?.value ?? "")
		let userId = store.getUserId(bundleId: bundleId, uniqueId: uniqueId)

		if needsToGetIdfa {
			needsToGetIdfa = false
			_ = getAdIdsResult.resolve(AdIds(idfa: idfa, userId: userId))

		} else if let attributionOutput, let idfa {
			if attributionOutput.isFulfilled {
				performAttributionAfterGettingIdfa(idfa: idfa, userId: userId)
			} else {
				attributionOutput.observe { [weak self] _ in
					self?.performAttributionAfterGettingIdfa(idfa: idfa, userId: userId)
				}
			}
		}
	}

	private func performAttributionAfterGettingIdfa(idfa: StringID?, userId: StringID) {
		let newGetAdIdsResult = FutureImpl<AdIds>(AdIds(idfa: idfa, userId: userId))
		self.getAdIdsResult = newGetAdIdsResult
		_ = self.getAttributionOutput(forcedDecision: .fetchAttributionAfterGettingIdfa)
	}

	func onFinishAdTrackingAuthorization() {
		proceedWithTrackingAuthorizationRequest()
	}

	func onPublishAdTrackingEvent(_ event: AppEvent) {
		_ = track(event: event)
	}
}
