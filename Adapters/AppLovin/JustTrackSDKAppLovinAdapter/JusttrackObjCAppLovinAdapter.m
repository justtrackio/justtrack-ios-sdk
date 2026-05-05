#import "JusttrackObjCAppLovinAdapter.h"
#import "JusttrackALImpressionData.h"
#import "JTAppLovinDelegates.h"
#import "JTALReferenceRetainer.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

void loadAppLovinBannerAd(MAAdView* ad, SEL sel);
void removeFromSuperviewForAppLovinBanner(UIView* view, SEL sel);
void showAppLovinInterstitialAd(MAInterstitialAd* ad, SEL sel);
void showAppLovinInterstitialAdForPlacement(MAInterstitialAd* ad, SEL sel, NSString* __nullable placement);
void showAppLovinInterstitialAdForPlacementWithCustomData(MAInterstitialAd* ad, SEL sel, NSString* __nullable placement, NSString* __nullable customData);
void showAppLovinRewardedAd(MARewardedAd* ad, SEL sel);
void showAppLovinRewardedAdForPlacement(MARewardedAd* ad, SEL sel, NSString* __nullable placement);
void showAppLovinRewardedAdForPlacementWithCustomData(MARewardedAd* ad, SEL sel, NSString* __nullable placement, NSString* __nullable customData);
void showAppLovinRewardedInterstitialAd(MARewardedInterstitialAd* ad, SEL sel);
void showAppLovinRewardedInterstitialAdForPlacement(MARewardedInterstitialAd* ad, SEL sel, NSString* __nullable placement);
void showAppLovinRewardedInterstitialAdForPlacementWithCustomData(MARewardedInterstitialAd* ad, SEL sel, NSString* __nullable placement, NSString* __nullable customData);
void showAppLovinOpenAd(MAAppOpenAd* ad, SEL sel);
void showAppLovinOpenAdForPlacement(MAAppOpenAd* ad, SEL sel, NSString * __nullable placement);
void showAppLovinOpenAdForPlacementWithCustomData(MAAppOpenAd* ad, SEL sel, NSString * __nullable placement, NSString * __nullable customData);
void loadAppLovinNativeAd(MANativeAdLoader* loader, SEL sel);
void loadAppLovinNativeAdIntoView(MANativeAdLoader* loader, SEL sel, MANativeAdView* __nullable view);

@class MAAd;
@class MAAdView;
@class MAInterstitialAd;
@class MARewardedAd;
@class MARewardedInterstitialAd;
@class MAAppOpenAd;
@class MANativeAdLoader;
@class MANativeAdView;
@class MAAdFormat;

typedef void (*LoadBannerAdCallback)(MAAdView*, SEL);
typedef void (*RemoveFromSuperviewCallback)(UIView*, SEL);

typedef void (*ShowInterstitialAdCallback)(MAInterstitialAd*, SEL);
typedef void (*ShowInterstitialAdForPlacementCallback)(MAInterstitialAd*, SEL, NSString* __nullable);
typedef void (*ShowInterstitialAdForPlacementWithCustomDataCallback)(MAInterstitialAd*, SEL, NSString* __nullable, NSString* __nullable);

typedef void (*ShowRewardedAdCallback)(MARewardedAd*, SEL);
typedef void (*ShowRewardedAdForPlacementCallback)(MARewardedAd*, SEL, NSString* __nullable);
typedef void (*ShowRewardedAdForPlacementWithCustomDataCallback)(MARewardedAd*, SEL, NSString* __nullable, NSString* __nullable);

typedef void (*ShowRewardedInterstitialAdCallback)(MARewardedInterstitialAd*, SEL);
typedef void (*ShowRewardedInterstitialAdForPlacementCallback)(MARewardedInterstitialAd*, SEL, NSString* __nullable);
typedef void (*ShowRewardedInterstitialAdForPlacementWithCustomDataCallback)(MARewardedInterstitialAd*, SEL, NSString* __nullable, NSString* __nullable);

