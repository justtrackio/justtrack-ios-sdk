#import "JTAppLovinDelegates.h"
#import "JTALReferenceRetainer.h"
#import <objc/runtime.h>
#import <objc/message.h>

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

extern bool listenForRevenue;

static NSString* __nullable getAdFormat(MAAd* __nullable ad);
static void callImpressionDataBlock(JusttrackALImpressionDataBlock block, MAAd* ad, NSString* format);

#pragma mark JTAppLovinAdDelegate

@implementation JTAppLovinAdDelegate

- (id)init:(NSObject<MAAdViewAdDelegate>*)wrapped
     appOpenAd:(MAAppOpenAd*)appOpenAd
listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock {
    self = [super init];

    if (self != NULL) {
        self.wrappedBanner = wrapped;
        self.wrapped = wrapped;
        self.wrappedRewarded = NULL;
        self.appOpenAd = appOpenAd;
        self.bannerAd = NULL;
        self.interstitialAd = NULL;
        self.rewardedAd = NULL;
        self.rewardedInterstitialAd = NULL;
        self.listenForRevenue = listenForRevenue;
        self.impressionDataBlock = impressionDataBlock;
        self.referenceIndex = [[JTALReferenceRetainer shared] retain:self];
    }

    return self;
}

- (id)init:(NSObject<MAAdViewAdDelegate>*)wrapped
      bannerAd:(MAAdView*)bannerAd
listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock {
    self = [super init];

    if (self != NULL) {
        self.wrappedBanner = wrapped;
        self.wrapped = wrapped;
        self.wrappedRewarded = NULL;
        self.appOpenAd = NULL;
        self.bannerAd = bannerAd;
        self.interstitialAd = NULL;
        self.rewardedAd = NULL;
        self.rewardedInterstitialAd = NULL;
        self.listenForRevenue = listenForRevenue;
        self.impressionDataBlock = impressionDataBlock;
        self.referenceIndex = [[JTALReferenceRetainer shared] retain:self];
    }

    return self;
}

- (id)init:(NSObject<MAAdDelegate>*)wrapped
interstitialAd:(MAInterstitialAd*)interstitialAd
listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock {
    self = [super init];

    if (self != NULL) {
        self.wrappedBanner = NULL;
        self.wrapped = wrapped;
        self.wrappedRewarded = NULL;
        self.appOpenAd = NULL;
        self.bannerAd = NULL;
        self.interstitialAd = interstitialAd;
        self.rewardedAd = NULL;
        self.rewardedInterstitialAd = NULL;
        self.listenForRevenue = listenForRevenue;
        self.impressionDataBlock = impressionDataBlock;
        self.referenceIndex = [[JTALReferenceRetainer shared] retain:self];
    }

    return self;
}

- (id)init:(NSObject<MARewardedAdDelegate>*)wrapped
    rewardedAd:(MARewardedAd*)rewardedAd
listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock {
    self = [super init];

    if (self != NULL) {
        self.wrappedBanner = NULL;
        self.wrapped = wrapped;
        self.wrappedRewarded = wrapped;
        self.appOpenAd = NULL;
        self.bannerAd = NULL;
        self.interstitialAd = NULL;
        self.rewardedAd = rewardedAd;
        self.rewardedInterstitialAd = NULL;
        self.listenForRevenue = listenForRevenue;
        self.impressionDataBlock = impressionDataBlock;
        self.referenceIndex = [[JTALReferenceRetainer shared] retain:self];
    }

    return self;
}

- (id)init:(NSObject<MARewardedAdDelegate> *)wrapped
rewardedInterstitialAd:(MARewardedInterstitialAd *)rewardedInterstitialAd
       listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock {
    self = [super init];

    if (self != NULL) {
        self.wrappedBanner = NULL;
        self.wrapped = wrapped;
        self.wrappedRewarded = wrapped;
        self.appOpenAd = NULL;
        self.bannerAd = NULL;
        self.interstitialAd = NULL;
        self.rewardedAd = NULL;
        self.rewardedInterstitialAd = rewardedInterstitialAd;
        self.listenForRevenue = listenForRevenue;
        self.impressionDataBlock = impressionDataBlock;
        self.referenceIndex = [[JTALReferenceRetainer shared] retain:self];
    }

    return self;
}

