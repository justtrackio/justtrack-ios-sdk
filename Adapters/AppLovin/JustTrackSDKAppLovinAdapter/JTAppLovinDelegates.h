#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "JusttrackALImpressionData.h"

NS_ASSUME_NONNULL_BEGIN

@class MAAd;
@class MAAdView;
@class MAInterstitialAd;
@class MARewardedAd;
@class MARewardedInterstitialAd;
@class MAAppOpenAd;
@class MANativeAdLoader;
@class MANativeAdView;
@class MAAdFormat;
@class MAError;
@class MAReward;

@protocol MAAdDelegate;
@protocol MAAdViewAdDelegate;
@protocol MARewardedAdDelegate;
@protocol MANativeAdDelegate;
@protocol MAAdRevenueDelegate;

#pragma mark JTAppLovinAdDelegate

@interface JTAppLovinAdDelegate : NSObject
@property (nonatomic, weak, nullable) NSObject<MAAdViewAdDelegate>* wrappedBanner;
@property (nonatomic, weak, nullable) NSObject<MAAdDelegate>* wrapped;
@property (nonatomic, weak, nullable) NSObject<MARewardedAdDelegate>* wrappedRewarded;
@property (nonatomic, weak, nullable) MAAppOpenAd* appOpenAd;
@property (nonatomic, weak, nullable) MAAdView* bannerAd;
@property (nonatomic, weak, nullable) MAInterstitialAd* interstitialAd;
@property (nonatomic, weak, nullable) MARewardedAd* rewardedAd;
@property (nonatomic, weak, nullable) MARewardedInterstitialAd* rewardedInterstitialAd;
@property (nonatomic) unsigned long referenceIndex;
@property (nonatomic) bool listenForRevenue;
@property (nonatomic, copy, nullable) JusttrackALImpressionDataBlock impressionDataBlock;

- (id)init:(NSObject<MAAdViewAdDelegate>*)wrapped
   appOpenAd:(MAAppOpenAd*)appOpenAd
listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock;

- (id)init:(NSObject<MAAdViewAdDelegate>*)wrapped
    bannerAd:(MAAdView*)bannerAd
listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock;

- (id)init:(NSObject<MAAdDelegate>*)wrapped
  interstitialAd:(MAInterstitialAd*)interstitialAd
listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock;

- (id)init:(NSObject<MARewardedAdDelegate>*)wrapped
    rewardedAd:(MARewardedAd*)rewardedAd
listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock;

- (id)init:(NSObject<MARewardedAdDelegate>*)wrapped
rewardedInterstitialAd:(MARewardedInterstitialAd*)rewardedInterstitialAd
       listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock;

- (void)unref;
@end

#pragma mark JTAppLovinNativeAdDelegate

@interface JTAppLovinNativeAdDelegate : NSObject
@property (nonatomic, weak, nullable) NSObject<MANativeAdDelegate>* wrapped;
@property (nonatomic, weak, nullable) MANativeAdLoader* loader;
@property (nonatomic) unsigned long referenceIndex;
@property (nonatomic, copy, nullable) JusttrackALImpressionDataBlock impressionDataBlock;

- (id)init:(NSObject<MANativeAdDelegate>*)wrapped
    loader:(MANativeAdLoader*)loader
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock;

- (void)unref;
@end

#pragma mark JTAppLovinAdRevenueDelegate

@interface JTAppLovinAdRevenueDelegate : NSObject
@property (nonatomic, weak, nullable) NSObject<MAAdRevenueDelegate>* wrapped;
@property (nonatomic, weak, nullable) MAAppOpenAd* appOpenAd;
@property (nonatomic, weak, nullable) MAAdView* bannerAd;
@property (nonatomic, weak, nullable) MAInterstitialAd* interstitialAd;
@property (nonatomic, weak, nullable) MARewardedAd* rewardedAd;
@property (nonatomic, weak, nullable) MARewardedInterstitialAd* rewardedInterstitialAd;
@property (nonatomic, weak, nullable) MANativeAdLoader* nativeAdLoader;
@property (nonatomic) unsigned long referenceIndex;
@property (nonatomic) bool listenForRevenue;
@property (nonatomic, copy, nullable) JusttrackALImpressionDataBlock impressionDataBlock;

- (id)init:(NSObject<MAAdRevenueDelegate>*)wrapped
	 appOpenAd:(MAAppOpenAd*)appOpenAd
  listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock;

- (id)init:(NSObject<MAAdRevenueDelegate>*)wrapped
	  bannerAd:(MAAdView*)bannerAd
  listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock;

- (id)init:(NSObject<MAAdRevenueDelegate>*)wrapped
	interstitialAd:(MAInterstitialAd*)interstitialAd
  listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock;

- (id)init:(NSObject<MAAdRevenueDelegate>*)wrapped
		rewardedAd:(MARewardedAd*)rewardedAd
  listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock;

- (id)init:(NSObject<MAAdRevenueDelegate>*)wrapped
rewardedInterstitialAd:(MARewardedInterstitialAd*)rewardedInterstitialAd
  listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock;

- (id)init:(NSObject<MAAdRevenueDelegate>*)wrapped
	nativeAdLoader:(MANativeAdLoader*)nativeAdLoader
  listenForRevenue:(bool)listenForRevenue
impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock;

- (void)unref;
@end

MANativeAdLoader* getLoaderFromController(MANativeAdLoader* loader);

NS_ASSUME_NONNULL_END