typedef void (*ShowAppOpenAdCallback)(MAAppOpenAd*, SEL);
typedef void (*ShowAppOpenAdForPlacementCallback)(MAAppOpenAd*, SEL, NSString* __nullable);
typedef void (*ShowAppOpenAdForPlacementWithCustomDataCallback)(MAAppOpenAd*, SEL, NSString* __nullable, NSString* __nullable);

typedef void (*LoadNativeAdCallback)(MANativeAdLoader*, SEL);
typedef void (*LoadNativeAdIntoViewCallback)(MANativeAdLoader*, SEL, MANativeAdView * __nullable);

bool listenForRevenue = false;
JusttrackALImpressionDataBlock _Nullable impressionDataBlock = nil;

LoadBannerAdCallback __nullable loadBannerAdCallback = NULL;
RemoveFromSuperviewCallback __nullable removeFromSuperviewCallback = NULL;

ShowInterstitialAdCallback __nullable showInterstitialAdCallback = NULL;
ShowInterstitialAdForPlacementCallback __nullable showInterstitialAdForPlacementCallback = NULL;
ShowInterstitialAdForPlacementWithCustomDataCallback __nullable showInterstitialAdForPlacementWithCustomDataCallback = NULL;

ShowRewardedAdCallback __nullable showRewardedAdCallback = NULL;
ShowRewardedAdForPlacementCallback __nullable showRewardedAdForPlacementCallback = NULL;
ShowRewardedAdForPlacementWithCustomDataCallback __nullable showRewardedAdForPlacementWithCustomDataCallback = NULL;

ShowRewardedInterstitialAdCallback __nullable showRewardedInterstitialAdCallback = NULL;
ShowRewardedInterstitialAdForPlacementCallback __nullable showRewardedInterstitialAdForPlacementCallback = NULL;
ShowRewardedInterstitialAdForPlacementWithCustomDataCallback __nullable showRewardedInterstitialAdForPlacementWithCustomDataCallback = NULL;

ShowAppOpenAdCallback __nullable showAppOpenAdCallback = NULL;
ShowAppOpenAdForPlacementCallback __nullable showAppOpenAdForPlacementCallback = NULL;
ShowAppOpenAdForPlacementWithCustomDataCallback __nullable showAppOpenAdForPlacementWithCustomDataCallback = NULL;

LoadNativeAdCallback __nullable loadNativeAdCallback = NULL;
LoadNativeAdIntoViewCallback __nullable loadNativeAdIntoViewCallback = NULL;

@interface JusttrackObjCAppLovinAdapter()
@end

@implementation JusttrackObjCAppLovinAdapter

- (instancetype)init {
	self = [super init];
	
	return self;
}