- (void)unref {
    if (self.appOpenAd != NULL && [(id)self.appOpenAd valueForKey:@"delegate"] == self) {
        [(id)self.appOpenAd setValue:self.wrapped forKey:@"delegate"];
        self.appOpenAd = NULL;
    } else if (self.bannerAd != NULL && [(id)self.bannerAd valueForKey:@"delegate"] == self) {
        [(id)self.bannerAd setValue:self.wrappedBanner forKey:@"delegate"];
        self.bannerAd = NULL;
    } else if (self.interstitialAd != NULL && [(id)self.interstitialAd valueForKey:@"delegate"] == self) {
        [(id)self.interstitialAd setValue:self.wrapped forKey:@"delegate"];
        self.interstitialAd = NULL;
    } else if (self.rewardedAd != NULL && [(id)self.rewardedAd valueForKey:@"delegate"] == self) {
        [(id)self.rewardedAd setValue:self.wrappedRewarded forKey:@"delegate"];
        self.rewardedAd = NULL;
    } else if (self.rewardedInterstitialAd != NULL && [(id)self.rewardedInterstitialAd valueForKey:@"delegate"] == self) {
        [(id)self.rewardedInterstitialAd setValue:self.wrappedRewarded forKey:@"delegate"];
        self.rewardedInterstitialAd = NULL;
    } else {
        return;
    }

    [[JTALReferenceRetainer shared] release:self.referenceIndex];
}

- (void)didExpandAd:(MAAd *)ad {
    if (self.wrappedBanner != NULL && [self.wrappedBanner respondsToSelector:@selector(didExpandAd:)]) {
        [self.wrappedBanner performSelector:@selector(didExpandAd:) withObject:ad];
    }
}

- (void)didCollapseAd:(MAAd *)ad {
    if (self.wrappedBanner != NULL && [self.wrappedBanner respondsToSelector:@selector(didCollapseAd:)]) {
        [self.wrappedBanner performSelector:@selector(didCollapseAd:) withObject:ad];
    }
}

- (void)didClickAd:(nonnull MAAd *)ad {
    if (self.wrapped != NULL && [self.wrapped respondsToSelector:@selector(didClickAd:)]) {
        [self.wrapped performSelector:@selector(didClickAd:) withObject:ad];
    }
}

- (void)didDisplayAd:(nonnull MAAd *)ad {
    if (self.wrapped != NULL && [self.wrapped respondsToSelector:@selector(didDisplayAd:)]) {
        [self.wrapped performSelector:@selector(didDisplayAd:) withObject:ad];
    }
}

- (void)didFailToDisplayAd:(nonnull MAAd *)ad withError:(nonnull MAError *)error {
    if (self.wrapped != NULL && [self.wrapped respondsToSelector:@selector(didFailToDisplayAd:withError:)]) {
        NSMethodSignature *methodSignature = [self.wrapped methodSignatureForSelector:@selector(didFailToDisplayAd:withError:)];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
        [invocation setTarget:self.wrapped];
        [invocation setSelector:@selector(didFailToDisplayAd:withError:)];
        [invocation setArgument:&ad atIndex:2];
        [invocation setArgument:&error atIndex:3];
        [invocation invoke];
    }
}

- (void)didFailToLoadAdForAdUnitIdentifier:(nonnull NSString *)adUnitIdentifier withError:(nonnull MAError *)error {
    if (self.wrapped != NULL && [self.wrapped respondsToSelector:@selector(didFailToLoadAdForAdUnitIdentifier:withError:)]) {
        NSMethodSignature *methodSignature = [self.wrapped methodSignatureForSelector:@selector(didFailToLoadAdForAdUnitIdentifier:withError:)];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
        [invocation setTarget:self.wrapped];
        [invocation setSelector:@selector(didFailToLoadAdForAdUnitIdentifier:withError:)];
        [invocation setArgument:&adUnitIdentifier atIndex:2];
        [invocation setArgument:&error atIndex:3];
        [invocation invoke];
    }
}

