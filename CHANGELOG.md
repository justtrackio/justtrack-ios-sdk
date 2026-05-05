# justtrack SDK Changelog

## Version 7.1.0 (Mar 06, 2026)

### Added

- Added `.set(isLoggingEnabled:)` to the SDK builder to control SDK logging.
- Added new predefined dimensions.
- Added `.set(bundleId:)` and `.set(applicationVersion:versionCode:)` to the SDK builder.
- Added `.set(serverUrl:)` to the SDK builder to configure a custom server URL.
- Added `Action` enum to `JtProgressionEvent`.
- Added `.track()` method for publishing events. `.publish(event:)` has been deprecated.
- Added remote config support with experiment assignments via the `remoteConfig` property.
- Added HTTP request logging to the console for debugging.

### Changed

- SDK logs are no longer printed to the console by default. Use `.set(isLoggingEnabled:)` on the builder to enable them.
- Migrated to tracking API v4.
- Replaced unnecessary error-level logs with warning and info levels.
- Added thread-safety guard (`dispatch_once`) to swizzling methods.

## Version 6.0.0 (Jan 22, 2026)

### Added

- Added support for third-party adapter SDKs (AppLovin, Firebase, IronSource, UnityAds).
- Added A/B test variant assignment support.
- Added callbacks to the publish event method.

### Changed

- `JustTrackSdk.forwardAdImpression()` now returns a Future.
- Updated public API for consistency between platforms.
- Increased minimum Xcode version to 16.0.

### Removed

- Removed built-in (autonomous) integration with AdColony.
- Removed built-in (autonomous) integration with Chartboost.
- Removed built-in (autonomous) integration with AppLovin.
- Removed built-in (autonomous) integration with Firebase.
- Removed built-in (autonomous) integration with IronSource.
- Removed built-in (autonomous) integration with UnityAds.
- Removed deprecated methods (`UserIdSource`, etc.).

## Version 5.0.1 (Jun 10, 2025)

### Bug-Fixes

- Fixed migration issue from 4.8.0 onward.

## Version 5.0.0 (May 13, 2025)

### Added

- Extended support for user data privacy by introducing new methods.

### Removed

- Removed `Recruiter` from `AttributionResponse`.
- Removed playtime calculation.
- Removed multiple predefined events.

### Changed

- All predefined event classes have been renamed, some have been removed or merged. See the latest predefined event page for more information.
- The `createAffiliateLink()` instance method of `JustTrackSdk` has been deprecated.
- The `getUserId()` instance method of `JustTrackSdk` has been renamed to `getJusttrackUserId()` and deprecated.
- The `set(customUserId: String)` instance method of `JustTrackSdk` has been renamed to `set(userId: String)`.
- The `getInstallId()` instance method of `JustTrackSdk` has been renamed to `getInstallInstanceId()`.
- The `network` instance property of `AttributionResponse` has been renamed to `partner`.
- The `format` instance property of `AdImpression` has been renamed to `unit`.

## Version 4.8.0 (Mar 19, 2025)

### Changed

- The ANR reports functionality has been temporary disabled because of a problem with getting stack traces in Sunday apps 

## Version 4.7.0 (Jan 22, 2025)

### Added

- StoreKit 2 support has been added.

## Version 4.6.1 (30th October 2024)

### Changed

- No change.

## Version 4.6.0 (22nd October 2024)

### Added

- Each user event now contains a field called `sequenceNumber`, which is an integer that represents the sequence number of the event.
- Breadcrumbs.
- Crash reports.

### Changed

- Switched to semantic versioning.

### Bug-Fixes

- Fixed the broken Applovin integration for `interstitial` and `rewarded`.

## Version 4.5.6 (18th July 2024)

### Bug-Fixes

- Added handling for scenarios where ATT is requested while the app is in inactive state.

## Version 4.5.5 (13th June 2024)

### Bug-Fixes

- Fixed attribution on iOS 17.4 and iOS 17.4.1

## Version 4.5.4 (31th May 2024)

### Changed

- The minimum supported iOS version was raised to iOS 12.

### Bug-Fixes

- A crash was fixed when integrating with AppLovin 12.x.

## Version 4.5.3 (29th April 2024)

### Added

- The SDK now contains a privacy manifest file.

## Version 4.5.2 (5th April 2024)

### Added

- The SDK is now available via Carthage and SPM as well.

### Changed

- The SDK now reads the IDFA automatically after the user accepts the ATT request even if this happens after the SDK has been initialized.
- The casing of enum variants has been unified to lowerCamelCase. All variants of the `Dimension` enum as well as some `AdFormat` variants have been affected.
- The `userId` and `advertiserIdInfo` properties have been replaced with async methods `getUserId()` and `getAdvertiserIdInfo()`.
- The `createAffiliateLink() -> String` and `createAffiliateLink(channel: String) throws -> String` methods have become asynchronous and now have the following signatures: `createAffiliateLink() -> Future<String>` and `createAffiliateLink(channel: String) -> Future<String>` respectively.