- (void)integrateCustomUserId:(NSString * _Nullable)customUserId
		  impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlockParam
					onSuccess:(void (^)(void))onSuccess
					onFailure:(void (^)(NSError *error))onFailure {
	impressionDataBlock = [impressionDataBlockParam copy];
	Class MAAdView = objc_lookUpClass("MAAdView") ?: objc_lookUpClass("AppLovinSDK.MAAdView");
	if (MAAdView == NULL) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:1101
										 userInfo:@{NSLocalizedDescriptionKey: @"Could not find MAAdView class"}];
		onFailure(error);
		return;
	}

	Class MAInterstitialAd = objc_lookUpClass("MAInterstitialAd") ?: objc_lookUpClass("AppLovinSDK.MAInterstitialAd");
	if (MAInterstitialAd == NULL) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:1102
										 userInfo:@{NSLocalizedDescriptionKey: @"Could not find MAInterstitialAd class"}];
		onFailure(error);
		return;
	}

	Class MARewardedAd = objc_lookUpClass("MARewardedAd") ?: objc_lookUpClass("AppLovinSDK.MARewardedAd");
	if (MARewardedAd == NULL) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:1103
										 userInfo:@{NSLocalizedDescriptionKey: @"Could not find MARewardedAd class"}];
		onFailure(error);
		return;
	}

	Class MARewardedInterstitialAd = objc_lookUpClass("MARewardedInterstitialAd") ?: objc_lookUpClass("AppLovinSDK.MARewardedInterstitialAd");

	Class MANativeAdLoader = objc_lookUpClass("MANativeAdLoader") ?: objc_lookUpClass("AppLovinSDK.MANativeAdLoader");
	if (MANativeAdLoader == NULL) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:1104
										 userInfo:@{NSLocalizedDescriptionKey: @"Could not find MANativeAdLoader class"}];
		onFailure(error);
		return;
	}

	Class MANativeAdView = objc_lookUpClass("MANativeAdView") ?: objc_lookUpClass("AppLovinSDK.MANativeAdView");
	if (MANativeAdView == NULL) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:1105
										 userInfo:@{NSLocalizedDescriptionKey: @"Could not find MANativeAdView class"}];
		onFailure(error);
		return;
	}

	Class MAAppOpenAd = objc_lookUpClass("MAAppOpenAd") ?: objc_lookUpClass("AppLovinSDK.MAAppOpenAd");
	if (MAAppOpenAd == NULL) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:1106
										 userInfo:@{NSLocalizedDescriptionKey: @"Could not find MAAppOpenAd class"}];
		onFailure(error);
		return;
	}

	Class ALSdk = objc_lookUpClass("ALSdk") ?: objc_lookUpClass("AppLovinSDK.ALSdk");
	if (ALSdk == NULL) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:1107
										 userInfo:@{NSLocalizedDescriptionKey: @"Could not find ALSdk class"}];
		onFailure(error);
		return;
	}

	Method getValueForKeyMethod = class_getClassMethod(ALSdk, @selector(valueForKey:));
	if (getValueForKeyMethod == NULL) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:1108
										 userInfo:@{NSLocalizedDescriptionKey: @"Could not find ALSdk valueForKey:"}];
		onFailure(error);
		return;
	}

	typedef id (*GetValueForKey)(Class, SEL, NSString*);
	GetValueForKey getValueForKey = (GetValueForKey) method_getImplementation(getValueForKeyMethod);

	NSString *version = getValueForKey(ALSdk, @selector(valueForKey:), @"version");

	static dispatch_once_t bannerSwizzleToken;
	static BOOL bannerSwizzleSuccess = YES;
	dispatch_once(&bannerSwizzleToken, ^{
		Method loadAdMethod = class_getInstanceMethod(MAAdView, NSSelectorFromString(@"loadAd"));
		if (loadAdMethod != NULL) {
			IMP oldIMP = method_getImplementation(loadAdMethod);
			loadBannerAdCallback = (LoadBannerAdCallback) oldIMP;
			method_setImplementation(loadAdMethod, (IMP) loadAppLovinBannerAd);
		} else {
			bannerSwizzleSuccess = NO;
		}
	});
	if (!bannerSwizzleSuccess) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:1109
										 userInfo:@{NSLocalizedDescriptionKey: @"Could not find MAAdView loadAd"}];
		onFailure(error);
		return;
	}

	static dispatch_once_t removeFromSuperviewSwizzleToken;
	static BOOL removeFromSuperviewSwizzleSuccess = YES;
	dispatch_once(&removeFromSuperviewSwizzleToken, ^{
		Method removeFromSuperviewMethod = class_getInstanceMethod(UIView.class, @selector(removeFromSuperview));
		if (removeFromSuperviewMethod != NULL) {
			IMP oldIMP = method_getImplementation(removeFromSuperviewMethod);
			removeFromSuperviewCallback = (RemoveFromSuperviewCallback) oldIMP;
			method_setImplementation(removeFromSuperviewMethod, (IMP) removeFromSuperviewForAppLovinBanner);
		} else {
			removeFromSuperviewSwizzleSuccess = NO;
		}
	});
	if (!removeFromSuperviewSwizzleSuccess) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:1110
										 userInfo:@{NSLocalizedDescriptionKey: @"Could not find UIView removeFromSuperview"}];
		onFailure(error);
		return;
	}

	[self setupInterstitialSwizzling:MAInterstitialAd onFailure:onFailure];

	[self setupRewardedSwizzling:MARewardedAd onFailure:onFailure];

	if (MARewardedInterstitialAd != NULL) {
		[self setupRewardedInterstitialSwizzling:MARewardedInterstitialAd onFailure:onFailure];
	}

	[self setupNativeAdSwizzling:MANativeAdLoader onFailure:onFailure];

	[self setupAppOpenAdSwizzling:MAAppOpenAd onFailure:onFailure];

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

	if (userIdHandled) {
		NSLog(@"[JusttrackSDK] Successfully integrated AppLovin adapter version: %@", version);
		onSuccess();
	} else {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:1111
										 userInfo:@{NSLocalizedDescriptionKey: @"Could not set userId:"}];
		onFailure(error);
	}
}

