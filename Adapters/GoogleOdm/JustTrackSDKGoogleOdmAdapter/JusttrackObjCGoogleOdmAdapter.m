#import "JusttrackObjCGoogleOdmAdapter.h"
#import <objc/message.h>
#import <objc/runtime.h>

@interface JusttrackObjCGoogleOdmAdapter()
@end

@implementation JusttrackObjCGoogleOdmAdapter

- (instancetype)init {
	self = [super init];

	return self;
}

- (void)fetchOdmInfoOnSuccess:(void (^)(NSString *odmInfo))onSuccess
					onFailure:(void (^)(NSError *error))onFailure {
	// Look up ODCConversionManager class from GoogleAdsOnDeviceConversion SDK
	// Try multiple possible class names for compatibility
	Class ConversionManager = objc_lookUpClass("ODCConversionManager")
		?: objc_lookUpClass("GADCConversionManager")
		?: objc_lookUpClass("ConversionManager");

	if (ConversionManager == NULL) {
		NSError *error = [NSError errorWithDomain:@"JusttrackGoogleOdmAdapter"
											 code:1201
										 userInfo:@{NSLocalizedDescriptionKey: @"GoogleAdsOnDeviceConversion SDK not found. Make sure 'GoogleAdsOnDeviceConversion' pod is installed."}];
		onFailure(error);
		return;
	}

	NSLog(@"[JusttrackGoogleOdmAdapter] Found ConversionManager class: %@", NSStringFromClass(ConversionManager));

	SEL sharedInstanceSelector = NSSelectorFromString(@"sharedInstance");
	if (![ConversionManager respondsToSelector:sharedInstanceSelector]) {
		NSError *error = [NSError errorWithDomain:@"JusttrackGoogleOdmAdapter"
											 code:1202
										 userInfo:@{NSLocalizedDescriptionKey: @"ConversionManager sharedInstance not available"}];
		onFailure(error);
		return;
	}

	id sharedInstance = ((id (*)(id, SEL))objc_msgSend)(ConversionManager, sharedInstanceSelector);
	if (sharedInstance == nil) {
		NSError *error = [NSError errorWithDomain:@"JusttrackGoogleOdmAdapter"
											 code:1203
										 userInfo:@{NSLocalizedDescriptionKey: @"Failed to get ConversionManager sharedInstance"}];
		onFailure(error);
		return;
	}

	SEL fetchSelector = NULL;
	NSArray *possibleFetchSelectors = @[
		@"fetchAggregateConversionInfoForInteraction:completion:",
		@"fetchAggregateConversionInfoForType:completionHandler:",
		@"fetchAggregateConversionInfoForType:completion:"
	];

	for (NSString *selectorName in possibleFetchSelectors) {
		SEL selector = NSSelectorFromString(selectorName);
		if ([sharedInstance respondsToSelector:selector]) {
			fetchSelector = selector;
			NSLog(@"[JusttrackGoogleOdmAdapter] Found fetch method: %@", selectorName);
			break;
		}
	}

	if (fetchSelector == NULL) {
		NSError *error = [NSError errorWithDomain:@"JusttrackGoogleOdmAdapter"
											 code:1204
										 userInfo:@{NSLocalizedDescriptionKey: @"fetchAggregateConversionInfo method not available"}];
		onFailure(error);
		return;
	}

	// ODCInteractionTypeInstallation = 0 (for app-first-open events)
	NSInteger interactionType = 0;

	void (^completionHandler)(NSString *, NSError *) = ^(NSString *aggregateConversionInfo, NSError *error) {
		if (error != nil) {
			NSLog(@"[JusttrackGoogleOdmAdapter] Fetch error: %@", error.localizedDescription);
			onFailure(error);
			return;
		}

		if (aggregateConversionInfo == nil || aggregateConversionInfo.length == 0) {
			NSLog(@"[JusttrackGoogleOdmAdapter] No ODM info available (expected in test environments)");
			NSError *nilError = [NSError errorWithDomain:@"JusttrackGoogleOdmAdapter"
												   code:1205
											   userInfo:@{NSLocalizedDescriptionKey: @"No ODM info available. This is expected if the app was not installed via a Google Ads campaign."}];
			onFailure(nilError);
			return;
		}

		NSLog(@"[JusttrackGoogleOdmAdapter] Successfully fetched ODM info (length: %lu)", (unsigned long)aggregateConversionInfo.length);
		onSuccess(aggregateConversionInfo);
	};

	((void (*)(id, SEL, NSInteger, id))objc_msgSend)(sharedInstance, fetchSelector, interactionType, completionHandler);
}

@end
