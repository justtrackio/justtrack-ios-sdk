#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JusttrackObjCFirebaseAdapter : NSObject

- (instancetype)init;

- (void)integrateOnSuccess:(void (^)(NSString *firebaseAppInstanceId))onSuccess
				 onFailure:(void (^)(NSError *error))onFailure;

@end

NS_ASSUME_NONNULL_END