- (void)setupInterstitialSwizzling:(Class)MAInterstitialAd onFailure:(void (^)(NSError *error))onFailure {
	static dispatch_once_t interstitialSwizzleToken;
	static BOOL interstitialSwizzleSuccess = YES;
	static int interstitialSwizzleErrorCode = 0;
	static NSString *interstitialSwizzleErrorMessage = nil;
	dispatch_once(&interstitialSwizzleToken, ^{
		Method showAdMethod = class_getInstanceMethod(MAInterstitialAd, NSSelectorFromString(@"showAd"));
		Method showAdForPlacementMethod = class_getInstanceMethod(MAInterstitialAd, NSSelectorFromString(@"showAdForPlacement:"));
		Method showAdForPlacementWithCustomDataMethod = class_getInstanceMethod(MAInterstitialAd, NSSelectorFromString(@"showAdForPlacement:customData:"));

		if (showAdMethod != NULL) {
			IMP oldIMP = method_getImplementation(showAdMethod);
			showInterstitialAdCallback = (ShowInterstitialAdCallback) oldIMP;
			method_setImplementation(showAdMethod, (IMP) showAppLovinInterstitialAd);
		} else {
			interstitialSwizzleSuccess = NO;
			interstitialSwizzleErrorCode = 2101;
			interstitialSwizzleErrorMessage = @"Could not find MAInterstitialAd showAd";
			return;
		}

		if (showAdForPlacementMethod != NULL) {
			IMP oldIMP = method_getImplementation(showAdForPlacementMethod);
			showInterstitialAdForPlacementCallback = (ShowInterstitialAdForPlacementCallback) oldIMP;
			method_setImplementation(showAdForPlacementMethod, (IMP) showAppLovinInterstitialAdForPlacement);
		} else {
			interstitialSwizzleSuccess = NO;
			interstitialSwizzleErrorCode = 2102;
			interstitialSwizzleErrorMessage = @"Could not find MAInterstitialAd showAdForPlacement:";
			return;
		}

		if (showAdForPlacementWithCustomDataMethod != NULL) {
			IMP oldIMP = method_getImplementation(showAdForPlacementWithCustomDataMethod);
			showInterstitialAdForPlacementWithCustomDataCallback = (ShowInterstitialAdForPlacementWithCustomDataCallback) oldIMP;
			method_setImplementation(showAdForPlacementWithCustomDataMethod, (IMP) showAppLovinInterstitialAdForPlacementWithCustomData);
		} else {
			interstitialSwizzleSuccess = NO;
			interstitialSwizzleErrorCode = 2103;
			interstitialSwizzleErrorMessage = @"Could not find MAInterstitialAd showAdForPlacement:customData:";
			return;
		}
	});
	if (!interstitialSwizzleSuccess) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:interstitialSwizzleErrorCode
										 userInfo:@{NSLocalizedDescriptionKey: interstitialSwizzleErrorMessage}];
		onFailure(error);
	}
}

