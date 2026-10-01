#import <Foundation/Foundation.h>
#include "JusttrackISImpressionDataDelegate.h"

@implementation JusttrackISImpressionData
@end

@implementation JusttrackISImpressionDataDelegate

- (instancetype)initWithImpressionDataBlock:(JusttrackISImpressionDataBlock)block {
    self = [super init];
    if (self) {
        _impressionDataBlock = [block copy];
    }
    return self;
}

- (void)impressionDataDidSucceed:(id)impressionData {
    if (impressionData == NULL || !self.impressionDataBlock) {
        return;
    }

    JusttrackISImpressionData *jtImpressionData = [[JusttrackISImpressionData alloc] init];
    jtImpressionData.adUnit = [impressionData valueForKey:@"adFormat"];
    jtImpressionData.adNetwork = [impressionData valueForKey:@"adNetwork"];
    jtImpressionData.placement = [impressionData valueForKey:@"placement"];
    jtImpressionData.abTesting = [impressionData valueForKey:@"ab"];
    jtImpressionData.segmentName = [impressionData valueForKey:@"segmentName"];
    jtImpressionData.instanceName = [impressionData valueForKey:@"instanceName"];
    jtImpressionData.revenue = [impressionData valueForKey:@"revenue"];
    
    self.impressionDataBlock(jtImpressionData);
}

@end
