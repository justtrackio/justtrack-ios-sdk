#import "JusttrackObjCFirebaseAdapter.h"
#import <objc/message.h>
#import <objc/runtime.h>

@interface JusttrackObjCFirebaseAdapter()
@end

@implementation JusttrackObjCFirebaseAdapter

- (instancetype)init {
	self = [super init];
	
	return self;
}

- (void)integrateOnSuccess:(void (^)(NSString *firebaseAppInstanceId))onSuccess
				 onFailure:(void (^)(NSError *error))onFailure {
	Class Firebase = objc_lookUpClass("FIRAnalytics") ?: objc_lookUpClass("FIRAnalytics.FIRAnalytics");
	
	if (Firebase == NULL) {
		NSError *error = [NSError errorWithDomain:@"JusttrackFirebaseAdapter"
											 code:1101
										 userInfo:@{NSLocalizedDescriptionKey: @"Firebase SDK not found"}];
		onFailure(error);
		return;
	}
	
	SEL appInstanceIDSelector = NSSelectorFromString(@"appInstanceID");
	if ([Firebase respondsToSelector:appInstanceIDSelector]) {
		NSString *firebaseAppInstanceId = ((NSString* (*)(id, SEL))objc_msgSend)(Firebase, appInstanceIDSelector);
		onSuccess(firebaseAppInstanceId);
	} else {
		NSError *error = [NSError errorWithDomain:@"JusttrackFirebaseAdapter"
											 code:1102
										 userInfo:@{NSLocalizedDescriptionKey: @"Firebase appInstanceID method not available"}];
		onFailure(error);
	}
}

@end
