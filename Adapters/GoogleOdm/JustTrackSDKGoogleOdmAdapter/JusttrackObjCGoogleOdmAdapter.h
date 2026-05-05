#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JusttrackObjCGoogleOdmAdapter : NSObject

- (instancetype)init;

- (void)fetchOdmInfoOnSuccess:(void (^)(NSString *odmInfo))onSuccess
					onFailure:(void (^)(NSError *error))onFailure;

@end

NS_ASSUME_NONNULL_END