- (void)didHideAd:(nonnull MAAd *)ad {
    if (self.bannerAd == NULL) {
        NSString* format = getAdFormat(ad);
        if (format != NULL && !self.listenForRevenue) {
            callImpressionDataBlock(self.impressionDataBlock, ad, format);
		}
        [self unref];
    }

    if (self.wrapped != NULL && [self.wrapped respondsToSelector:@selector(didHideAd:)]) {
        [self.wrapped performSelector:@selector(didHideAd:) withObject:ad];
    }
}

- (void)didLoadAd:(nonnull MAAd *)ad {
    if (self.bannerAd != NULL) {
        NSString* format = getAdFormat(ad);
        if (format != NULL && !self.listenForRevenue) {
            callImpressionDataBlock(self.impressionDataBlock, ad, format);
        }
    }
    if (self.wrapped != NULL && [self.wrapped respondsToSelector:@selector(didLoadAd:)]) {
        [self.wrapped performSelector:@selector(didLoadAd:) withObject:ad];
    }
}

- (void)didRewardUserForAd:(nonnull MAAd *)ad withReward:(nonnull MAReward *)reward {
    if (self.wrappedRewarded != NULL && [self.wrappedRewarded respondsToSelector:@selector(didRewardUserForAd:withReward:)]) {
        NSMethodSignature *methodSignature = [self.wrappedRewarded methodSignatureForSelector:@selector(didRewardUserForAd:withReward:)];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
        [invocation setTarget:self.wrappedRewarded];
        [invocation setSelector:@selector(didRewardUserForAd:withReward:)];
        [invocation setArgument:&ad atIndex:2];
        [invocation setArgument:&reward atIndex:3];
        [invocation invoke];
    }
}

@end

#pragma mark JTAppLovinNativeAdDelegate

MANativeAdLoader* getLoaderFromController(MANativeAdLoader* loader) {
    static Protocol* MAAdRevenueDelegateProtocol = NULL;
    static Protocol* MANativeAdDelegateProtocol = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        MAAdRevenueDelegateProtocol = objc_getProtocol("MAAdRevenueDelegate");
        MANativeAdDelegateProtocol = objc_getProtocol("MANativeAdDelegate");
    });

    id controller = [(id)loader valueForKey:@"controller"];
    if (controller != NULL) {
        id controllerRevenueDelegate = [controller valueForKey:@"revenueDelegate"];
        id controllerNativeAdDelegate = [controller valueForKey:@"nativeAdDelegate"];
        if (controllerRevenueDelegate != NULL && [controllerRevenueDelegate conformsToProtocol:MAAdRevenueDelegateProtocol]) {
            return (MANativeAdLoader*) controller;
        }
        if (controllerNativeAdDelegate != NULL && [controllerNativeAdDelegate conformsToProtocol:MANativeAdDelegateProtocol]) {
            return (MANativeAdLoader*) controller;
        }
    }

    return loader;
}

@implementation JTAppLovinNativeAdDelegate

- (id)init:(NSObject<MANativeAdDelegate>*)wrapped
    loader:(MANativeAdLoader*)loader
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock {
    self = [super init];

    if (self != NULL) {
        self.wrapped = wrapped;
        self.loader = loader;
        self.impressionDataBlock = impressionDataBlock;
        self.referenceIndex = [[JTALReferenceRetainer shared] retain:self];
    }

    return self;
}

- (void)unref {
    MANativeAdLoader* loader = self.loader == NULL ? NULL : getLoaderFromController(self.loader);
    if (loader != NULL && [(id)loader valueForKey:@"nativeAdDelegate"] == self) {
        [(id)self.loader setValue:self.wrapped forKey:@"nativeAdDelegate"];
        self.loader = NULL;
    } else {
        return;
    }

    [[JTALReferenceRetainer shared] release:self.referenceIndex];
}

