#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JusttrackObjCUnityAdsAdapter : NSObject

- (instancetype)init;

- (void)integrateWithForwardBlock:(void (^)(NSString *eventName, NSString *placement, NSNumber * _Nullable isComplete))forwardBlock
				   reportingBlock:(void (^)(NSString *message))reportingBlock
						onSuccess:(void (^)(NSString *version))onSuccess
						onFailure:(void (^)(NSError *error))onFailure;

@end

NS_ASSUME_NONNULL_END
