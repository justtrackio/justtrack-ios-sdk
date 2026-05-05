#import "JusttrackALImpressionData.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JusttrackObjCAppLovinAdapter : NSObject

- (instancetype)init;

- (void)integrateCustomUserId:(NSString * _Nullable)customUserId
		  impressionDataBlock:(JusttrackALImpressionDataBlock)impressionDataBlock
					onSuccess:(void (^)(void))onSuccess
					onFailure:(void (^)(NSError *error))onFailure;

@end

NS_ASSUME_NONNULL_END
