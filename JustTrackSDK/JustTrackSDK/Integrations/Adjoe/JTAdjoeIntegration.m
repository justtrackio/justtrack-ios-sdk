#import "JTAdjoeIntegration.h"
#import <JustTrackSDK/JustTrackSDK-Swift.h>
#import <objc/runtime.h>
#import <JustTrackSDK/JustTrackSDK.h>
#import "JTLimitedReferenceRetainer.h"

NS_ASSUME_NONNULL_BEGIN

@protocol AdjoeWaveImpressionListener <NSObject>
- (void)onImpressionWithUserId:(NSString *)userId
                   placementId:(NSString *)placementId
                          type:(NSString *)type
                     auctionId:(NSString *)auctionId
                    bidderName:(NSString *)bidderName
                         appId:(NSString *)appId
                      deviceId:(NSString *)deviceId;
@end

@interface AdjoeWaveImpressionObservable : NSObject
+ (void)addAdImpressionDataListener:(id<AdjoeWaveImpressionListener>)listener;
@end

@interface SDKVersionProvider : NSObject
+ (NSString*)getVersion;
@end

typedef void (*AddAdImpressionDataListener)(Class, SEL, id<AdjoeWaveImpressionListener>);

static JTLimitedReferenceRetainer* __nullable impressionRetainer = NULL;

@interface JTAdjoeWaveImpressionListener : NSObject <AdjoeWaveImpressionListener>
- (id)init;
@end

@implementation JTAdjoeWaveImpressionListener


- (id)init {
    self = [super init];

    if (self != NULL) {
        [impressionRetainer retain:self];
    }

    return self;
}

- (void)onImpressionWithUserId:(NSString *)userId
                   placementId:(NSString *)placementId
                          type:(NSString *)type
                     auctionId:(NSString *)auctionId
                    bidderName:(NSString *)bidderName
                         appId:(NSString *)appId
                      deviceId:(NSString *)deviceId {
    [AdjoeIntegration impressionDidSucceed:type adNetwork:bidderName placement:placementId appId:appId];
}

@end

NS_ASSUME_NONNULL_END

@implementation JTAdjoeIntegration

+ (void)integrateWithAdjoe {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *version = NULL;

        Class sdkVersionClass = NSClassFromString(@"AdjoeWaveSDK.SDKVersionProvider");
        if (sdkVersionClass != NULL && [sdkVersionClass respondsToSelector:@selector(getVersion)]) {
            version = [sdkVersionClass getVersion];
        }

        Class adjoeClass = objc_lookUpClass("AdjoeWaveSDK.AdjoeWaveImpressionObservable");
        if (adjoeClass == NULL) {
            [AdjoeIntegration integrationFailed:@"Could not find AdjoeWaveSDK.AdjoeWaveImpressionObservable class" version:version];

            return;
        }

        // only set it to non-null after we know that there is something from adjoe
        if (version == NULL) {
            version = @"unknown";
        }

        if ([adjoeClass respondsToSelector:@selector(addAdImpressionDataListener:)]) {
            impressionRetainer = [[JTLimitedReferenceRetainer alloc] init:1];
            [adjoeClass addAdImpressionDataListener:[[JTAdjoeWaveImpressionListener alloc] init]];
        } else {
            [AdjoeIntegration integrationFailed:@"Could not find Adjoe addAdImpressionDataListener:" version:version];

            return;
        }

        [AdjoeIntegration integrationSucceeded:version];
    });
}

@end
