#import "JusttrackObjCAppLovinAdapter.h"
#import "JusttrackALImpressionData.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

/// Topic that the MAX SDK broadcasts impression-level revenue events on, for MMPs.
/// See: https://support.applovin.com/en/max/ios/overview/impression-level-user-revenue-api-for-mmps
static NSString *const kJTMaxRevenueEventsTopic = @"max_revenue_events";

#pragma mark - Ad format mapping

/// Maps AppLovin's `ad_format` values to the encoded ad-unit names justtrack reports. The output
/// strings match the canonical `AdUnit.encodedName` values (shared with the Android adapter, which
/// reads the same MAX broadcast); unknown formats return nil so the event is dropped rather than
/// reported as garbage.
static NSString *_Nullable jtMapAdFormat(id adFormat) {
	if (![adFormat isKindOfClass:[NSString class]]) {
		return nil;
	}
	NSString *format = [(NSString *)adFormat uppercaseString];
	if ([format isEqualToString:@"APP_OPEN"] || [format isEqualToString:@"APPOPEN"]) { return @"app_open"; }
	if ([format isEqualToString:@"BANNER"]) { return @"banner"; }
	if ([format isEqualToString:@"MREC"]) { return @"mrec"; }
	if ([format isEqualToString:@"INTER"]) { return @"interstitial"; }
	if ([format isEqualToString:@"REWARDED"]) { return @"rewarded"; }
	if ([format isEqualToString:@"REWARDED_INTER"]) { return @"rewarded_interstitial"; }
	if ([format isEqualToString:@"NATIVE"]) { return @"native"; }
	if ([format isEqualToString:@"LEADER"]) { return @"leader"; }
	return nil;
}

static NSString *_Nullable jtStringOrNil(id value) {
	return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}

#pragma mark - Revenue subscriber

/// Subscribes to the MAX `max_revenue_events` topic (AppLovin's official impression-level revenue
/// API for MMPs) and forwards each impression to justtrack. This replaces the previous approach of
/// swizzling AppLovin load/show methods and wrapping ad delegates, which competed for the ad's
/// `delegate` slot and collided with other delegate-wrapping SDKs (e.g. IronSource Ad Quality),
/// producing forwarding cycles. The communicator is a separate pub/sub channel, so there is no
/// delegate to contend for.
///
/// `didReceiveMessage:` and `communicatorIdentifier` are the `ALCSubscriber` protocol methods.
/// The protocol/message types are not available at compile time (the adapter is built against the
/// AppLovin SDK via the Objective-C runtime, not headers), so the message is typed as `id` and read
/// with KVC, and protocol conformance is added at runtime with `class_addProtocol`.
@interface JTAppLovinRevenueSubscriber : NSObject
@property (nonatomic, copy, nullable) JusttrackALImpressionDataBlock impressionDataBlock;
@end

@implementation JTAppLovinRevenueSubscriber

- (void)didReceiveMessage:(id)message {
	JusttrackALImpressionDataBlock block = self.impressionDataBlock;
	if (message == nil || block == nil) {
		return;
	}

	NSString *topic = nil;
	id data = nil;
	@try {
		topic = [message valueForKey:@"topic"];
		data = [message valueForKey:@"data"];
	} @catch (NSException *exception) {
		return;
	}

	if (![topic isKindOfClass:[NSString class]] || ![topic isEqualToString:kJTMaxRevenueEventsTopic]) {
		return;
	}
	if (![data isKindOfClass:[NSDictionary class]]) {
		return;
	}

	NSDictionary *payload = (NSDictionary *)data;

	id revenueValue = payload[@"revenue"];
	double revenue = [revenueValue respondsToSelector:@selector(doubleValue)] ? [revenueValue doubleValue] : 0.0;
	// A negative revenue (e.g. -1) signals an invalid/errored event from the MAX SDK. Match the
	// Android adapter and drop it rather than reporting a bogus impression.
	if (revenue < 0.0) {
		return;
	}

	NSString *format = jtMapAdFormat(payload[@"ad_format"]);
	if (format == nil) {
		// Unknown ad format — drop, consistent with the Android adapter.
		return;
	}

	// Placement resolution mirrors the Android adapter: prefer `network_placement`; otherwise use
	// `third_party_ad_placement_id`; otherwise fall back to any other key containing "placement".
	NSString *placement = nil;
	BOOL hasNetworkPlacement = payload[@"network_placement"] != nil;
	if (hasNetworkPlacement) {
		placement = jtStringOrNil(payload[@"network_placement"]);
	} else {
		placement = jtStringOrNil(payload[@"third_party_ad_placement_id"]);
		for (id key in payload) {
			if (![key isKindOfClass:[NSString class]]) { continue; }
			NSString *keyString = (NSString *)key;
			if ([keyString isEqualToString:@"third_party_ad_placement_id"]) { continue; }
			if ([keyString rangeOfString:@"placement"].location == NSNotFound) { continue; }
			id value = payload[keyString];
			if ([value isKindOfClass:[NSString class]]) {
				placement = (NSString *)value;
			}
		}
	}

	JusttrackALImpressionData *impressionData = [[JusttrackALImpressionData alloc] init];
	impressionData.format = format;
	impressionData.network = jtStringOrNil(payload[@"network_name"]);
	impressionData.placement = placement;
	impressionData.segmentName = jtStringOrNil(payload[@"user_segment"]);
	impressionData.instanceName = jtStringOrNil(payload[@"max_ad_unit_id"]);
	impressionData.revenue = @(revenue);

	block(impressionData);
}