- (void)setupRewardedSwizzling:(Class)MARewardedAd onFailure:(void (^)(NSError *error))onFailure {
	static dispatch_once_t rewardedSwizzleToken;
	static BOOL rewardedSwizzleSuccess = YES;
	static int rewardedSwizzleErrorCode = 0;
	static NSString *rewardedSwizzleErrorMessage = nil;
	dispatch_once(&rewardedSwizzleToken, ^{
		Method showAdMethod = class_getInstanceMethod(MARewardedAd, NSSelectorFromString(@"showAd"));
		Method showAdForPlacementMethod = class_getInstanceMethod(MARewardedAd, NSSelectorFromString(@"showAdForPlacement:"));
		Method showAdForPlacementWithCustomDataMethod = class_getInstanceMethod(MARewardedAd, NSSelectorFromString(@"showAdForPlacement:customData:"));

		if (showAdMethod != NULL) {
			IMP oldIMP = method_getImplementation(showAdMethod);
			showRewardedAdCallback = (ShowRewardedAdCallback) oldIMP;
			method_setImplementation(showAdMethod, (IMP) showAppLovinRewardedAd);
		} else {
			rewardedSwizzleSuccess = NO;
			rewardedSwizzleErrorCode = 3101;
			rewardedSwizzleErrorMessage = @"Could not find MARewardedAd showAd";
			return;
		}

		if (showAdForPlacementMethod != NULL) {
			IMP oldIMP = method_getImplementation(showAdForPlacementMethod);
			showRewardedAdForPlacementCallback = (ShowRewardedAdForPlacementCallback) oldIMP;
			method_setImplementation(showAdForPlacementMethod, (IMP) showAppLovinRewardedAdForPlacement);
		} else {
			rewardedSwizzleSuccess = NO;
			rewardedSwizzleErrorCode = 3102;
			rewardedSwizzleErrorMessage = @"Could not find MARewardedAd showAdForPlacement:";
			return;
		}

		if (showAdForPlacementWithCustomDataMethod != NULL) {
			IMP oldIMP = method_getImplementation(showAdForPlacementWithCustomDataMethod);
			showRewardedAdForPlacementWithCustomDataCallback = (ShowRewardedAdForPlacementWithCustomDataCallback) oldIMP;
			method_setImplementation(showAdForPlacementWithCustomDataMethod, (IMP) showAppLovinRewardedAdForPlacementWithCustomData);
		} else {
			rewardedSwizzleSuccess = NO;
			rewardedSwizzleErrorCode = 3103;
			rewardedSwizzleErrorMessage = @"Could not find MARewardedAd showAdForPlacement:customData:";
			return;
		}
	});
	if (!rewardedSwizzleSuccess) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:rewardedSwizzleErrorCode
										 userInfo:@{NSLocalizedDescriptionKey: rewardedSwizzleErrorMessage}];
		onFailure(error);
	}
}