### Bug-Fixes

- The SDK no longer resets the SKAd conversion value after installing from SKAdNetwork v4 and higher ads.
- The timestamps on user events now carry the millisecond the event happened instead of just the second.

## Version 4.5.1 (5th February 2024)

### Bug-Fixes

- Removed the application delegate wrapper as it wasn't always forwarding calls correctly.

## Version 4.5.0 (12th December 2023)

### Changed

- The `UserEvent` classes have been changed such that you can now submit named custom dimensions instead of dimensions custom1/2/3.
- All predefined event classes have been renamed, some have been removed or merged. See the migration guide you received for more details.
- The JustTrackSDK can now only be initialized from the main thread. If you need to initialize it from another thread, use `DispatchQueue.main.sync` to move the call to the main thread.
- `JustTrackSdk.forwardAdImpression` now requires you to construct an `AdImpression` object instead of passing individual parameters.

## Version 4.4.1 (30th August 2023)

### Bug-Fixes

- Initializing the SDK multiple times no longer causes multiple instances running concurrently.

### Removed

- The `EventDetails` class has been removed, the event name is now just a single string.

## Version 4.4.0 (14th July 2023)

### Added

- `JustTrackSdk.userId` was added to retrieve a future for the justtrack user id.

### Changed

- The justtrack SDK now provides the user and test group id without waiting for the justtrack backend.
- `JustTrackSdk.attributeUser` was renamed to `JustTrackSdk.attribution` and is now a property.
- `JustTrackSdk.getRetargetingParameters` was renamed to `JustTrackSdk.retargetingParameters` and is now a property.
- `JustTrackSdk.getPreliminaryRetargetingParameters` was renamed to `JustTrackSdk.preliminaryRetargetingParameters` and is now a property.
- `JustTrackSdk.getAppVersionAtInstall` was renamed to `JustTrackSdk.attribution` and is now a property.
- `JustTrackSdk.getSdkVersion` was renamed to `JustTrackSdk.sdkVersion` and is now a property.
- `JustTrackSdk.getAdvertiserIdInfo` was renamed to `JustTrackSdk.advertiserIdInfo` and is now a property.
- `JustTrackSdk.getTestGroupId` was renamed to `JustTrackSdk.testGroupId` and is now a property.
- `JustTrackSdk.publishEvent` was renamed to `JustTrackSdk.publish(event:)`.
- `JustTrackSdk.registerAttributionListener` was renamed to `JustTrackSdk.register(attributionListener:)`.
- `JustTrackSdk.registerRetargetingParametersListener` was renamed to `JustTrackSdk.register(retargetingParametersListener:)`.
- `JustTrackSdk.registerPreliminaryRetargetingParametersListener` was renamed to `JustTrackSdk.register(preliminaryRetargetingParametersListener:)`.
- `JustTrackSdk.onDestroy` was renamed to `JustTrackSdk.shutdown`.
- `JustTrackSdk.getAffiliateLink` was renamed to `JustTrackSdk.createAffiliateLink(channel:)` and can now throw an error instead of returning a future which can fail. A version without a parameter that doesn't throw any errors was also added.
- `JustTrackSdk.publishFirebaseAppInstanceId` was renamed to `JustTrackSdk.set(firebaseAppInstanceId:)`.
- The `AdvertiserIdInfo` and `AttributionResponse` protocols now provide properties instead of getter methods.
- XCode 14.0 or newer is now required.

### Removed

- `JustTrackSdk.getCachedAttribution` was removed.

## Version 4.3.8 (29th March 2023)

### Added

- `JustTrack.getInstance` now returns the current SDK instance if one was already created.
- `set(automaticInAppPurchaseTracking: Bool)` was added to configure automatic in-app purchase tracking. It is enabled by default.

### Removed

- You can now no longer manually forward in-app purchases. Use the automatic integration instead.

## Version 4.3.7 (17th March 2023)

### Bug-Fixes

- Added support to integrate with AppLovin 10.x.
- Added support to integrate with Unity Ads 4.6.0.

## Version 4.3.6 (2nd March 2023)

### Added

- `forwardAdImpression` can now be called with an arbitrary string parameter instead of an `AdFormat`.
- `integrateWithAdColony` was added to automatically track ad impressions from AdColony.
- `integrateWithAppLovin` was added to automatically track ad impressions from AppLovin.
- `integrateWithChartboost` was added to automatically track ad impressions from Chartboost.
- `integrateWithUnityAds` was added to automatically track ad impressions from Unity Ads.

### Changed

- The `AdUnit` enum was renamed to `AdFormat` and the `.rewarded_video` value was renamed to `rewarded`. `.rewarded_interstitial`, `.native`, and `.app_open` have been added as new values, too.
- The `JustTrackSDKFirebase` and `JustTrackSDKIronsource` pods were merged into the `JustTrackSDK` pod.

### Bug-Fixes

- The correct device model is now reported to the justtrack backend, improving attribution precision.

## Version 4.3.5 (16th December 2022)

### Changed