- (NSString *)communicatorIdentifier {
	return @"justtrack";
}

@end

#pragma mark - Adapter

/// Held strongly for the lifetime of the process: the MAX communicator keeps only a weak reference
/// to its subscribers, so we must retain ours ourselves.
static JTAppLovinRevenueSubscriber *jtRevenueSubscriber = nil;

@implementation JusttrackObjCAppLovinAdapter

- (instancetype)init {
	self = [super init];

	return self;
}

- (void)integrateCustomUserId:(NSString * _Nullable)customUserId
		  impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlockParam
					onSuccess:(void (^)(void))onSuccess
					onFailure:(void (^)(NSError *error))onFailure {

	Class ALSdk = objc_lookUpClass("ALSdk") ?: objc_lookUpClass("AppLovinSDK.ALSdk");
	if (ALSdk == NULL) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:1101
										 userInfo:@{NSLocalizedDescriptionKey: @"Could not find ALSdk class"}];
		onFailure(error);
		return;
	}

	NSString *version = nil;
	Method getValueForKeyMethod = class_getClassMethod(ALSdk, @selector(valueForKey:));
	if (getValueForKeyMethod != NULL) {
		typedef id (*GetValueForKey)(Class, SEL, NSString*);
		GetValueForKey getValueForKey = (GetValueForKey) method_getImplementation(getValueForKeyMethod);
		version = getValueForKey(ALSdk, @selector(valueForKey:), @"version");
	}

	// Set the custom user id (best effort, unchanged from the previous implementation).
	bool userIdHandled = false;
	if (customUserId != NULL) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		SEL sharedSelector = NSSelectorFromString(@"shared");
		SEL settingsSelector = NSSelectorFromString(@"settings");
		if ([ALSdk respondsToSelector:sharedSelector]) {
			id instance = [ALSdk performSelector:sharedSelector];
			if (instance != NULL) {
				SEL setUserIdentifierSelector = NSSelectorFromString(@"setUserIdentifier:");
				if ([instance respondsToSelector:setUserIdentifierSelector]) {
					[instance performSelector:setUserIdentifierSelector withObject:customUserId];
					userIdHandled = true;
				} else if ([instance respondsToSelector:settingsSelector]) {
					id settings = [instance performSelector:settingsSelector];
					if ([settings respondsToSelector:setUserIdentifierSelector]) {
						[settings performSelector:setUserIdentifierSelector withObject:customUserId];
						userIdHandled = true;
					}
				}
			}
		}
#pragma clang diagnostic pop
	} else {
		userIdHandled = true;
	}

	if (!userIdHandled) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:1111
										 userInfo:@{NSLocalizedDescriptionKey: @"Could not set userId:"}];
		onFailure(error);
		return;
	}

	// Subscribe to the MAX impression-level revenue events (official MMP API).
	Class ALCCommunicator = objc_lookUpClass("ALCCommunicator") ?: objc_lookUpClass("AppLovinSDK.ALCCommunicator");
	if (ALCCommunicator == NULL) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:1112
										 userInfo:@{NSLocalizedDescriptionKey: @"Could not find ALCCommunicator; the AppLovin SDK is too old for the MMP revenue API"}];
		onFailure(error);
		return;
	}

	SEL defaultCommunicatorSelector = NSSelectorFromString(@"defaultCommunicator");
	if (![ALCCommunicator respondsToSelector:defaultCommunicatorSelector]) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:1113
										 userInfo:@{NSLocalizedDescriptionKey: @"ALCCommunicator does not respond to defaultCommunicator"}];
		onFailure(error);
		return;
	}

	id communicator = ((id (*)(id, SEL))objc_msgSend)(ALCCommunicator, defaultCommunicatorSelector);
	SEL subscribeSelector = NSSelectorFromString(@"subscribe:forTopic:");
	if (communicator == nil || ![communicator respondsToSelector:subscribeSelector]) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:1114
										 userInfo:@{NSLocalizedDescriptionKey: @"ALCCommunicator does not support subscribe:forTopic:"}];
		onFailure(error);
		return;
	}

	if (jtRevenueSubscriber == nil) {
		// `subscribe:forTopic:` may verify conformsToProtocol:@protocol(ALCSubscriber); add it at runtime.
		static dispatch_once_t protocolOnceToken;
		dispatch_once(&protocolOnceToken, ^{
			Protocol *subscriberProtocol = objc_getProtocol("ALCSubscriber");
			if (subscriberProtocol != NULL) {
				class_addProtocol([JTAppLovinRevenueSubscriber class], subscriberProtocol);
			}
		});

		jtRevenueSubscriber = [[JTAppLovinRevenueSubscriber alloc] init];
		jtRevenueSubscriber.impressionDataBlock = [impressionDataBlockParam copy];

		((void (*)(id, SEL, id, NSString *))objc_msgSend)(communicator, subscribeSelector, jtRevenueSubscriber, kJTMaxRevenueEventsTopic);
	} else {
		// Already subscribed (idempotent re-integration): just refresh the callback.
		jtRevenueSubscriber.impressionDataBlock = [impressionDataBlockParam copy];
	}

	NSLog(@"[JusttrackSDK] Successfully integrated AppLovin adapter version: %@ (MAX revenue events)", version);
	onSuccess();
}

@end