- (void)setupRewardedInterstitialSwizzling:(Class)MARewardedInterstitialAd onFailure:(void (^)(NSError *error))onFailure {
	static dispatch_once_t rewardedInterstitialSwizzleToken;
	static BOOL rewardedInterstitialSwizzleSuccess = YES;
	static int rewardedInterstitialSwizzleErrorCode = 0;
	static NSString *rewardedInterstitialSwizzleErrorMessage = nil;
	dispatch_once(&rewardedInterstitialSwizzleToken, ^{
		Method showAdMethod = class_getInstanceMethod(MARewardedInterstitialAd, NSSelectorFromString(@"showAd"));
		Method showAdForPlacementMethod = class_getInstanceMethod(MARewardedInterstitialAd, NSSelectorFromString(@"showAdForPlacement:"));
		Method showAdForPlacementWithCustomDataMethod = class_getInstanceMethod(MARewardedInterstitialAd, NSSelectorFromString(@"showAdForPlacement:customData:"));

		if (showAdMethod != NULL) {
			IMP oldIMP = method_getImplementation(showAdMethod);
			showRewardedInterstitialAdCallback = (ShowRewardedInterstitialAdCallback) oldIMP;
			method_setImplementation(showAdMethod, (IMP) showAppLovinRewardedInterstitialAd);
		} else {
			rewardedInterstitialSwizzleSuccess = NO;
			rewardedInterstitialSwizzleErrorCode = 4101;
			rewardedInterstitialSwizzleErrorMessage = @"Could not find MARewardedInterstitialAd showAd";
			return;
		}

		if (showAdForPlacementMethod != NULL) {
			IMP oldIMP = method_getImplementation(showAdForPlacementMethod);
			showRewardedInterstitialAdForPlacementCallback = (ShowRewardedInterstitialAdForPlacementCallback) oldIMP;
			method_setImplementation(showAdForPlacementMethod, (IMP) showAppLovinRewardedInterstitialAdForPlacement);
		} else {
			rewardedInterstitialSwizzleSuccess = NO;
			rewardedInterstitialSwizzleErrorCode = 4102;
			rewardedInterstitialSwizzleErrorMessage = @"Could not find MARewardedInterstitialAd showAdForPlacement:";
			return;
		}

		if (showAdForPlacementWithCustomDataMethod != NULL) {
			IMP oldIMP = method_getImplementation(showAdForPlacementWithCustomDataMethod);
			showRewardedInterstitialAdForPlacementWithCustomDataCallback = (ShowRewardedInterstitialAdForPlacementWithCustomDataCallback) oldIMP;
			method_setImplementation(showAdForPlacementWithCustomDataMethod, (IMP) showAppLovinRewardedInterstitialAdForPlacementWithCustomData);
		} else {
			rewardedInterstitialSwizzleSuccess = NO;
			rewardedInterstitialSwizzleErrorCode = 4103;
			rewardedInterstitialSwizzleErrorMessage = @"Could not find MARewardedInterstitialAd showAdForPlacement:customData:";
			return;
		}
	});
	if (!rewardedInterstitialSwizzleSuccess) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:rewardedInterstitialSwizzleErrorCode
										 userInfo:@{NSLocalizedDescriptionKey: rewardedInterstitialSwizzleErrorMessage}];
		onFailure(error);
	}
}

- (void)setupNativeAdSwizzling:(Class)MANativeAdLoader onFailure:(void (^)(NSError *error))onFailure {
	static dispatch_once_t nativeAdSwizzleToken;
	static BOOL nativeAdSwizzleSuccess = YES;
	static int nativeAdSwizzleErrorCode = 0;
	static NSString *nativeAdSwizzleErrorMessage = nil;
	dispatch_once(&nativeAdSwizzleToken, ^{
		Method loadNativeAdMethod = class_getInstanceMethod(MANativeAdLoader, NSSelectorFromString(@"loadAd"));
		if (loadNativeAdMethod != NULL) {
			IMP oldIMP = method_getImplementation(loadNativeAdMethod);
			loadNativeAdCallback = (LoadNativeAdCallback) oldIMP;
			method_setImplementation(loadNativeAdMethod, (IMP) loadAppLovinNativeAd);
		} else {
			nativeAdSwizzleSuccess = NO;
			nativeAdSwizzleErrorCode = 5101;
			nativeAdSwizzleErrorMessage = @"Could not find MANativeAdLoader loadAd";
			return;
		}

		Method loadNativeAdIntoViewMethod = class_getInstanceMethod(MANativeAdLoader, NSSelectorFromString(@"loadAdIntoAdView:"));
		if (loadNativeAdIntoViewMethod != NULL) {
			IMP oldIMP = method_getImplementation(loadNativeAdIntoViewMethod);
			loadNativeAdIntoViewCallback = (LoadNativeAdIntoViewCallback) oldIMP;
			method_setImplementation(loadNativeAdIntoViewMethod, (IMP) loadAppLovinNativeAdIntoView);
		} else {
			nativeAdSwizzleSuccess = NO;
			nativeAdSwizzleErrorCode = 5102;
			nativeAdSwizzleErrorMessage = @"Could not find MANativeAdLoader loadAdIntoAdView:";
			return;
		}
	});
	if (!nativeAdSwizzleSuccess) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:nativeAdSwizzleErrorCode
										 userInfo:@{NSLocalizedDescriptionKey: nativeAdSwizzleErrorMessage}];
		onFailure(error);
	}
}

