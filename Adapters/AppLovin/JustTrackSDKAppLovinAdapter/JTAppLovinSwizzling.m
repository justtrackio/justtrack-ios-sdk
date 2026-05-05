#import "JTAppLovinDelegates.h"
#import "JTALReferenceRetainer.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

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

extern bool listenForRevenue;
extern JusttrackALImpressionDataBlock _Nullable impressionDataBlock;

extern LoadBannerAdCallback __nullable loadBannerAdCallback;
extern RemoveFromSuperviewCallback __nullable removeFromSuperviewCallback;

extern ShowInterstitialAdCallback __nullable showInterstitialAdCallback;
extern ShowInterstitialAdForPlacementCallback __nullable showInterstitialAdForPlacementCallback;
extern ShowInterstitialAdForPlacementWithCustomDataCallback __nullable showInterstitialAdForPlacementWithCustomDataCallback;

extern ShowRewardedAdCallback __nullable showRewardedAdCallback;
extern ShowRewardedAdForPlacementCallback __nullable showRewardedAdForPlacementCallback;
extern ShowRewardedAdForPlacementWithCustomDataCallback __nullable showRewardedAdForPlacementWithCustomDataCallback;

extern ShowRewardedInterstitialAdCallback __nullable showRewardedInterstitialAdCallback;
extern ShowRewardedInterstitialAdForPlacementCallback __nullable showRewardedInterstitialAdForPlacementCallback;
extern ShowRewardedInterstitialAdForPlacementWithCustomDataCallback __nullable showRewardedInterstitialAdForPlacementWithCustomDataCallback;

extern ShowAppOpenAdCallback __nullable showAppOpenAdCallback;
extern ShowAppOpenAdForPlacementCallback __nullable showAppOpenAdForPlacementCallback;
extern ShowAppOpenAdForPlacementWithCustomDataCallback __nullable showAppOpenAdForPlacementWithCustomDataCallback;

extern LoadNativeAdCallback __nullable loadNativeAdCallback;
extern LoadNativeAdIntoViewCallback __nullable loadNativeAdIntoViewCallback;

MANativeAdLoader* getLoaderFromController(MANativeAdLoader* loader);

#pragma mark Banner

void loadAppLovinBannerAd(MAAdView* ad, SEL sel) {
    if (loadBannerAdCallback != NULL) {
        id adObj = (id)ad;
        id currentRevenueDelegate = [adObj valueForKey:@"revenueDelegate"];
        if (currentRevenueDelegate == NULL || [currentRevenueDelegate class] != [JTAppLovinAdRevenueDelegate class]) {
            id revenueDelegate = [[JTAppLovinAdRevenueDelegate alloc] init:currentRevenueDelegate bannerAd:ad listenForRevenue:listenForRevenue impressionDataBlock:impressionDataBlock];
            [adObj setValue:revenueDelegate forKey:@"revenueDelegate"];
        }
        id currentDelegate = [adObj valueForKey:@"delegate"];
        if (currentDelegate == NULL || [currentDelegate class] != [JTAppLovinAdDelegate class]) {
            id wrappedDelegate = [[JTAppLovinAdDelegate alloc] init:currentDelegate bannerAd:ad listenForRevenue:listenForRevenue impressionDataBlock:impressionDataBlock];
            [adObj setValue:wrappedDelegate forKey:@"delegate"];
        }
        loadBannerAdCallback(ad, sel);
    }
}

void removeFromSuperviewForAppLovinBanner(UIView* view, SEL sel) {
    static Class MAAdViewClass = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        MAAdViewClass = objc_lookUpClass("MAAdView");
    });

    if (view != NULL && [view class] == MAAdViewClass) {
        id adObj = (id) view;
        id revenueDelegate = [adObj valueForKey:@"revenueDelegate"];
        if (revenueDelegate != NULL && [revenueDelegate class] == [JTAppLovinAdRevenueDelegate class]) {
            JTAppLovinAdRevenueDelegate* revDelegate = (JTAppLovinAdRevenueDelegate*) revenueDelegate;
            [revDelegate unref];
        }
        id delegate = [adObj valueForKey:@"delegate"];
        if (delegate != NULL && [delegate class] == [JTAppLovinAdDelegate class]) {
            JTAppLovinAdDelegate* adDelegate = (JTAppLovinAdDelegate*) delegate;
            [adDelegate unref];
        }
    }

    if (removeFromSuperviewCallback != NULL) {
        removeFromSuperviewCallback(view, sel);
    }
}

#pragma mark Interstitial

