#import <Foundation/Foundation.h>
#import <JustTrackSDK/JustTrackSDK-Swift.h>
#include "JTAdjoeIntegration.h"

NS_ASSUME_NONNULL_BEGIN

@interface AdjoeIntegrationLoader : NSObject
@end

@implementation AdjoeIntegrationLoader

+ (void)load {
    [AdjoeIntegration registerWithSDKWithCallback:^() {
        [JTAdjoeIntegration integrateWithAdjoe];
    }];
}

@end

NS_ASSUME_NONNULL_END
