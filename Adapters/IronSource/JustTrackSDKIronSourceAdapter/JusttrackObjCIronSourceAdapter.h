#import <Foundation/Foundation.h>
#import "JusttrackISImpressionDataDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface JusttrackObjCIronSourceAdapter : NSObject

- (instancetype)init;

- (void)integrateImpressionDataBlock:(JusttrackISImpressionDataBlock)impressionDataBlock
						   onSuccess:(void (^)(void))onSuccess
						   onFailure:(void (^)(NSError *error))onFailure;

@end

NS_ASSUME_NONNULL_END