static void setInterstitialAdDelegate(MAInterstitialAd* ad) {
    id adObj = (id)ad;
    id currentRevenueDelegate = [adObj valueForKey:@"revenueDelegate"];
    if ([currentRevenueDelegate class] != [JTAppLovinAdRevenueDelegate class]) {
        id revenueDelegate = [[JTAppLovinAdRevenueDelegate alloc] init:currentRevenueDelegate interstitialAd:ad listenForRevenue:listenForRevenue impressionDataBlock:impressionDataBlock];
        [adObj setValue:revenueDelegate forKey:@"revenueDelegate"];
    }
    id currentDelegate = [adObj valueForKey:@"delegate"];
    if ([currentDelegate class] != [JTAppLovinAdDelegate class]) {
        id wrappedDelegate = [[JTAppLovinAdDelegate alloc] init:currentDelegate interstitialAd:ad listenForRevenue:listenForRevenue impressionDataBlock:impressionDataBlock];
        [adObj setValue:wrappedDelegate forKey:@"delegate"];
    }
}

void showAppLovinInterstitialAd(MAInterstitialAd* ad, SEL sel) {
    if (showInterstitialAdCallback != NULL) {
        setInterstitialAdDelegate(ad);
        showInterstitialAdCallback(ad, sel);
    }
}

void showAppLovinInterstitialAdForPlacement(MAInterstitialAd* ad, SEL sel, NSString* __nullable placement) {
    if (showInterstitialAdForPlacementCallback != NULL) {
        setInterstitialAdDelegate(ad);
        showInterstitialAdForPlacementCallback(ad, sel, placement);
    }
}

void showAppLovinInterstitialAdForPlacementWithCustomData(MAInterstitialAd* ad, SEL sel, NSString* __nullable placement, NSString* __nullable customData) {
    if (showInterstitialAdForPlacementWithCustomDataCallback != NULL) {
        setInterstitialAdDelegate(ad);
        showInterstitialAdForPlacementWithCustomDataCallback(ad, sel, placement, customData);
    }
}

#pragma mark Rewarded

static void setRewardedAdDelegate(MARewardedAd* ad) {
    id adObj = (id)ad;
    id currentRevenueDelegate = [adObj valueForKey:@"revenueDelegate"];
    if ([currentRevenueDelegate class] != [JTAppLovinAdRevenueDelegate class]) {
        id revenueDelegate = [[JTAppLovinAdRevenueDelegate alloc] init:currentRevenueDelegate rewardedAd:ad listenForRevenue:listenForRevenue impressionDataBlock:impressionDataBlock];
        [adObj setValue:revenueDelegate forKey:@"revenueDelegate"];
    }
    id currentDelegate = [adObj valueForKey:@"delegate"];
    if ([currentDelegate class] != [JTAppLovinAdDelegate class]) {
        id wrappedDelegate = [[JTAppLovinAdDelegate alloc] init:currentDelegate rewardedAd:ad listenForRevenue:listenForRevenue impressionDataBlock:impressionDataBlock];
        [adObj setValue:wrappedDelegate forKey:@"delegate"];
    }
}

void showAppLovinRewardedAd(MARewardedAd* ad, SEL sel) {
    if (showRewardedAdCallback != NULL) {
        setRewardedAdDelegate(ad);
        showRewardedAdCallback(ad, sel);
    }
}

void showAppLovinRewardedAdForPlacement(MARewardedAd* ad, SEL sel, NSString* __nullable placement) {
    if (showRewardedAdForPlacementCallback != NULL) {
        setRewardedAdDelegate(ad);
        showRewardedAdForPlacementCallback(ad, sel, placement);
    }
}

void showAppLovinRewardedAdForPlacementWithCustomData(MARewardedAd* ad, SEL sel, NSString* __nullable placement, NSString* __nullable customData) {
    if (showRewardedAdForPlacementWithCustomDataCallback != NULL) {
        setRewardedAdDelegate(ad);
        showRewardedAdForPlacementWithCustomDataCallback(ad, sel, placement, customData);
    }
}

#pragma mark Rewarded Interstitial

static void setRewardedInterstitialAdDelegate(MARewardedInterstitialAd* ad) {
    id adObj = (id)ad;
    id currentRevenueDelegate = [adObj valueForKey:@"revenueDelegate"];
    if ([currentRevenueDelegate class] != [JTAppLovinAdRevenueDelegate class]) {
        id revenueDelegate = [[JTAppLovinAdRevenueDelegate alloc] init:currentRevenueDelegate rewardedInterstitialAd:ad listenForRevenue:listenForRevenue impressionDataBlock:impressionDataBlock];
        [adObj setValue:revenueDelegate forKey:@"revenueDelegate"];
    }
    id currentDelegate = [adObj valueForKey:@"delegate"];
    if ([currentDelegate class] != [JTAppLovinAdDelegate class]) {
        id wrappedDelegate = [[JTAppLovinAdDelegate alloc] init:currentDelegate rewardedInterstitialAd:ad listenForRevenue:listenForRevenue impressionDataBlock:impressionDataBlock];
        [adObj setValue:wrappedDelegate forKey:@"delegate"];
    }
}

void showAppLovinRewardedInterstitialAd(MARewardedInterstitialAd* ad, SEL sel) {
    if (showRewardedInterstitialAdCallback != NULL) {
        setRewardedInterstitialAdDelegate(ad);
        showRewardedInterstitialAdCallback(ad, sel);
    }
}

