#import "JusttrackObjCIronSourceAdapter.h"
#import "JusttrackISImpressionDataDelegate.h"
#import <objc/message.h>
#import <objc/runtime.h>

@interface JusttrackObjCIronSourceAdapter()
@end

@implementation JusttrackObjCIronSourceAdapter

- (instancetype)init {
	self = [super init];
	
	return self;
}

- (void)integrateCustomUserId:(NSString *)customUserId
          impressionDataBlock:(JusttrackISImpressionDataBlock)impressionDataBlock
					onSuccess:(void (^)(void))onSuccess
					onFailure:(void (^)(NSError *error))onFailure {
	Class IronSource = objc_lookUpClass("IronSource") ?: objc_lookUpClass("IronSource.IronSource");

	if (IronSource == NULL) {
		NSError *error = [NSError errorWithDomain:@"JusttrackIronSourceAdapter"
											 code:1101
										 userInfo:@{NSLocalizedDescriptionKey: @"IronSource SDK not found"}];
		onFailure(error);
		return;
	}

	if (customUserId != nil) {
		SEL setUserIdSelector = NSSelectorFromString(@"setUserId:");
		if ([IronSource respondsToSelector:setUserIdSelector]) {
			((void (*)(id, SEL, NSString *))objc_msgSend)(IronSource, setUserIdSelector, customUserId);
			NSLog(@"[JusttrackIronSourceAdapter] Setting IronSouce user Id: %@", customUserId);
		}
	}

	JusttrackISImpressionDataDelegate *delegate = [[JusttrackISImpressionDataDelegate alloc] initWithImpressionDataBlock:impressionDataBlock];

	SEL addDelegateSelector = NSSelectorFromString(@"addImpressionDataDelegate:");
	if ([IronSource respondsToSelector:addDelegateSelector]) {
		((void (*)(id, SEL, id))objc_msgSend)(IronSource, addDelegateSelector, delegate);
		onSuccess();
	} else {
		NSError *error = [NSError errorWithDomain:@"JusttrackIronSourceAdapter"
											 code:1102
										 userInfo:@{NSLocalizedDescriptionKey: @"IronSource addImpressionDataDelegate method not available"}];
		onFailure(error);
	}
}

@end