- (void)didClickNativeAd:(nonnull MAAd *)ad {
    if (self.wrapped != NULL && [self.wrapped respondsToSelector:@selector(didClickNativeAd:)]) {
        [self.wrapped performSelector:@selector(didClickNativeAd:) withObject:ad];
    }
}

- (void)didFailToLoadNativeAdForAdUnitIdentifier:(nonnull NSString *)adUnitIdentifier withError:(nonnull MAError *)error {
    if (self.wrapped != NULL && [self.wrapped respondsToSelector:@selector(didFailToLoadNativeAdForAdUnitIdentifier:withError:)]) {
        NSMethodSignature *methodSignature = [self.wrapped methodSignatureForSelector:@selector(didFailToLoadNativeAdForAdUnitIdentifier:withError:)];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
        [invocation setTarget:self.wrapped];
        [invocation setSelector:@selector(didFailToLoadNativeAdForAdUnitIdentifier:withError:)];
        [invocation setArgument:&adUnitIdentifier atIndex:2];
        [invocation setArgument:&error atIndex:3];
        [invocation invoke];
    }
}

- (void)didLoadNativeAd:(nullable MANativeAdView *)nativeAdView forAd:(nonnull MAAd *)ad {
    NSString* format = getAdFormat(ad);
    if (format != NULL) {
        callImpressionDataBlock(self.impressionDataBlock, ad, format);
    }

    [self unref];

    if (self.wrapped != NULL && [self.wrapped respondsToSelector:@selector(didLoadNativeAd:forAd:)]) {
        NSMethodSignature *methodSignature = [self.wrapped methodSignatureForSelector:@selector(didLoadNativeAd:forAd:)];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
        [invocation setTarget:self.wrapped];
        [invocation setSelector:@selector(didLoadNativeAd:forAd:)];
        [invocation setArgument:&nativeAdView atIndex:2];
        [invocation setArgument:&ad atIndex:3];
        [invocation invoke];
    }
}

@end

#pragma mark JTAppLovinAdRevenueDelegate

@implementation JTAppLovinAdRevenueDelegate

- (id)init:(NSObject<MAAdRevenueDelegate>*)wrapped
 appOpenAd:(MAAppOpenAd *)appOpenAd
listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock {
	self = [super init];

	if (self != NULL) {
		self.wrapped = wrapped;
		self.appOpenAd = appOpenAd;
		self.bannerAd = NULL;
		self.interstitialAd = NULL;
		self.rewardedAd = NULL;
		self.rewardedInterstitialAd = NULL;
		self.nativeAdLoader = NULL;
		self.listenForRevenue = listenForRevenue;
		self.impressionDataBlock = impressionDataBlock;
		self.referenceIndex = [[JTALReferenceRetainer shared] retain:self];
	}

	return self;
}

- (id)init:(NSObject<MAAdRevenueDelegate>*)wrapped
	  bannerAd:(MAAdView *)bannerAd
listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock {
	self = [super init];

	if (self != NULL) {
		self.wrapped = wrapped;
		self.appOpenAd = NULL;
        self.bannerAd = bannerAd;
        self.interstitialAd = NULL;
        self.rewardedAd = NULL;
        self.rewardedInterstitialAd = NULL;
        self.nativeAdLoader = NULL;
        self.listenForRevenue = listenForRevenue;
        self.impressionDataBlock = impressionDataBlock;
        self.referenceIndex = [[JTALReferenceRetainer shared] retain:self];
    }

    return self;
}

- (id)init:(NSObject<MAAdRevenueDelegate>*)wrapped
   interstitialAd:(MAInterstitialAd*)interstitialAd
       listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock {
    self = [super init];

    if (self != NULL) {
        self.wrapped = wrapped;
        self.appOpenAd = NULL;
        self.bannerAd = NULL;
        self.interstitialAd = interstitialAd;
        self.rewardedAd = NULL;
        self.rewardedInterstitialAd = NULL;
        self.nativeAdLoader = NULL;
        self.listenForRevenue = listenForRevenue;
        self.impressionDataBlock = impressionDataBlock;
        self.referenceIndex = [[JTALReferenceRetainer shared] retain:self];
    }

    return self;
}