void showAppLovinRewardedInterstitialAdForPlacement(MARewardedInterstitialAd* ad, SEL sel, NSString* __nullable placement) {
    if (showRewardedInterstitialAdForPlacementCallback != NULL) {
        setRewardedInterstitialAdDelegate(ad);
        showRewardedInterstitialAdForPlacementCallback(ad, sel, placement);
    }
}

void showAppLovinRewardedInterstitialAdForPlacementWithCustomData(MARewardedInterstitialAd* ad, SEL sel, NSString* __nullable placement, NSString* __nullable customData) {
    if (showRewardedInterstitialAdForPlacementWithCustomDataCallback != NULL) {
        setRewardedInterstitialAdDelegate(ad);
        showRewardedInterstitialAdForPlacementWithCustomDataCallback(ad, sel, placement, customData);
    }
}

#pragma mark Native Ad

static void wrapNativeAdDelegate(MANativeAdLoader* loader) {
    MANativeAdLoader *readFromLoader = getLoaderFromController(loader);
    id readFromLoaderObj = (id)readFromLoader;
    id wrappedRevenueDelegate = [readFromLoaderObj valueForKey:@"revenueDelegate"];
    if ([wrappedRevenueDelegate class] != [JTAppLovinAdRevenueDelegate class]) {
        id revenueDelegate = [[JTAppLovinAdRevenueDelegate alloc] init:wrappedRevenueDelegate nativeAdLoader:loader listenForRevenue:listenForRevenue impressionDataBlock:impressionDataBlock];
        id loaderObj = (id)loader;
        [loaderObj setValue:revenueDelegate forKey:@"revenueDelegate"];
    }
    id wrappedNativeAdDelegate = [readFromLoaderObj valueForKey:@"nativeAdDelegate"];
    if ([wrappedNativeAdDelegate class] != [JTAppLovinNativeAdDelegate class]) {
        id wrapperDelegate = [[JTAppLovinNativeAdDelegate alloc] init:wrappedNativeAdDelegate loader:loader impressionDataBlock:impressionDataBlock];
        id loaderObj = (id)loader;
        [loaderObj setValue:wrapperDelegate forKey:@"nativeAdDelegate"];
    }
}

void loadAppLovinNativeAd(MANativeAdLoader* loader, SEL sel) {
    if (loadNativeAdCallback != NULL) {
        wrapNativeAdDelegate(loader);
        loadNativeAdCallback(loader, sel);
    }
}

void loadAppLovinNativeAdIntoView(MANativeAdLoader* loader, SEL sel, MANativeAdView* __nullable view) {
    if (loadNativeAdIntoViewCallback != NULL) {
        wrapNativeAdDelegate(loader);
        loadNativeAdIntoViewCallback(loader, sel, view);
    }
}

#pragma mark App Open Ad

static void wrapAppOpenAdDelegate(MAAppOpenAd* ad) {
    id adObj = (id)ad;
    id wrappedRevenueDelegate = [adObj valueForKey:@"revenueDelegate"];
    if ([wrappedRevenueDelegate class] != [JTAppLovinAdRevenueDelegate class]) {
        id revenueDelegate = [[JTAppLovinAdRevenueDelegate alloc] init:wrappedRevenueDelegate appOpenAd:ad listenForRevenue:listenForRevenue impressionDataBlock:impressionDataBlock];
        [adObj setValue:revenueDelegate forKey:@"revenueDelegate"];
    }
    id wrappedDelegate = [adObj valueForKey:@"delegate"];
    if ([wrappedDelegate class] != [JTAppLovinAdDelegate class]) {
        id wrapperDelegate = [[JTAppLovinAdDelegate alloc] init:wrappedDelegate appOpenAd:ad listenForRevenue:listenForRevenue impressionDataBlock:impressionDataBlock];
        [adObj setValue:wrapperDelegate forKey:@"delegate"];
    }
}

void showAppLovinOpenAd(MAAppOpenAd* ad, SEL sel) {
    if (showAppOpenAdCallback != NULL) {
        wrapAppOpenAdDelegate(ad);
        showAppOpenAdCallback(ad, sel);
    }
}

void showAppLovinOpenAdForPlacement(MAAppOpenAd* ad, SEL sel, NSString * __nullable placement) {
    if (showAppOpenAdForPlacementCallback != NULL) {
        wrapAppOpenAdDelegate(ad);
        showAppOpenAdForPlacementCallback(ad, sel, placement);
    }
}

void showAppLovinOpenAdForPlacementWithCustomData(MAAppOpenAd* ad, SEL sel, NSString * __nullable placement, NSString * __nullable customData) {
    if (showAppOpenAdForPlacementWithCustomDataCallback != NULL) {
        wrapAppOpenAdDelegate(ad);
        showAppOpenAdForPlacementWithCustomDataCallback(ad, sel, placement, customData);
    }
}