- (void)setupAppOpenAdSwizzling:(Class)MAAppOpenAd onFailure:(void (^)(NSError *error))onFailure {
	static dispatch_once_t appOpenAdSwizzleToken;
	static BOOL appOpenAdSwizzleSuccess = YES;
	static int appOpenAdSwizzleErrorCode = 0;
	static NSString *appOpenAdSwizzleErrorMessage = nil;
	dispatch_once(&appOpenAdSwizzleToken, ^{
		Method showAdMethod = class_getInstanceMethod(MAAppOpenAd, NSSelectorFromString(@"showAd"));
		if (showAdMethod != NULL) {
			IMP oldIMP = method_getImplementation(showAdMethod);
			showAppOpenAdCallback = (ShowAppOpenAdCallback) oldIMP;
			method_setImplementation(showAdMethod, (IMP) showAppLovinOpenAd);
		} else {
			appOpenAdSwizzleSuccess = NO;
			appOpenAdSwizzleErrorCode = 6101;
			appOpenAdSwizzleErrorMessage = @"Could not find MAAppOpenAd showAd";
			return;
		}

		Method showAdForPlacementMethod = class_getInstanceMethod(MAAppOpenAd, NSSelectorFromString(@"showAdForPlacement:"));
		if (showAdForPlacementMethod != NULL) {
			IMP oldIMP = method_getImplementation(showAdForPlacementMethod);
			showAppOpenAdForPlacementCallback = (ShowAppOpenAdForPlacementCallback) oldIMP;
			method_setImplementation(showAdForPlacementMethod, (IMP) showAppLovinOpenAdForPlacement);
		} else {
			appOpenAdSwizzleSuccess = NO;
			appOpenAdSwizzleErrorCode = 6102;
			appOpenAdSwizzleErrorMessage = @"Could not find MAAppOpenAd showAdForPlacement:";
			return;
		}

		Method showAdForPlacementWithCustomDataMethod = class_getInstanceMethod(MAAppOpenAd, NSSelectorFromString(@"showAdForPlacement:customData:"));
		if (showAdForPlacementWithCustomDataMethod != NULL) {
			IMP oldIMP = method_getImplementation(showAdForPlacementWithCustomDataMethod);
			showAppOpenAdForPlacementWithCustomDataCallback = (ShowAppOpenAdForPlacementWithCustomDataCallback) oldIMP;
			method_setImplementation(showAdForPlacementWithCustomDataMethod, (IMP) showAppLovinOpenAdForPlacementWithCustomData);
		} else {
			appOpenAdSwizzleSuccess = NO;
			appOpenAdSwizzleErrorCode = 6103;
			appOpenAdSwizzleErrorMessage = @"Could not find MAAppOpenAd showAdForPlacement:customData:";
			return;
		}
	});
	if (!appOpenAdSwizzleSuccess) {
		NSError *error = [NSError errorWithDomain:@"JusttrackAppLovinAdapter"
											 code:appOpenAdSwizzleErrorCode
										 userInfo:@{NSLocalizedDescriptionKey: appOpenAdSwizzleErrorMessage}];
		onFailure(error);
	}
}

@end