- (id)init:(NSObject<MAAdRevenueDelegate>*)wrapped
    rewardedAd:(MARewardedAd*)rewardedAd
       listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock {
    self = [super init];

    if (self != NULL) {
        self.wrapped = wrapped;
        self.appOpenAd = NULL;
        self.bannerAd = NULL;
        self.interstitialAd = NULL;
        self.rewardedAd = rewardedAd;
        self.rewardedInterstitialAd = NULL;
        self.nativeAdLoader = NULL;
        self.listenForRevenue = listenForRevenue;
        self.impressionDataBlock = impressionDataBlock;
        self.referenceIndex = [[JTALReferenceRetainer shared] retain:self];
    }

    return self;
}

- (id)init:(NSObject<MAAdRevenueDelegate> *)wrapped
rewardedInterstitialAd:(MARewardedInterstitialAd *)rewardedInterstitialAd
       listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock {
    self = [super init];

    if (self != NULL) {
        self.wrapped = wrapped;
        self.appOpenAd = NULL;
        self.bannerAd = NULL;
        self.interstitialAd = NULL;
        self.rewardedAd = NULL;
        self.rewardedInterstitialAd = rewardedInterstitialAd;
        self.nativeAdLoader = NULL;
        self.listenForRevenue = listenForRevenue;
        self.impressionDataBlock = impressionDataBlock;
        self.referenceIndex = [[JTALReferenceRetainer shared] retain:self];
    }

    return self;
}

- (id)init:(NSObject<MAAdRevenueDelegate> *)wrapped
        nativeAdLoader:(MANativeAdLoader *)nativeAdLoader
       listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock {
    self = [super init];

    if (self != NULL) {
        self.wrapped = wrapped;
        self.appOpenAd = NULL;
        self.bannerAd = NULL;
        self.interstitialAd = NULL;
        self.rewardedAd = NULL;
        self.rewardedInterstitialAd = NULL;
        self.nativeAdLoader = nativeAdLoader;
        self.listenForRevenue = listenForRevenue;
        self.impressionDataBlock = impressionDataBlock;
        self.referenceIndex = [[JTALReferenceRetainer shared] retain:self];
    }

    return self;
}

- (void) unref {
    if (self.bannerAd != NULL && [(id)self.bannerAd valueForKey:@"revenueDelegate"] == self) {
        [(id)self.bannerAd setValue:self.wrapped forKey:@"revenueDelegate"];
        self.bannerAd = NULL;
    } else if (self.appOpenAd != NULL && [(id)self.appOpenAd valueForKey:@"revenueDelegate"] == self) {
        [(id)self.appOpenAd setValue:self.wrapped forKey:@"revenueDelegate"];
        self.appOpenAd = NULL;
    } else if (self.interstitialAd != NULL && [(id)self.interstitialAd valueForKey:@"revenueDelegate"] == self) {
        [(id)self.interstitialAd setValue:self.wrapped forKey:@"revenueDelegate"];
        self.interstitialAd = NULL;
    } else if (self.rewardedAd != NULL && [(id)self.rewardedAd valueForKey:@"revenueDelegate"] == self) {
        [(id)self.rewardedAd setValue:self.wrapped forKey:@"revenueDelegate"];
        self.rewardedAd = NULL;
    } else if (self.rewardedInterstitialAd != NULL && [(id)self.rewardedInterstitialAd valueForKey:@"revenueDelegate"] == self) {
        [(id)self.rewardedInterstitialAd setValue:self.wrapped forKey:@"revenueDelegate"];
        self.rewardedInterstitialAd = NULL;
    } else if (self.nativeAdLoader != NULL && [(id)self.nativeAdLoader valueForKey:@"revenueDelegate"] == self) {
        [(id)self.nativeAdLoader setValue:self.wrapped forKey:@"revenueDelegate"];
        self.nativeAdLoader = NULL;
    } else {
        return;
    }

    [[JTALReferenceRetainer shared] release:self.referenceIndex];
}