- Forwarding in-app purchases no longer requires you to manually supply the receipt as token.

## Version 4.3.4 (2nd December 2022)

### Added

- The SDK now provides a method to track in-app purchases.

### Changed

- You can now attach a currency to the events you are sending.
- If you are forwarding ad impressions, you now have to specify the currency for the revenue of the event.

### Bug-Fixes

- The reported app version was fixed and now provides the name you specify instead of the version code only.
- The SDK no longer reports requesting the tracking permission multiple times if the method is called more than once.

## Version 4.3.3 (8th November 2022)

### Added

- The SDK now provides the token for Apple Search Ads to the backend.
- You can now provide a custom user id to the backend.
- The SDK is now available as a CocoaPod.

### Changed

- The SDK now imposes restrictions about the data you can send to the backend.
- The integration with Google Ads campaigns was improved.
- The native integration with IronSource was changed to allow specifying the user id source.

## Version 4.3.2 (4th August 2022)

### Changed

- The SDK now provides a method `forwardAdImpression` to report ad impressions to the justtrack backend.

## Version 4.3.1 (7th July 2022)

### Bug-Fixes

- The SDK now stores internal logs and metrics more carefully to avoid excessive memory usage.

## Version 4.3.0 (6th May 2022)

### Changed

- The SDK now handles timeouts while collecting information for a correct attribution better. This will make it more likely to receive an attribution event after the initial `Future` resolves should you have registered a listener.
- The test group id is now computed based on the IDFV instead of the IDFA.

## Version 4.2.9 (1st April 2022)

### Changed

- Renamed all occurrences of the Firebase instance id to Firebase app instance id. For example, `publishFirebaseInstanceId` is now called `publishFirebaseAppInstanceId`.

### Bug-Fixes

- The SDK now retrieves the Firebase app instance id instead of the Firebase (installation) instance id during integration.

## Version 4.2.8 (30th March 2022)

### Added

- The SDK can now retrieve the Firebase instance id of a user and send it to the justtrack backend.

## Version 4.2.6 (11th February 2022)

### Changed

- Improved attribution precision.

## Version 4.2.5 (17th December 2021)

### Added

- Added `JustTrack.requestTrackingAuthorization` to allow the user to opt in for tracking.

### Changed

- Improved the precision of the retrieved device model name.

## Version 4.2.4 (11th November 2021)

### Added

- The SDK now provides methods to get the advertiser id of the user and the test group id of the user.

### Changed

- The SDK now includes logic to retry fetching the attribution if it failed last time and some time has passed.

### Bug Fixes

- The SDK now sends session_app_open events correctly.

## Version 4.2.3 (25th August 2021)

### Changed

- The SDK now automatically handles a network reconnect when fetching an attribution.
- Improved the error messages when you try to use an invalid API token.
- The SDK will now automatically send the revenue value with user events generated from ad impressions to the backend.

## Version 4.2.2 (29th July 2021)

### Changed

- Increased version to align with unity version.
- Increased likelihood that events reach the backend if the user is only using the app for a short time.
- Added call to `SKAdNetwork.registerAppForAdNetworkAttribution`.

## Version 4.2.0 (23rd June 2021)

### Changed

- Events tracking the progress of a user for a level or quest have been extended to automatically track the progress of the user and provide the duration the app was active during that time upon completion.
- The session id is now included in all events sent to the backend.
- You now have to name the provider of the tracking id when initializing the SDK.

### Removed

- Removed `with(realTime:)` from all interfaces again as well as realTime event functionality.
- It is no longer possible to set the duration for progression events by hand.

## Version 4.1.0 (21st May 2021)

### Added

- Added `with(realTime:)` to user events to send events without any delay.
- Added `registerAttributionListener`, `registerRetargetingParametersListener`, and `registerPreliminaryRetargetingParametersListener` to the SDK as well as needed companion types.
- Added `getRetargetingParameters` and `getPreliminaryRetargetingParameters` to the SDK.

### Changed

- The implementation for standard events changed significantly. Each standard event now has an associated class and should be created via an instance of this class.
- Standard events now carry built-in dimensions next to the three custom dimensions.
- A `UserEvent` now takes a `EventDetails` instance instead of a `String` as the `name` parameter. You can create a `EventDetails` instance from a string, leaving category, element, and action empty.
- Events are now persisted until they reached the justtrack servers at least once.
- There is now a short delay before sending user events to batch them.
- The justtrack SDK is now licensed under the MIT license.
- The attribution format was changed slightly and more information is now provided with each attribution.
- Added the current version name (if available) to the app version send to the backend.
- The SDK now fetches the attribution again after 5 seconds (default, can be changed) after a re-attribution opportunity was detected.

### Removed

- Removed units for level, currency, and average count.

## Version 2.4.2 (11th January 2021)

### Changed

- Use build number as version if available.

### Bug-Fixes

- Use correct locale when formatting dates.

## Version 2.3.3 (10th December 2020)

### Added

- Created the SDK and released it onto an unsuspecting world.