- (void)didPayRevenueForAd:(MAAd *)ad {
    NSString* format = getAdFormat(ad);
    if (format != NULL && self.listenForRevenue) {
        callImpressionDataBlock(self.impressionDataBlock, ad, format);
    }

    if (self.bannerAd == NULL && self.nativeAdLoader == NULL) {
        [self unref];
    }

    if (self.wrapped != NULL && [self.wrapped respondsToSelector:@selector(didPayRevenueForAd:)]) {
        [self.wrapped performSelector:@selector(didPayRevenueForAd:) withObject:ad];
    }
}

@end

#pragma mark Helpers

typedef id (*GetValueForKey)(Class, SEL, NSString*);

static id __nullable findAdFormat(Class MAAdFormat, GetValueForKey getValueForKey, NSString* key) {
    @try {
        return getValueForKey(MAAdFormat, @selector(valueForKey:), key);
    } @catch (NSException * e) {
        return NULL;
    }
}

static NSString* __nullable getAdFormat(MAAd* __nullable ad) {
    static id __nullable banner = NULL;
    static id __nullable mrec = NULL;
    static id __nullable leader = NULL;
    static id __nullable interstitial = NULL;
    static id __nullable rewardedInterstitial = NULL;
    static id __nullable rewarded = NULL;
    static id __nullable native = NULL;
    static id __nullable appOpen = NULL;
    static id __nullable crossPromo = NULL;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class MAAdFormat = objc_lookUpClass("MAAdFormat");
        if (MAAdFormat == NULL) {
            return;
        }

        Method getValueForKeyMethod = class_getClassMethod(MAAdFormat, @selector(valueForKey:));
        if (getValueForKeyMethod == NULL) {
            return;
        }

        GetValueForKey getValueForKey = (GetValueForKey) method_getImplementation(getValueForKeyMethod);

        banner = findAdFormat(MAAdFormat, getValueForKey, @"banner");
        mrec = findAdFormat(MAAdFormat, getValueForKey, @"mrec");
        leader = findAdFormat(MAAdFormat, getValueForKey, @"leader");
        interstitial = findAdFormat(MAAdFormat, getValueForKey, @"interstitial");
        rewardedInterstitial = findAdFormat(MAAdFormat, getValueForKey, @"rewardedInterstitial");
        rewarded = findAdFormat(MAAdFormat, getValueForKey, @"rewarded");
        native = findAdFormat(MAAdFormat, getValueForKey, @"native");
        appOpen = findAdFormat(MAAdFormat, getValueForKey, @"appOpen");
        crossPromo = findAdFormat(MAAdFormat, getValueForKey, @"crossPromo");
    });

    if (ad == NULL) {
        return NULL;
    }

    id adFormat = [(id)ad valueForKey:@"format"];
    
    if (banner != NULL && adFormat == banner) {
        return @"banner";
    } else if (mrec != NULL && adFormat == mrec) {
        return @"mrec";
    } else if (leader != NULL && adFormat == leader) {
        return @"leader";
    } else if (interstitial != NULL && adFormat == interstitial) {
        return @"interstitial";
    } else if (rewardedInterstitial != NULL && adFormat == rewardedInterstitial) {
        return @"rewardedInterstitial";
    } else if (rewarded != NULL && adFormat == rewarded) {
        return @"rewarded";
    } else if (native != NULL && adFormat == native) {
        return @"native";
    } else if (appOpen != NULL && adFormat == appOpen) {
        return @"appOpen";
    } else if (crossPromo != NULL && adFormat == crossPromo) {
        return @"crossPromo";
    } else {
        return @"impression";
    }
}

static void callImpressionDataBlock(JusttrackALImpressionDataBlock block, MAAd* ad, NSString* format) {
    if (block && ad && format) {
        JusttrackALImpressionData *impressionData = [[JusttrackALImpressionData alloc] init];
        impressionData.format = format;
        impressionData.network = [(id)ad valueForKey:@"networkName"];
        impressionData.placement = [(id)ad valueForKey:@"placement"];
        NSNumber *revenueNum = [(id)ad valueForKey:@"revenue"];
        impressionData.revenue = revenueNum ?: @(0.0);
        block(impressionData);
    }
}
